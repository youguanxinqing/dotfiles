#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"

# Codex skips only harmless trust prompts; project-local config still requires consent.
command -v fish >/dev/null 2>&1 || exit 0
new_test_root

FISH_BIN="$(command -v fish)"
TEST_BIN="$TEST_ROOT/bin"
TEST_REPO="$TEST_ROOT/repo"
mkdir -p "$TEST_BIN" "$TEST_REPO/child"
git -C "$TEST_REPO" init -q
REPO_ROOT="$(git -C "$TEST_REPO" rev-parse --show-toplevel)"
printf '#!/usr/bin/env bash\nprintf '\''%%s\\n'\'' "$@" > "$CODEX_TEST_LOG"\n' > "$TEST_BIN/codex"
chmod +x "$TEST_BIN/codex"

PATH="$TEST_BIN:/usr/bin:/bin" CODEX_TEST_LOG="$TEST_ROOT/codex.log" \
  CODEX_FUNCTION="$ROOT/configs/fish/functions/codex.fish" CODEX_REPO="$TEST_REPO" \
  "$FISH_BIN" --no-config -c 'source "$CODEX_FUNCTION"; cd "$CODEX_REPO/child"; codex launch'
grep -Fqx -- '-c' "$TEST_ROOT/codex.log"
grep -Fqx "projects.\"$REPO_ROOT\".trust_level=\"untrusted\"" "$TEST_ROOT/codex.log"

mkdir "$TEST_REPO/.codex"
PATH="$TEST_BIN:/usr/bin:/bin" CODEX_TEST_LOG="$TEST_ROOT/codex.log" \
  CODEX_FUNCTION="$ROOT/configs/fish/functions/codex.fish" CODEX_REPO="$TEST_REPO" \
  "$FISH_BIN" --no-config -c 'source "$CODEX_FUNCTION"; cd "$CODEX_REPO/child"; codex launch'
[[ "$(cat "$TEST_ROOT/codex.log")" == launch ]]
