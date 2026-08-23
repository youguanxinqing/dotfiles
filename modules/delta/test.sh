#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

export GIT_CONFIG_GLOBAL="$TEST_ROOT/gitconfig"
HOME="$TEST_ROOT/home" "$ROOT/modules/delta/post-install.sh"
HOME="$TEST_ROOT/home" "$ROOT/modules/delta/post-install.sh"
[[ "$(git config --global --get core.pager)" == delta ]]
[[ "$(git config --global --get interactive.diffFilter)" == 'delta --color-only' ]]
[[ "$(git config --global --get delta.navigate)" == true ]]
[[ "$(git config --global --get merge.conflictStyle)" == zdiff3 ]]
