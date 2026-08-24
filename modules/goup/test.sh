#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

TEST_HOME="$TEST_ROOT/home"
TEST_BIN="$TEST_ROOT/bin"
mkdir -p "$TEST_HOME" "$TEST_BIN"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "$1" in' \
  '  init) mkdir -p "$HOME/.goup/current/bin"; : > "$HOME/.goup/env" ;;' \
  '  install) printf '\''#!/usr/bin/env bash\nexit 0\n'\'' > "$HOME/.goup/current/bin/go"; chmod +x "$HOME/.goup/current/bin/go" ;;' \
'esac' > "$TEST_ROOT/goup-template"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "${1:-} ${2:-}" in' \
  '  "install goup-rs")' \
  '    mkdir -p "$CARGO_INSTALL_ROOT/bin"' \
  '    cp "$GOUP_TEST_TEMPLATE" "$CARGO_INSTALL_ROOT/bin/goup"' \
  '    chmod +x "$CARGO_INSTALL_ROOT/bin/goup"' \
  '    ;;' \
  '  "install --list")' \
  '    [[ -x "$CARGO_INSTALL_ROOT/bin/goup" ]] && printf "goup-rs v0.16.0:\n"' \
  '    ;;' \
  '  "uninstall goup-rs") rm -f "$CARGO_INSTALL_ROOT/bin/goup" ;;' \
  'esac' > "$TEST_BIN/cargo"
chmod +x "$TEST_BIN/cargo"

PATH="$TEST_BIN:$TEST_HOME/.goup/current/bin:/usr/bin:/bin" HOME="$TEST_HOME" \
  GOUP_TEST_TEMPLATE="$TEST_ROOT/goup-template" \
  "$ROOT/modules/goup/install.sh" install
[[ -x "$TEST_HOME/.local/bin/goup" ]]
PATH="$TEST_HOME/.local/bin:$TEST_BIN:$TEST_HOME/.goup/current/bin:/usr/bin:/bin" HOME="$TEST_HOME" \
  "$ROOT/modules/goup/install.sh" check
PATH="$TEST_BIN:/usr/bin:/bin" HOME="$TEST_HOME" GOUP_TEST_TEMPLATE="$TEST_ROOT/goup-template" \
  "$ROOT/modules/goup/install.sh" clean
[[ ! -e "$TEST_HOME/.local/bin/goup" ]]
PATH="$TEST_BIN:/usr/bin:/bin" HOME="$TEST_HOME" GOUP_TEST_TEMPLATE="$TEST_ROOT/goup-template" \
  "$ROOT/modules/goup/install.sh" clean
