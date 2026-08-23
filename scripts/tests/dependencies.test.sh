#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

# Cleanup removes module-only packages but keeps packages declared by another module.
BREW_ROOT="$TEST_ROOT/brew"
BREW_HOME="$BREW_ROOT/home"
BREW_BIN="$BREW_ROOT/bin"
mkdir -p "$BREW_HOME" "$BREW_BIN"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'if [[ "$1" == list && ("$2" == --formula || "$2" == --cask) ]]; then' \
  '  exit 0' \
  'elif [[ "$1" == uninstall ]]; then' \
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
