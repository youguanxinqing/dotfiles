#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"

# The repository owns one static user PATH entry, and fzf's embedded Fish
# integration owns the default Ctrl-R/Ctrl-T widgets.
PATH_CONFIG="$ROOT/configs/fish/conf.d/10-paths.fish"
FZF_BINDINGS="$ROOT/configs/fish/functions/fish_user_key_bindings.fish"
grep -Fq 'fish_add_path --global --move --path "$HOME/.local/bin"' "$PATH_CONFIG"
grep -Fq 'set -qU fish_user_paths' "$PATH_CONFIG"
if grep -Eq '\.fzf/bin|go/bin|\.cargo/bin|\.local/share/fnm|flutter/bin' "$PATH_CONFIG"; then
  echo "Unexpected tool-specific directory in the static Fish PATH" >&2
  exit 1
fi
grep -Fq 'type -q fzf; or return' "$FZF_BINDINGS"
grep -Fq 'fzf --fish | source' "$FZF_BINDINGS"

command -v fish >/dev/null 2>&1 || exit 0
new_test_root

FISH_BIN="$(command -v fish)"
TEST_BIN="$TEST_ROOT/bin"
TEST_REPO="$TEST_ROOT/repo"
mkdir -p "$TEST_BIN" "$TEST_REPO/child"

for fish_file in "$ROOT"/configs/fish/config.fish \
  "$ROOT"/configs/fish/conf.d/*.fish "$ROOT"/configs/fish/functions/*.fish; do
  "$FISH_BIN" --no-config -n "$fish_file"
done

# Verify the integration is sourced and installs both requested bindings. The
# fake fzf emits the same bind surface without needing a terminal UI in tests.
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '[[ "${1:-}" == --fish ]] || exit 2' \
  'printf '\''%s\n'\'' '\''function fzf-history-widget; end'\'' '\''function fzf-file-widget; end'\'' '\''bind \\cr fzf-history-widget'\'' '\''bind \\ct fzf-file-widget'\''' \
  > "$TEST_BIN/fzf"
chmod +x "$TEST_BIN/fzf"
bindings="$(PATH="$TEST_BIN:/usr/bin:/bin" FZF_BINDINGS="$FZF_BINDINGS" \
  "$FISH_BIN" --no-config -c 'source "$FZF_BINDINGS"; fish_user_key_bindings; bind \\cr; bind \\ct')"
assert_contains "$bindings" 'fzf-history-widget'
assert_contains "$bindings" 'fzf-file-widget'

# Non-interactive Fish shells must not create an fnm multishell PATH.
printf '%s\n' '#!/usr/bin/env bash' 'printf called > "$FNM_TEST_LOG"' > "$TEST_BIN/fnm"
chmod +x "$TEST_BIN/fnm"
PATH="$TEST_BIN:/usr/bin:/bin" FNM_TEST_LOG="$TEST_ROOT/fnm.log" \
  TOOLCHAINS="$ROOT/configs/fish/conf.d/20-toolchains.fish" \
  "$FISH_BIN" --no-config -c 'source "$TOOLCHAINS"'
[[ ! -e "$TEST_ROOT/fnm.log" ]]

# Codex skips only harmless trust prompts; project-local config still requires consent.
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
