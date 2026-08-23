#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

TEST_HOME="$TEST_ROOT/home"
TEST_STATE="$TEST_ROOT/state/links.tsv"
mkdir -p "$TEST_HOME"

[[ -f "$ROOT/configs/kitty/theme.conf" ]] || { echo "Kitty theme must be a regular file." >&2; exit 1; }
[[ -x "$ROOT/bin/tmux-cleanup-scratch" && -x "$ROOT/bin/tmux-swap-scratch" && -x "$ROOT/bin/tmux-toggle-scratch" ]] || {
  echo "tmux helpers must be executable." >&2
  exit 1
}

# Common modules are idempotent, and overlay modules discover every Git-visible file.
HOME="$TEST_HOME" DOTFILES_STATE_FILE="$TEST_STATE" \
  "$ROOT/install.sh" --links-only fish herdr tmux bin >/dev/null
HOME="$TEST_HOME" DOTFILES_STATE_FILE="$TEST_STATE" \
  "$ROOT/install.sh" --links-only fish herdr tmux bin >/dev/null
assert_link "$TEST_HOME/.config/fish" "$ROOT/configs/fish"
assert_link "$TEST_HOME/.config/herdr/config.toml" "$ROOT/configs/herdr/config.toml"
assert_link "$TEST_HOME/.local/bin/herdr-smart-tab" "$ROOT/bin/herdr-smart-tab"
assert_link "$TEST_HOME/.tmux.conf" "$ROOT/configs/tmux/tmux.conf"
assert_link "$TEST_HOME/.local/bin/tmux-toggle-scratch" "$ROOT/bin/tmux-toggle-scratch"

# Platform selection and targets stay inside each module.
MAC_BIN="$TEST_ROOT/mac-bin"
LINUX_BIN="$TEST_ROOT/linux-bin"
MAC_HOME="$TEST_ROOT/mac-home"
LINUX_HOME="$TEST_ROOT/linux-home"
mkdir -p "$MAC_BIN" "$LINUX_BIN" "$MAC_HOME" "$LINUX_HOME"
printf '#!/usr/bin/env bash\necho Darwin\n' > "$MAC_BIN/uname"
printf '#!/usr/bin/env bash\necho Linux\n' > "$LINUX_BIN/uname"
chmod +x "$MAC_BIN/uname" "$LINUX_BIN/uname"
PATH="$MAC_BIN:$PATH" HOME="$MAC_HOME" DOTFILES_STATE_FILE="$TEST_ROOT/mac-state" \
  "$ROOT/install.sh" --links-only ghostty hammerspoon >/dev/null
assert_link "$MAC_HOME/Library/Application Support/com.mitchellh.ghostty" "$ROOT/configs/ghostty"
assert_link "$MAC_HOME/.hammerspoon" "$ROOT/configs/hammerspoon"
PATH="$LINUX_BIN:$PATH" HOME="$LINUX_HOME" DOTFILES_STATE_FILE="$TEST_ROOT/linux-state" \
  "$ROOT/install.sh" --links-only ghostty >/dev/null
assert_link "$LINUX_HOME/.config/ghostty" "$ROOT/configs/ghostty"
if PATH="$LINUX_BIN:$PATH" HOME="$LINUX_HOME" "$ROOT/install.sh" --links-only hammerspoon >/dev/null 2>&1; then
  echo "Linux accepted a macOS-only module." >&2
  exit 1
fi

# Unmanaged destinations are never replaced.
CONFLICT_HOME="$TEST_ROOT/conflict-home"
mkdir -p "$CONFLICT_HOME/.config/fish"
conflict_output="$(HOME="$CONFLICT_HOME" DOTFILES_STATE_FILE="$TEST_ROOT/conflict-state" \
  "$ROOT/install.sh" --links-only fish)"
assert_contains "$conflict_output" "Skipped unmanaged path: $CONFLICT_HOME/.config/fish"
[[ -d "$CONFLICT_HOME/.config/fish" && ! -L "$CONFLICT_HOME/.config/fish" ]]

# Repository-owned links can be migrated, and module-local link hooks run in links-only mode.
LEGACY_HOME="$TEST_ROOT/legacy-home"
mkdir -p "$LEGACY_HOME/.config" "$LEGACY_HOME/.tmux"
ln -s "$ROOT/fish" "$LEGACY_HOME/.config/fish"
ln -s "$ROOT/configs/tmux/bin" "$LEGACY_HOME/.tmux/bin"
HOME="$LEGACY_HOME" DOTFILES_STATE_FILE="$TEST_ROOT/legacy-state" \
  "$ROOT/install.sh" --links-only fish tmux >/dev/null
assert_link "$LEGACY_HOME/.config/fish" "$ROOT/configs/fish"
[[ ! -e "$LEGACY_HOME/.tmux/bin" && ! -L "$LEGACY_HOME/.tmux/bin" ]]

# The open/closed boundary: a whole capability and later files are discovered
# from modules/<name>/ without editing install.sh, a registry, or a test list.
SYNTH_ROOT="$TEST_ROOT/repo"
SYNTH_HOME="$TEST_ROOT/synth-home"
SYNTH_STATE="$TEST_ROOT/synth-state/links.tsv"
mkdir -p "$SYNTH_ROOT/scripts" "$SYNTH_ROOT/modules/demo/home/.config/demo" "$SYNTH_HOME"
cp "$ROOT/install.sh" "$SYNTH_ROOT/install.sh"
cp "$ROOT/scripts/module-engine.sh" "$SYNTH_ROOT/scripts/module-engine.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '[[ "$1" != --clean ]] || shift' \
  'cp "$1" "$DEPS_LOG"' > "$SYNTH_ROOT/scripts/install-deps.sh"
printf '%s\n' \
  '[module]' \
  'platforms = all' \
  'order = 10' \
  '' \
  '[dependency demo]' \
  'command = demo' \
  'installer = script' \
  'source = install.sh' > "$SYNTH_ROOT/modules/demo/module.ini"
printf '#!/usr/bin/env bash\nexit 0\n' > "$SYNTH_ROOT/modules/demo/install.sh"
printf '#!/usr/bin/env bash\nprintf '\''hook\\n'\'' > "$HOOK_LOG"\n' > "$SYNTH_ROOT/modules/demo/post-install.sh"
printf 'first\n' > "$SYNTH_ROOT/modules/demo/home/.config/demo/first.conf"
printf '*.runtime\n' > "$SYNTH_ROOT/.gitignore"
printf 'private\n' > "$SYNTH_ROOT/modules/demo/home/.config/demo/cache.runtime"
chmod +x "$SYNTH_ROOT/install.sh" "$SYNTH_ROOT/scripts/install-deps.sh"
git -C "$SYNTH_ROOT" init -q

list_output="$(PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" "$SYNTH_ROOT/install.sh" list)"
assert_contains "$list_output" "demo"
PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DEPS_LOG="$TEST_ROOT/deps.log" HOOK_LOG="$TEST_ROOT/hook.log" \
  "$SYNTH_ROOT/install.sh" --deps-only demo >/dev/null
grep -Fqx 'all | demo | demo | script | modules/demo/install.sh' "$TEST_ROOT/deps.log"
grep -Fqx hook "$TEST_ROOT/hook.log"
PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" \
  "$SYNTH_ROOT/install.sh" --links-only demo >/dev/null
assert_link "$SYNTH_HOME/.config/demo/first.conf" "$SYNTH_ROOT/modules/demo/home/.config/demo/first.conf"
[[ ! -e "$SYNTH_HOME/.config/demo/cache.runtime" ]]

printf 'second\n' > "$SYNTH_ROOT/modules/demo/home/.config/demo/second.conf"
PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" \
  "$SYNTH_ROOT/install.sh" --links-only demo >/dev/null
assert_link "$SYNTH_HOME/.config/demo/second.conf" "$SYNTH_ROOT/modules/demo/home/.config/demo/second.conf"

PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" DEPS_LOG="$TEST_ROOT/clean-deps.log" \
  "$SYNTH_ROOT/install.sh" clean demo >/dev/null
[[ ! -e "$SYNTH_HOME/.config/demo/first.conf" && ! -L "$SYNTH_HOME/.config/demo/first.conf" ]]
[[ ! -e "$SYNTH_HOME/.config/demo/second.conf" && ! -L "$SYNTH_HOME/.config/demo/second.conf" ]]

# Strict parsing rejects ambiguous author-facing configuration.
mkdir -p "$SYNTH_ROOT/modules/broken"
printf '%s\n' \
  '[module]' \
  'order = 10' \
  'order = 20' > "$SYNTH_ROOT/modules/broken/module.ini"
if PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" "$SYNTH_ROOT/install.sh" list >"$TEST_ROOT/invalid.out" 2>&1; then
  echo "module.ini accepted a duplicate key." >&2
  exit 1
fi
grep -Fq 'duplicate module key: order' "$TEST_ROOT/invalid.out"

printf '%s\n' \
  '[module]' \
  'mystery = value' > "$SYNTH_ROOT/modules/broken/module.ini"
if PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" "$SYNTH_ROOT/install.sh" list >"$TEST_ROOT/invalid.out" 2>&1; then
  echo "module.ini accepted an unknown key." >&2
  exit 1
fi
grep -Fq 'unknown module key: mystery' "$TEST_ROOT/invalid.out"

printf '%s\n' \
  '[module]' \
  '' \
  '[dependency broken]' \
  'installer = brew' \
  'source = broken' > "$SYNTH_ROOT/modules/broken/module.ini"
if PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" "$SYNTH_ROOT/install.sh" list >"$TEST_ROOT/invalid.out" 2>&1; then
  echo "module.ini accepted a missing dependency field." >&2
  exit 1
fi
grep -Fq 'dependency broken is missing command' "$TEST_ROOT/invalid.out"
