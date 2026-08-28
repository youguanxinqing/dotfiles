#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

TEST_BIN="$TEST_ROOT/bin"
TEST_LOG="$TEST_ROOT/herdr.log"
mkdir -p "$TEST_BIN"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "$1 $2" == "plugin list" ]]; then' \
  '  echo "- heeler (heeler) disabled [github:ZingerLittleBee/Heeler/plugin@main]"' \
  '  echo "- rmarganti.herdr-pluck (Herdr Pluck) enabled [github:rmarganti/herdr-pluck@v0.3.0]"' \
  'elif [[ "$1 $2" == "plugin install" ]]; then' \
  '  echo "install $3" >> "$HERDR_TEST_LOG"' \
  '  [[ "$3" != rmarganti/herdr-pluck ]] || echo "pluck source=${HERDR_PLUCK_BUILD_FROM_SOURCE:-0}" >> "$HERDR_TEST_LOG"' \
  '  [[ "$3" != cinco/herdr-grep-nvim ]]' \
  'elif [[ "$1 $2" == "plugin enable" ]]; then' \
  '  echo "enable $3" >> "$HERDR_TEST_LOG"' \
  'elif [[ "$1 $2" == "plugin link" ]]; then' \
  '  echo "link ${3##*/}" >> "$HERDR_TEST_LOG"' \
  'else' \
  '  exit 1' \
  'fi' > "$TEST_BIN/herdr"
chmod +x "$TEST_BIN/herdr"
: > "$TEST_LOG"

if PATH="$TEST_BIN:/usr/bin:/bin" HERDR_TEST_LOG="$TEST_LOG" \
  "$ROOT/modules/herdr/install.sh" install >/dev/null 2>&1; then
  echo "Herdr plugin installation ignored a failed plugin." >&2
  exit 1
fi
grep -Fqx 'enable heeler' "$TEST_LOG"
grep -Fqx 'install ntindle/herdr-resurrect' "$TEST_LOG"
grep -Fqx 'install rmarganti/herdr-pluck' "$TEST_LOG"
grep -Fqx 'pluck source=1' "$TEST_LOG"
grep -Fqx 'install youguanxinqing/herdr-flash' "$TEST_LOG"
# 本地插件（manifest 在仓库里）走 plugin link，不是 plugin install。
grep -Fqx 'link nvim-here' "$TEST_LOG"
grep -Fqx 'link worktree-links' "$TEST_LOG"
if grep -Fq 'install nvim-here' "$TEST_LOG"; then
  echo "Herdr tried to install a local plugin from GitHub." >&2
  exit 1
fi
if grep -Fq 'install ZingerLittleBee/Heeler/plugin' "$TEST_LOG"; then
  echo "Herdr reinstalled a disabled plugin instead of enabling it." >&2
  exit 1
fi
