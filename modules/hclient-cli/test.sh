#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

TEST_HOME="$TEST_ROOT/home"
TEST_BIN="$TEST_HOME/.local/bin/hclient-cli"
PS_STUB="$TEST_ROOT/ps-stub"
PS_OUT="$TEST_ROOT/ps-out"
mkdir -p "$TEST_HOME/.local/bin"

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# 假二进制只需要回答 `-version`，安装器认的就是这一条输出。
write_fake_cli() {
  printf '#!/usr/bin/env bash\necho v%s\n' "$2" > "$1"
  chmod +x "$1"
}

make_asset() {
  ASSET_URL="file://$TEST_ROOT/asset-$1"
  write_fake_cli "$TEST_ROOT/asset-$1" "$1"
  ASSET_SHA="$(sha_of "$TEST_ROOT/asset-$1")"
}

TARGET_ARCH=arm64

run_installer() {
  HOME="$TEST_HOME" \
    HCLIENT_CLI_BIN="$TEST_BIN" \
    HCLIENT_CLI_OS=Darwin \
    HCLIENT_CLI_ARCH="$TARGET_ARCH" \
    HCLIENT_CLI_DOWNLOAD_URL="$ASSET_URL" \
    HCLIENT_CLI_SHA256="$ASSET_SHA" \
    HCLIENT_CLI_PS="$PS_STUB" \
    "$ROOT/modules/hclient-cli/install.sh" "$1"
}

write_fake_cli "$PS_STUB" unused
printf '#!/usr/bin/env bash\ncat "%s"\n' "$PS_OUT" > "$PS_STUB"
chmod +x "$PS_STUB"
: > "$PS_OUT"

make_asset 1.5.1
UNREACHABLE_URL="file://$TEST_ROOT/no-such-asset"

# 首次安装：下载、校验摘要、落到 ~/.local/bin。
run_installer install >/dev/null
run_installer check || die "check failed right after install."
[[ -x "$TEST_BIN" ]] || die "hclient-cli binary was not installed."

# 已满足时不再下载。URL 指向不存在的文件，重跑仍要成功。
ASSET_URL="$UNREACHABLE_URL"
run_installer install >/dev/null \
  || die "Re-running install downloaded again instead of accepting the existing binary."

# 自带 upgrade 升上去的更高版本必须被接受，不能被 pin 降回来。
write_fake_cli "$TEST_BIN" 1.9.0
run_installer check || die "check rejected a version newer than the pin."
run_installer install >/dev/null || die "install downgraded a self-upgraded binary back to the pin."
assert_contains "$("$TEST_BIN" -version)" v1.9.0

# 低于 pin 的旧二进制要被换掉。
make_asset 1.5.1
write_fake_cli "$TEST_BIN" 1.0.0
if run_installer check 2>/dev/null; then
  die "check accepted a version older than the pin."
fi
run_installer install >/dev/null
assert_contains "$("$TEST_BIN" -version)" v1.5.1

# 摘要对不上就装不进去，且现有二进制原样保留。本地要先退回旧版本，否则 binary_ok
# 直接短路，根本走不到下载这一步。
write_fake_cli "$TEST_BIN" 1.0.0
ASSET_SHA=0000000000000000000000000000000000000000000000000000000000000000
if run_installer install >/dev/null 2>&1; then
  die "install accepted an asset whose checksum did not match."
fi
assert_contains "$("$TEST_BIN" -version)" v1.0.0

# 摘要表和 HCLIENT_CLI_VERSION 不一致时也要拦下来：字节没坏，版本却低于 pin。
make_asset 1.0.0
if run_installer install >/dev/null 2>&1; then
  die "install accepted a verified asset older than the pinned version."
fi

# 认不出的目标平台要明确报错，而不是撞上 set -u。
make_asset 1.5.1
TARGET_ARCH=riscv64
if run_installer install >/dev/null 2>&1; then
  die "install accepted an architecture with no published checksum."
fi
TARGET_ARCH=arm64

# daemon 还开着 TUN 时 clean 必须拒绝，而不是把二进制从它脚下抽走。
printf '%s\n' "$TEST_BIN" > "$PS_OUT"
if run_installer clean 2>/dev/null; then
  die "clean removed the binary while hclient-cli was still running."
fi
[[ -x "$TEST_BIN" ]] || die "clean deleted a running hclient-cli binary."

: > "$PS_OUT"
run_installer clean >/dev/null
[[ ! -e "$TEST_BIN" ]] || die "clean left the binary behind when nothing held it."
run_installer clean >/dev/null || die "clean was not idempotent."
