#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

SUBL="$ROOT/modules/sublime-text/install.sh"
TEST_HOME="$TEST_ROOT/home"
APP_BIN="$TEST_HOME/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl"
mkdir -p "$(dirname "$APP_BIN")" "$TEST_HOME/.local/bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$APP_BIN"
chmod +x "$APP_BIN"

# 没链之前 check 必须失败，否则 install 永远不会被触发。
! HOME="$TEST_HOME" "$SUBL" check || die "check passed before the link existed"
HOME="$TEST_HOME" "$SUBL" install
assert_link "$TEST_HOME/.local/bin/subl" "$APP_BIN"
HOME="$TEST_HOME" "$SUBL" check
HOME="$TEST_HOME" "$SUBL" install
assert_link "$TEST_HOME/.local/bin/subl" "$APP_BIN"

# 别人的 subl 不覆盖，也不在 clean 里删。
ln -sfn /usr/bin/true "$TEST_HOME/.local/bin/subl"
! HOME="$TEST_HOME" "$SUBL" install 2>/dev/null || die "install replaced an unmanaged subl"
assert_link "$TEST_HOME/.local/bin/subl" /usr/bin/true
HOME="$TEST_HOME" "$SUBL" clean
assert_link "$TEST_HOME/.local/bin/subl" /usr/bin/true

rm "$TEST_HOME/.local/bin/subl"
HOME="$TEST_HOME" "$SUBL" install
HOME="$TEST_HOME" "$SUBL" clean
[ ! -e "$TEST_HOME/.local/bin/subl" ] || die "clean left the link behind"
HOME="$TEST_HOME" "$SUBL" clean

# Sublime 不在的机器上 check 失败即可，不能报错刷屏。
rm -rf "$TEST_HOME/Applications"
! HOME="$TEST_HOME" "$SUBL" check || die "check passed without Sublime installed"

echo "sublime-text checks passed."
