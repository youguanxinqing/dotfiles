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
  'esac' > "$TEST_BIN/goup"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_BIN/cargo"
chmod +x "$TEST_BIN/goup" "$TEST_BIN/cargo"

PATH="$TEST_BIN:$TEST_HOME/.goup/current/bin:/usr/bin:/bin" HOME="$TEST_HOME" \
  "$ROOT/modules/goup/install.sh" install
PATH="$TEST_BIN:$TEST_HOME/.goup/current/bin:/usr/bin:/bin" HOME="$TEST_HOME" \
  "$ROOT/modules/goup/install.sh" check
PATH="$TEST_BIN:/usr/bin:/bin" HOME="$TEST_HOME" "$ROOT/modules/goup/install.sh" clean
PATH="$TEST_BIN:/usr/bin:/bin" HOME="$TEST_HOME" "$ROOT/modules/goup/install.sh" clean
