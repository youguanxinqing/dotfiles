#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

# 公开仓库：models.json 只能描述模型，密钥必须留在 auth.json。
if grep -Fq '"apiKey"' "$ROOT/modules/pi/home/.pi/agent/models.json"; then
  die "Pi models.json carries an apiKey; keep credentials in ~/.pi/agent/auth.json."
fi

TEST_BIN="$TEST_ROOT/bin"
TEST_LOG="$TEST_ROOT/pi.log"
mkdir -p "$TEST_BIN"
# 已声明一个，另一个只出现在安装路径里（不能算声明），第三个完全没有。
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "$1" in' \
  '  list) printf "User packages:\n  npm:pi-open-tui\n    /x/node_modules/pi-knowledge\n" ;;' \
  '  install|remove) echo "$1 $2" >> "$PI_TEST_LOG" ;;' \
  '  *) exit 1 ;;' \
  'esac' > "$TEST_BIN/pi"
chmod +x "$TEST_BIN/pi"
: > "$TEST_LOG"

run() { PATH="$TEST_BIN:$TEST_SYSTEM_PATH" PI_TEST_LOG="$TEST_LOG" "$ROOT/modules/pi/install.sh" "$1"; }

if run check; then
  die "Pi package check passed with undeclared packages."
fi
run install >/dev/null
grep -Fqx 'install npm:pi-knowledge' "$TEST_LOG"
grep -Fqx 'install npm:nowledge-mem-pi' "$TEST_LOG"
if grep -Fq 'npm:pi-open-tui' "$TEST_LOG"; then
  die "Pi reinstalled a package that was already declared."
fi

: > "$TEST_LOG"
run clean >/dev/null
[ "$(cat "$TEST_LOG")" = 'remove npm:pi-open-tui' ] || die "Pi clean touched undeclared packages."
