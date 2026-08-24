#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

# Cleanup removes module-only packages but keeps packages declared by another module.
BREW_ROOT="$TEST_ROOT/brew"
BREW_HOME="$BREW_ROOT/home"
BREW_BIN="$BREW_ROOT/bin"
mkdir -p "$BREW_HOME" "$BREW_BIN" \
  "$BREW_ROOT/opt/feature-only" "$BREW_ROOT/opt/shared" \
  "$BREW_ROOT/Caskroom/feature-cask"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'if [[ "$1" == uninstall ]]; then' \
  '  printf '\''%s\n'\'' "$*" >> "$BREW_LOG"' \
  'elif [[ "$1" == shellenv ]]; then' \
  '  exit 0' \
  'else' \
  '  exit 1' \
  'fi' > "$BREW_BIN/brew"
printf '#!/usr/bin/env bash\necho Darwin\n' > "$BREW_BIN/uname"
for command in feature-only feature-cask shared; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$BREW_BIN/$command"
  chmod +x "$BREW_BIN/$command"
done
chmod +x "$BREW_BIN/brew" "$BREW_BIN/uname"
printf 'all | feature-only | feature-only | brew | feature-only\nmacos | feature-cask | feature-cask | brew-cask | feature-cask\nall | shared | shared | brew | shared\n' > "$BREW_ROOT/feature.conf"
printf 'all | shared | shared | brew | shared\n' > "$BREW_ROOT/keep.conf"
: > "$BREW_ROOT/brew.log"
PATH="$BREW_BIN:/usr/bin:/bin" HOME="$BREW_HOME" BREW_LOG="$BREW_ROOT/brew.log" \
  "$ROOT/scripts/install-deps.sh" --clean "$BREW_ROOT/feature.conf" "$BREW_ROOT/keep.conf"
grep -Fqx 'uninstall feature-only' "$BREW_ROOT/brew.log"
grep -Fqx 'uninstall --cask feature-cask' "$BREW_ROOT/brew.log"
if grep -Fq shared "$BREW_ROOT/brew.log"; then
  echo "Dependency cleanup removed a shared package." >&2
  exit 1
fi

# A command from the wrong source does not satisfy a Homebrew declaration.
SOURCE_ROOT="$TEST_ROOT/brew-source"
SOURCE_HOME="$SOURCE_ROOT/home"
SOURCE_BREW_BIN="$SOURCE_ROOT/bin"
SOURCE_WRONG_BIN="$SOURCE_ROOT/wrong-bin"
SOURCE_CELLAR="$SOURCE_ROOT/opt"
SOURCE_LOG="$SOURCE_ROOT/brew.log"
mkdir -p "$SOURCE_HOME" "$SOURCE_BREW_BIN" "$SOURCE_WRONG_BIN" "$SOURCE_CELLAR"
printf '#!/usr/bin/env bash\nexit 0\n' > "$SOURCE_WRONG_BIN/demo"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'case "${1:-} ${2:-}" in' \
  '  "shellenv bash") printf '\''export PATH="%s:$PATH"\n'\'' "$BREW_SOURCE_BIN" ;;' \
  '  "install demo")' \
  '    mkdir -p "$BREW_SOURCE_CELLAR/demo"' \
  '    printf '\''#!/usr/bin/env bash\nexit 0\n'\'' > "$BREW_SOURCE_BIN/demo"' \
  '    chmod +x "$BREW_SOURCE_BIN/demo"' \
  '    printf '\''%s\n'\'' "$*" >> "$BREW_SOURCE_LOG"' \
  '    ;;' \
  '  *) exit 1 ;;' \
  'esac' > "$SOURCE_BREW_BIN/brew"
printf '#!/usr/bin/env bash\necho Linux\n' > "$SOURCE_BREW_BIN/uname"
chmod +x "$SOURCE_WRONG_BIN/demo" "$SOURCE_BREW_BIN/brew" "$SOURCE_BREW_BIN/uname"
printf 'all | demo | demo | brew | demo\n' > "$SOURCE_ROOT/normalized.manifest"
: > "$SOURCE_LOG"
PATH="$SOURCE_WRONG_BIN:$SOURCE_BREW_BIN:/usr/bin:/bin" HOME="$SOURCE_HOME" \
  BREW_SOURCE_BIN="$SOURCE_BREW_BIN" BREW_SOURCE_CELLAR="$SOURCE_CELLAR" \
  BREW_SOURCE_LOG="$SOURCE_LOG" \
  "$ROOT/scripts/install-deps.sh" "$SOURCE_ROOT/normalized.manifest"
grep -Fqx 'install demo' "$SOURCE_LOG"

# A module-local script can implement an arbitrary lifecycle without a central adapter edit.
SCRIPT_ROOT="$TEST_ROOT/script-repo"
SCRIPT_HOME="$TEST_ROOT/script-home"
SCRIPT_BIN="$SCRIPT_ROOT/bin"
mkdir -p "$SCRIPT_ROOT/scripts" "$SCRIPT_ROOT/modules/fail" "$SCRIPT_ROOT/modules/demo" "$SCRIPT_BIN" "$SCRIPT_HOME"
cp "$ROOT/scripts/install-deps.sh" "$SCRIPT_ROOT/scripts/install-deps.sh"
printf '#!/usr/bin/env bash\n[[ "$1" == shellenv ]]\n' > "$SCRIPT_BIN/brew"
printf '#!/usr/bin/env bash\necho Linux\n' > "$SCRIPT_BIN/uname"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "$1" in check | install) exit 1 ;; clean) exit 0 ;; esac' > "$SCRIPT_ROOT/modules/fail/install.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'case "$1" in' \
  '  check) command -v demo-cli >/dev/null 2>&1 ;;' \
  '  install) printf '\''#!/usr/bin/env bash\nexit 0\n'\'' > "$SCRIPT_TEST_BIN/demo-cli"; chmod +x "$SCRIPT_TEST_BIN/demo-cli" ;;' \
  '  clean) rm -f "$SCRIPT_TEST_BIN/demo-cli" ;;' \
  'esac' > "$SCRIPT_ROOT/modules/demo/install.sh"
printf 'linux | fail | fail-cli | script | modules/fail/install.sh\nlinux | demo | demo-cli | script | modules/demo/install.sh\nmacos | mac-only | mac-only | script | modules/demo/install.sh\n' > "$SCRIPT_ROOT/normalized.manifest"
chmod +x "$SCRIPT_BIN/brew" "$SCRIPT_BIN/uname" "$SCRIPT_ROOT/modules/fail/install.sh" "$SCRIPT_ROOT/modules/demo/install.sh"
export SCRIPT_TEST_BIN="$SCRIPT_BIN"
if PATH="$SCRIPT_BIN:/usr/bin:/bin" HOME="$SCRIPT_HOME" \
  "$SCRIPT_ROOT/scripts/install-deps.sh" "$SCRIPT_ROOT/normalized.manifest"; then
  echo "Dependency installation ignored a failed module." >&2
  exit 1
fi
[[ -x "$SCRIPT_BIN/demo-cli" ]]
[[ ! -e "$SCRIPT_BIN/mac-only" ]]
PATH="$SCRIPT_BIN:/usr/bin:/bin" HOME="$SCRIPT_HOME" \
  "$SCRIPT_ROOT/scripts/install-deps.sh" --clean "$SCRIPT_ROOT/normalized.manifest"
[[ ! -e "$SCRIPT_BIN/demo-cli" ]]

# A failed Homebrew bootstrap is aggregated and does not hide a later script result.
BOOT_ROOT="$TEST_ROOT/bootstrap-repo"
BOOT_HOME="$TEST_ROOT/bootstrap-home"
BOOT_BIN="$BOOT_ROOT/bin"
mkdir -p "$BOOT_ROOT/scripts" "$BOOT_ROOT/modules/demo" "$BOOT_BIN" "$BOOT_HOME"
cp "$ROOT/scripts/install-deps.sh" "$BOOT_ROOT/scripts/install-deps.sh"
sed -i.bak 's|for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do|for candidate in "$BOOTSTRAP_BREW"; do|' \
  "$BOOT_ROOT/scripts/install-deps.sh"
printf '#!/usr/bin/env bash\necho Darwin\n' > "$BOOT_BIN/uname"
printf '#!/usr/bin/env bash\nexit 1\n' > "$BOOT_BIN/curl"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "$1" in' \
  '  check) test -x "$BOOTSTRAP_BIN/demo" ;;' \
  '  install) printf '\''#!/usr/bin/env bash\nexit 0\n'\'' > "$BOOTSTRAP_BIN/demo"; chmod +x "$BOOTSTRAP_BIN/demo" ;;' \
  '  clean) exit 0 ;;' \
  'esac' > "$BOOT_ROOT/modules/demo/install.sh"
printf 'all | missing-brew | missing-brew | brew | missing-brew\nall | demo | demo | script | modules/demo/install.sh\n' > "$BOOT_ROOT/normalized.manifest"
chmod +x "$BOOT_BIN/uname" "$BOOT_BIN/curl" "$BOOT_ROOT/modules/demo/install.sh"
if PATH="$BOOT_BIN:/usr/bin:/bin" HOME="$BOOT_HOME" BOOTSTRAP_BIN="$BOOT_BIN" \
  BOOTSTRAP_BREW="$BOOT_ROOT/no-brew" \
  "$BOOT_ROOT/scripts/install-deps.sh" "$BOOT_ROOT/normalized.manifest" >/dev/null 2>&1; then
  echo "Homebrew bootstrap failure was not reported." >&2
  exit 1
fi
[[ -x "$BOOT_BIN/demo" ]]

# Dry-run describes toolchain dependencies that an earlier planned module will
# provide; it must not fail merely because those commands do not exist yet.
DRY_ROOT="$TEST_ROOT/dry-toolchains"
DRY_HOME="$DRY_ROOT/home"
DRY_BIN="$DRY_ROOT/bin"
mkdir -p "$DRY_HOME" "$DRY_BIN"
printf '#!/usr/bin/env bash\necho Linux\n' > "$DRY_BIN/uname"
chmod +x "$DRY_BIN/uname"
printf '%s\n' \
  'all | planned-cargo | planned-cargo | rustup | stable' \
  'all | planned-node | planned-node | fnm | lts' \
  'all | planned-rust-cli | planned-rust-cli | cargo | planned-rust-cli' \
  'all | planned-go-cli | planned-go-cli | go | example.com/planned@latest' \
  'all | planned-node-cli | planned-node-cli | npm | planned-node-cli' \
  > "$DRY_ROOT/normalized.manifest"
PATH="$DRY_BIN:/usr/bin:/bin" HOME="$DRY_HOME" \
  "$ROOT/scripts/install-deps.sh" --dry-run "$DRY_ROOT/normalized.manifest" > "$DRY_ROOT/output"
grep -Fq '+ rustup default stable' "$DRY_ROOT/output"
grep -Fq '+ fnm install --lts' "$DRY_ROOT/output"
grep -Fq '+ cargo install planned-rust-cli' "$DRY_ROOT/output"
grep -Fq '+ go install example.com/planned@latest' "$DRY_ROOT/output"
grep -Fq '+ npm install --global planned-node-cli' "$DRY_ROOT/output"
