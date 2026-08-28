#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"

WRAPPER="$ROOT/configs/fish/functions/bootmux.fish"
LAYOUT="$ROOT/modules/bootmux/home/.config/tmuxinator/default.yaml"

# The layout is the reason the wrapper can skip settings: it derives root and
# session from $PWD, so `bootmux picker` reaches it the same way the wrapper does.
grep -Fq 'settings.session | default(env.PWD | split("/") | last)' "$LAYOUT"
grep -Fq 'settings.root | default(env.PWD)' "$LAYOUT"

# install.sh reaches ~/.config/tmuxinator/default.yaml through link_module_home,
# which enumerates modules/bootmux/home with `git ls-files --cached --others
# --exclude-standard`. A gitignored or moved layout silently stops being linked.
git -C "$ROOT" ls-files --cached --others --exclude-standard \
  -- modules/bootmux/home/.config/tmuxinator/default.yaml | grep -q . || {
  echo "default.yaml is not Git-visible, so install.sh will not link it" >&2
  exit 1
}

if command -v bootmux >/dev/null 2>&1; then
  # --backend tmux only prints a shell script, so this stays read-only. Herdr's
  # planner would name a socket and the repo forbids probes that start servers.
  plan="$(cd "$ROOT" && bootmux debug --backend tmux -p "$LAYOUT" 2>&1)"
  assert_contains "$plan" '-s dotfiles'
  assert_contains "$plan" '.0 -T claude'
  assert_contains "$plan" '.1 -T shell'
  # Left pane runs claude; the right one is a bare shell, so it gets no send-keys.
  assert_contains "$plan" 'send-keys -t dotfiles:0.0 claude'
  if [[ "$plan" == *'send-keys -t dotfiles:0.1'* ]]; then
    echo "Expected the right pane to stay a plain shell" >&2
    exit 1
  fi
fi

command -v fish >/dev/null 2>&1 || exit 0
FISH_BIN="$(command -v fish)"
new_test_root

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/plain" "$TEST_ROOT/haslocal"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*"' > "$TEST_ROOT/bin/bootmux"
chmod +x "$TEST_ROOT/bin/bootmux"
: > "$TEST_ROOT/haslocal/.tmuxinator.yml"

dispatch() {
  local dir="$1"
  shift
  PATH="$TEST_ROOT/bin:/usr/bin:/bin" WRAPPER="$WRAPPER" DIR="$dir" \
    "$FISH_BIN" --no-config -c 'source $WRAPPER; cd $DIR; bootmux $argv' -- "$@"
}

expect() {
  local want="$1" got="$2"
  [[ "$want" == "$got" ]] || {
    echo "Expected forwarded args '$want', got '$got'" >&2
    exit 1
  }
}

# Bare start/stop in a directory with no project file falls back to `default`.
expect 'start default' "$(dispatch "$TEST_ROOT/plain" start)"
expect 's default' "$(dispatch "$TEST_ROOT/plain" s)"
expect 'stop default' "$(dispatch "$TEST_ROOT/plain" stop)"
# Anything the user spelled out themselves goes through untouched.
expect 'start dev root=/x' "$(dispatch "$TEST_ROOT/plain" start dev root=/x)"
expect 'list' "$(dispatch "$TEST_ROOT/plain" list)"
expect 'start' "$(dispatch "$TEST_ROOT/haslocal" start)"

echo "bootmux default layout checks passed."
