#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

# The privacy checker derives its root from its own path, so the fixture is a
# whole throwaway worktree holding a copy of it. `git ls-files --others` picks
# up the fixture files, so no commit is needed.
FIXTURE="$TEST_ROOT/repo"
mkdir -p "$FIXTURE/scripts"
cp "$ROOT/scripts/check-private.sh" "$FIXTURE/scripts/check-private.sh"
git -C "$FIXTURE" init -q

check_fixture() {
  (cd "$FIXTURE" && bash scripts/check-private.sh 2>&1)
}

# Private addresses are assembled from octets instead of written out: this repo
# has to pass its own check, and a literal quad in a fixture would fail it.
quad() { printf '%s.%s.%s.%s' "$1" "$2" "$3" "$4"; }

# Version numbers and two-octet prefixes are not addresses. `v0.10.0` in the
# Herdr plugin list used to match `10.` and failed the check on a clean tree.
printf '%s\n' \
  'qintmb/herdr-theme-picker|v0.10.0|herdr-theme-picker' \
  'quad = 1.10.0.0' \
  'cdn = 172.32.0.1' > "$FIXTURE/versions.list"
out="$(check_fixture)" || {
  printf '%s\n' "$out" >&2
  die "Privacy check flagged version numbers as private addresses."
}
assert_contains "$out" "No obvious private data found"

# Real addresses must still be caught: all three private blocks, any octet
# length. Lines 5 and 6 are public and short, and must stay quiet.
{
  printf 'lan = %s\n' "$(quad 10 0 0 5)"
  printf 'router = %s:7890\n' "$(quad 192 168 1 10)"
  printf 'dmz = %s\n' "$(quad 172 16 3 4)"
  printf 'top = %s\n' "$(quad 172 31 255 254)"
  printf 'cdn = %s\n' "$(quad 172 32 0 1)"
  printf 'short = %s.%s\n' 10 5
} > "$FIXTURE/network.conf"

if out="$(check_fixture)"; then
  die "Privacy check passed a fixture holding private network addresses."
fi
for line in 1 2 3 4; do
  assert_contains "$out" "network.conf:$line: possible private network address"
done
for line in 5 6; do
  [[ "$out" != *"network.conf:$line:"* ]] || {
    printf '%s\n' "$out" >&2
    die "Privacy check flagged network.conf:$line, which holds no private address."
  }
done

echo "check-private checks passed."
