#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

WRAPPER_DIR="$ROOT/modules/cargo/cargo-local"
STUB="$TEST_ROOT/stub"
APP="$TEST_ROOT/app"
DEP="$TEST_ROOT/dep"

# 假 cargo：只把收到的参数打出来。
mkdir -p "$STUB"
printf '#!/bin/sh\necho "$@"\n' >"$STUB/cargo"
chmod +x "$STUB/cargo"
# HOME 隔离：包装器优先用 $HOME/.local/bin 里的 cargo fork，不隔离会调到本机真 cargo。
FAKE_HOME="$TEST_ROOT/home"
mkdir -p "$FAKE_HOME"
run() { (cd "$APP" && HOME="$FAKE_HOME" PATH="$WRAPPER_DIR:$STUB:$TEST_SYSTEM_PATH" cargo "$@" 2>/dev/null); }

mkdir -p "$APP" "$DEP/crates/dep" "$DEP/crates/other"
git -c init.defaultBranch=main init -q "$APP"
cat >"$APP/Cargo.lock" <<'EOF'
[[package]]
name = "dep"
version = "0.1.0"
source = "git+https://example.com/dep?rev=abc#abc1234567"

[[package]]
name = "serde"
version = "1.0.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
EOF
printf '[package]\nname = "dep"\nversion = "0.1.0"\n' >"$DEP/crates/dep/Cargo.toml"
# lock 里没有的包不进 paths。
printf '[package]\nname = "other"\n' >"$DEP/crates/other/Cargo.toml"

# 没有 .cargo-local：原样转给 cargo。
[ "$(run check -p x)" = "check -p x" ] || die "plain cargo was not passed through"

printf '# comment\n%s\n' "$DEP" >"$APP/.cargo-local"
want="paths=[\"$DEP/crates/dep\"]"
[ "$(run check -p x)" = "check --config $want -p x" ] || die "check: $(run check -p x)"
# nextest 的 --config 要在它自己的子命令后面，才传得到它内部调的 cargo。
[ "$(run nextest run --locked)" = "nextest run --config $want --locked" ] || die "nextest: $(run nextest run --locked)"
[ "$(run fmt --all --check)" = "fmt --all --check" ] || die "fmt: $(run fmt --all --check)"
[ "$(run nextest --version)" = "nextest --version" ] || die "nextest flag: $(run nextest --version)"
[ "$(run sweep --time 7)" = "sweep --time 7" ] || die "sweep: $(run sweep --time 7)"
[ "$(run b)" = "b --config $want" ] || die "alias: $(run b)"
[ "$(run +nightly build)" = "+nightly build --config $want" ] || die "toolchain: $(run +nightly build)"
[ "$(run --version)" = "--config $want --version" ] || die "flag first: $(run --version)"
# ~/.local/bin 里有 fork 时，即使 PATH 上 rustup 的 cargo 排在前面，也要走 fork。
mkdir -p "$FAKE_HOME/.local/bin"
printf '#!/bin/sh\necho fork "$@"\n' >"$FAKE_HOME/.local/bin/cargo"
chmod +x "$FAKE_HOME/.local/bin/cargo"
[ "$(run --version)" = "fork --config $want --version" ] || die "fork not preferred: $(run --version)"
echo ok
