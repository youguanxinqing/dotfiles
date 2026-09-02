#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

TEST_HOME="$TEST_ROOT/home"
TEST_STATE="$TEST_ROOT/state/links.tsv"
PROFILE="$ROOT/modules/codex/home/.codex/dotfiles.config.toml"
mkdir -p "$TEST_HOME"

HOME="$TEST_HOME" DOTFILES_STATE_FILE="$TEST_STATE" \
  "$ROOT/install.sh" --links-only codex >/dev/null
assert_link "$TEST_HOME/.codex/dotfiles.config.toml" "$PROFILE"

grep -Fq 'five-hour-limit' "$PROFILE"
grep -Fq 'weekly-limit' "$PROFILE"
grep -Fq 'estimated-thread-cost' "$PROFILE"
if grep -Eq '/Users/|^\[projects\.|^\[hooks\.state|^\[marketplaces\.' "$PROFILE"; then
  die "Codex profile contains machine-local state."
fi

# A second install must keep the same repository-owned link.
HOME="$TEST_HOME" DOTFILES_STATE_FILE="$TEST_STATE" \
  "$ROOT/install.sh" --links-only codex >/dev/null
assert_link "$TEST_HOME/.codex/dotfiles.config.toml" "$PROFILE"
