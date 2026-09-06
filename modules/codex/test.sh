#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

TEST_HOME="$TEST_ROOT/home"
TEST_STATE="$TEST_ROOT/state/links.tsv"
PROFILE="$ROOT/modules/codex/dotfiles.config.toml"
TARGET="$TEST_HOME/.codex/dotfiles.config.toml"
mkdir -p "$TEST_HOME"

HOME="$TEST_HOME" DOTFILES_STATE_FILE="$TEST_STATE" \
  "$ROOT/install.sh" --links-only codex >/dev/null
assert_regular_file "$TARGET"
cmp -s "$PROFILE" "$TARGET" || die "Deployed Codex profile differs from the repository copy."

grep -Fq 'five-hour-limit' "$PROFILE"
grep -Fq 'weekly-limit' "$PROFILE"
grep -Fq 'estimated-thread-cost' "$PROFILE"
if grep -Eq '/Users/|^\[projects\.|^\[hooks\.state|^\[marketplaces\.' "$PROFILE"; then
  die "Codex profile contains machine-local state."
fi

# Codex 写回 profile 是常态（目录信任、NUX 计数）。仓库那份必须纹丝不动，
# 否则 /Users/... 绝对路径会跟着 commit 进公开仓库。
BEFORE="$(cat "$PROFILE")"
printf '\n[projects."/Users/nobody"]\ntrust_level = "trusted"\n' >> "$TARGET"
HOME="$TEST_HOME" DOTFILES_STATE_FILE="$TEST_STATE" \
  "$ROOT/install.sh" --links-only codex >/dev/null
[ "$BEFORE" = "$(cat "$PROFILE")" ] || die "Codex write-back reached the repository profile."
assert_regular_file "$TARGET"
