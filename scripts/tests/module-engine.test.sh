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
[[ -f "$TEST_HOME/.config/herdr/config.toml" && ! -L "$TEST_HOME/.config/herdr/config.toml" ]]
cmp -s "$TEST_HOME/.config/herdr/config.toml" "$ROOT/configs/herdr/config.toml"
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
grep -Fqx 'config-file = ~/.local/share/dotfiles/current/configs/ghostty/common.conf' \
  "$LINUX_HOME/.config/ghostty/config"
assert_link "$LINUX_HOME/.local/share/dotfiles/current" "$ROOT"
if PATH="$LINUX_BIN:$PATH" HOME="$LINUX_HOME" "$ROOT/install.sh" --links-only hammerspoon >/dev/null 2>&1; then
  echo "Linux accepted a macOS-only module." >&2
  exit 1
fi

# A fresh Omarchy home already contains terminal and Herdr configs. Managed
# entries adopt those files without exposing the repository to refresh writes;
# managed copies restore runtime-only drift and preserve each displaced file.
OMARCHY_HOME="$TEST_ROOT/omarchy-home"
OMARCHY_STATE="$TEST_ROOT/omarchy-state"
mkdir -p "$OMARCHY_HOME/.config/ghostty" "$OMARCHY_HOME/.config/kitty" "$OMARCHY_HOME/.config/herdr"
printf 'omarchy ghostty\n' > "$OMARCHY_HOME/.config/ghostty/config"
printf 'omarchy kitty\n' > "$OMARCHY_HOME/.config/kitty/kitty.conf"
printf 'omarchy herdr\n' > "$OMARCHY_HOME/.config/herdr/config.toml"
PATH="$LINUX_BIN:$PATH" HOME="$OMARCHY_HOME" DOTFILES_STATE_FILE="$OMARCHY_STATE/links.tsv" \
  "$ROOT/install.sh" --links-only ghostty kitty herdr >/dev/null
grep -Fqx 'config-file = ~/.local/share/dotfiles/current/configs/ghostty/common.conf' \
  "$OMARCHY_HOME/.config/ghostty/config"
grep -Fqx 'include ~/.local/share/dotfiles/current/configs/kitty/kitty.conf' \
  "$OMARCHY_HOME/.config/kitty/kitty.conf"
cmp -s "$OMARCHY_HOME/.config/herdr/config.toml" "$ROOT/configs/herdr/config.toml"
[[ ! -L "$OMARCHY_HOME/.config/ghostty/config" && ! -L "$OMARCHY_HOME/.config/kitty/kitty.conf" && \
  ! -L "$OMARCHY_HOME/.config/herdr/config.toml" ]]
assert_link "$OMARCHY_HOME/.local/share/dotfiles/current" "$ROOT"
[[ "$(find "$OMARCHY_STATE/backups" -type f | wc -l)" -eq 3 ]]

PATH="$LINUX_BIN:$PATH" HOME="$OMARCHY_HOME" DOTFILES_STATE_FILE="$OMARCHY_STATE/links.tsv" \
  "$ROOT/install.sh" --links-only ghostty kitty herdr >/dev/null
[[ "$(find "$OMARCHY_STATE/backups" -type f | wc -l)" -eq 3 ]]

printf 'refreshed ghostty\n' > "$OMARCHY_HOME/.config/ghostty/config"
printf 'refreshed kitty\n' > "$OMARCHY_HOME/.config/kitty/kitty.conf"
printf 'refreshed herdr\n' > "$OMARCHY_HOME/.config/herdr/config.toml"
PATH="$LINUX_BIN:$PATH" HOME="$OMARCHY_HOME" DOTFILES_STATE_FILE="$OMARCHY_STATE/links.tsv" \
  "$ROOT/install.sh" --links-only ghostty kitty herdr >/dev/null
grep -Fqx 'config-file = ~/.local/share/dotfiles/current/configs/ghostty/common.conf' \
  "$OMARCHY_HOME/.config/ghostty/config"
grep -Fqx 'include ~/.local/share/dotfiles/current/configs/kitty/kitty.conf' \
  "$OMARCHY_HOME/.config/kitty/kitty.conf"
cmp -s "$OMARCHY_HOME/.config/herdr/config.toml" "$ROOT/configs/herdr/config.toml"
[[ "$(find "$OMARCHY_STATE/backups" -type f | wc -l)" -eq 6 ]]

DRY_HOME="$TEST_ROOT/dry-omarchy-home"
DRY_STATE="$TEST_ROOT/dry-omarchy-state"
mkdir -p "$DRY_HOME/.config/ghostty" "$DRY_HOME/.config/kitty" "$DRY_HOME/.config/herdr"
printf 'omarchy ghostty\n' > "$DRY_HOME/.config/ghostty/config"
printf 'omarchy kitty\n' > "$DRY_HOME/.config/kitty/kitty.conf"
printf 'omarchy herdr\n' > "$DRY_HOME/.config/herdr/config.toml"
PATH="$LINUX_BIN:$PATH" HOME="$DRY_HOME" DOTFILES_STATE_FILE="$DRY_STATE/links.tsv" \
  "$ROOT/install.sh" --links-only --dry-run ghostty kitty herdr > "$TEST_ROOT/dry-omarchy.out"
grep -Fqx 'omarchy ghostty' "$DRY_HOME/.config/ghostty/config"
grep -Fqx 'omarchy kitty' "$DRY_HOME/.config/kitty/kitty.conf"
grep -Fqx 'omarchy herdr' "$DRY_HOME/.config/herdr/config.toml"
[[ ! -e "$DRY_HOME/.local/share/dotfiles/current" && ! -e "$DRY_STATE" ]]
grep -Fq '+ backup ' "$TEST_ROOT/dry-omarchy.out"

# The previous Linux layout linked whole terminal directories. It can be
# migrated because those links point into this repository; unrelated directory
# links remain outside the installer's authority.
LEGACY_TERMINAL_HOME="$TEST_ROOT/legacy-terminal-home"
mkdir -p "$LEGACY_TERMINAL_HOME/.config"
ln -s "$ROOT/configs/ghostty" "$LEGACY_TERMINAL_HOME/.config/ghostty"
ln -s "$ROOT/configs/kitty" "$LEGACY_TERMINAL_HOME/.config/kitty"
PATH="$LINUX_BIN:$PATH" HOME="$LEGACY_TERMINAL_HOME" DOTFILES_STATE_FILE="$TEST_ROOT/legacy-terminal-state/links.tsv" \
  "$ROOT/install.sh" --links-only ghostty kitty >/dev/null
[[ -d "$LEGACY_TERMINAL_HOME/.config/ghostty" && ! -L "$LEGACY_TERMINAL_HOME/.config/ghostty" ]]
[[ -d "$LEGACY_TERMINAL_HOME/.config/kitty" && ! -L "$LEGACY_TERMINAL_HOME/.config/kitty" ]]
grep -Fqx 'config-file = ~/.local/share/dotfiles/current/configs/ghostty/common.conf' \
  "$LEGACY_TERMINAL_HOME/.config/ghostty/config"
grep -Fqx 'include ~/.local/share/dotfiles/current/configs/kitty/kitty.conf' \
  "$LEGACY_TERMINAL_HOME/.config/kitty/kitty.conf"

EXTERNAL_HOME="$TEST_ROOT/external-config-home"
EXTERNAL_GHOSTTY="$TEST_ROOT/external-ghostty"
mkdir -p "$EXTERNAL_HOME/.config" "$EXTERNAL_GHOSTTY"
printf 'external config\n' > "$EXTERNAL_GHOSTTY/config"
ln -s "$EXTERNAL_GHOSTTY" "$EXTERNAL_HOME/.config/ghostty"
PATH="$LINUX_BIN:$PATH" HOME="$EXTERNAL_HOME" DOTFILES_STATE_FILE="$TEST_ROOT/external-state/links.tsv" \
  "$ROOT/install.sh" --links-only ghostty >/dev/null
assert_link "$EXTERNAL_HOME/.config/ghostty" "$EXTERNAL_GHOSTTY"
grep -Fqx 'config-file = ~/.local/share/dotfiles/current/configs/ghostty/common.conf' \
  "$EXTERNAL_GHOSTTY/config"

# On Omarchy itself, exercise the exact three seeded files without copying the
# rest of /etc/skel or touching the real home directory.
if [[ -r /etc/os-release ]] && grep -Eq '^ID="?omarchy"?$' /etc/os-release && \
  [[ -f /etc/skel/.config/ghostty/config && -f /etc/skel/.config/kitty/kitty.conf && \
    -f /etc/skel/.config/herdr/config.toml ]]; then
  SKEL_HOME="$TEST_ROOT/skel-home"
  mkdir -p "$SKEL_HOME/.config/ghostty" "$SKEL_HOME/.config/kitty" "$SKEL_HOME/.config/herdr"
  cp -p /etc/skel/.config/ghostty/config "$SKEL_HOME/.config/ghostty/config"
  cp -p /etc/skel/.config/kitty/kitty.conf "$SKEL_HOME/.config/kitty/kitty.conf"
  cp -p /etc/skel/.config/herdr/config.toml "$SKEL_HOME/.config/herdr/config.toml"
  PATH="$LINUX_BIN:$PATH" HOME="$SKEL_HOME" DOTFILES_STATE_FILE="$TEST_ROOT/skel-state/links.tsv" \
    "$ROOT/install.sh" --links-only ghostty kitty herdr >/dev/null
  grep -Fqx 'config-file = ~/.local/share/dotfiles/current/configs/ghostty/common.conf' \
    "$SKEL_HOME/.config/ghostty/config"
  grep -Fqx 'include ~/.local/share/dotfiles/current/configs/kitty/kitty.conf' \
    "$SKEL_HOME/.config/kitty/kitty.conf"
  cmp -s "$SKEL_HOME/.config/herdr/config.toml" "$ROOT/configs/herdr/config.toml"
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
mkdir -p "$SYNTH_ROOT/scripts" "$SYNTH_ROOT/modules/demo/home/.config/demo" \
  "$SYNTH_ROOT/modules/managed" "$SYNTH_ROOT/modules/parked/home/.config/parked" "$SYNTH_HOME"
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
printf '%s\n' \
  '[module]' \
  'platforms = all' \
  'enabled = true' \
  'default = false' \
  '' \
  '[link config]' \
  'mode = copy' \
  'source = modules/managed/source.conf' \
  'target = ~/.config/managed/config' > "$SYNTH_ROOT/modules/managed/module.ini"
printf 'repository v1\n' > "$SYNTH_ROOT/modules/managed/source.conf"
printf '%s\n' \
  '[module]' \
  'platforms = all' \
  'enabled = true' > "$SYNTH_ROOT/modules/parked/module.ini"
printf 'kept\n' > "$SYNTH_ROOT/modules/parked/home/.config/parked/kept.conf"
printf '*.runtime\n' > "$SYNTH_ROOT/.gitignore"
printf 'private\n' > "$SYNTH_ROOT/modules/demo/home/.config/demo/cache.runtime"
chmod +x "$SYNTH_ROOT/install.sh" "$SYNTH_ROOT/scripts/install-deps.sh"
git -C "$SYNTH_ROOT" init -q

list_output="$(PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" "$SYNTH_ROOT/install.sh" list)"
assert_contains "$list_output" "demo"

# Disabling a module prevents all future application without cleaning its
# existing links or ownership state.
PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" \
  "$SYNTH_ROOT/install.sh" --links-only parked >/dev/null
assert_link "$SYNTH_HOME/.config/parked/kept.conf" "$SYNTH_ROOT/modules/parked/home/.config/parked/kept.conf"
printf '%s\n' \
  '[module]' \
  'platforms = all' \
  'enabled = false' > "$SYNTH_ROOT/modules/parked/module.ini"
printf 'not applied\n' > "$SYNTH_ROOT/modules/parked/home/.config/parked/later.conf"
PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" \
  "$SYNTH_ROOT/install.sh" --links-only >/dev/null
assert_link "$SYNTH_HOME/.config/parked/kept.conf" "$SYNTH_ROOT/modules/parked/home/.config/parked/kept.conf"
[[ ! -e "$SYNTH_HOME/.config/parked/later.conf" ]]
list_output="$(PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" "$SYNTH_ROOT/install.sh" list)"
printf '%s\n' "$list_output" | grep -Eq '^parked[[:space:]]+all[[:space:]]+false[[:space:]]+true[[:space:]]+disabled$'
if PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" "$SYNTH_ROOT/install.sh" --links-only parked >"$TEST_ROOT/disabled.out" 2>&1; then
  echo "Installer explicitly applied a disabled module." >&2
  exit 1
fi
grep -Fq 'Module parked is disabled in module.ini.' "$TEST_ROOT/disabled.out"
PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" \
  "$SYNTH_ROOT/install.sh" clean parked >/dev/null
[[ ! -e "$SYNTH_HOME/.config/parked/kept.conf" && ! -L "$SYNTH_HOME/.config/parked/kept.conf" ]]

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

# Managed copies restore runtime-only drift, but a simultaneous repository and
# runtime edit is a conflict and neither side is overwritten.
PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" \
  "$SYNTH_ROOT/install.sh" --links-only managed >/dev/null
cmp -s "$SYNTH_HOME/.config/managed/config" "$SYNTH_ROOT/modules/managed/source.conf"
printf 'runtime drift\n' > "$SYNTH_HOME/.config/managed/config"
PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" \
  "$SYNTH_ROOT/install.sh" --links-only managed >/dev/null
grep -Fqx 'repository v1' "$SYNTH_HOME/.config/managed/config"
printf 'repository v2\n' > "$SYNTH_ROOT/modules/managed/source.conf"
printf 'runtime v2\n' > "$SYNTH_HOME/.config/managed/config"
if PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" \
  "$SYNTH_ROOT/install.sh" --links-only managed >"$TEST_ROOT/managed-conflict.out" 2>&1; then
  echo "Managed copy silently resolved a two-sided conflict." >&2
  exit 1
fi
grep -Fq 'repository and runtime both changed' "$TEST_ROOT/managed-conflict.out"
grep -Fqx 'runtime v2' "$SYNTH_HOME/.config/managed/config"
PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" \
  "$SYNTH_ROOT/install.sh" clean managed >"$TEST_ROOT/managed-clean.out"
grep -Fq 'Skipped managed file changed outside dotfiles' "$TEST_ROOT/managed-clean.out"
grep -Fqx 'runtime v2' "$SYNTH_HOME/.config/managed/config"
printf 'repository v1\n' > "$SYNTH_HOME/.config/managed/config"
PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" DOTFILES_STATE_FILE="$SYNTH_STATE" \
  "$SYNTH_ROOT/install.sh" clean managed >/dev/null
[[ ! -e "$SYNTH_HOME/.config/managed/config" ]]

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

printf '%s\n' \
  '[module]' \
  '' \
  '[link broken]' \
  'mode = entry' \
  'source = modules/managed/source.conf' \
  'target = ~/.config/broken/config' > "$SYNTH_ROOT/modules/broken/module.ini"
if PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" "$SYNTH_ROOT/install.sh" list >"$TEST_ROOT/invalid.out" 2>&1; then
  echo "module.ini accepted an entry link without a template." >&2
  exit 1
fi
grep -Fq 'link broken is missing template' "$TEST_ROOT/invalid.out"

printf '%s\n' \
  '[module]' \
  '' \
  '[link broken]' \
  'mode = tree' \
  'source = modules/managed/source.conf' \
  'target = ~/../outside-home' > "$SYNTH_ROOT/modules/broken/module.ini"
if PATH="$LINUX_BIN:$PATH" HOME="$SYNTH_HOME" "$SYNTH_ROOT/install.sh" list >"$TEST_ROOT/invalid.out" 2>&1; then
  echo "module.ini accepted a target outside the home directory." >&2
  exit 1
fi
grep -Fq 'target must stay inside the home directory' "$TEST_ROOT/invalid.out"

# A real install completes one ordered module before starting the next. A later
# dependency failure therefore cannot suppress an earlier bootstrap module's
# links and post-install handoff.
LIFECYCLE_ROOT="$TEST_ROOT/lifecycle-repo"
LIFECYCLE_HOME="$TEST_ROOT/lifecycle-home"
mkdir -p "$LIFECYCLE_ROOT/scripts" \
  "$LIFECYCLE_ROOT/modules/bootstrap/home/.config/bootstrap" \
  "$LIFECYCLE_ROOT/modules/later/home/.config/later" "$LIFECYCLE_HOME"
cp "$ROOT/install.sh" "$LIFECYCLE_ROOT/install.sh"
cp "$ROOT/scripts/module-engine.sh" "$LIFECYCLE_ROOT/scripts/module-engine.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'grep -Fq "| later |" "$1" && exit 1' \
  'exit 0' > "$LIFECYCLE_ROOT/scripts/install-deps.sh"
printf '%s\n' \
  '[module]' \
  'order = 0' \
  '' \
  '[dependency bootstrap]' \
  'command = bootstrap' \
  'installer = script' \
  'source = install.sh' > "$LIFECYCLE_ROOT/modules/bootstrap/module.ini"
printf '#!/usr/bin/env bash\nexit 0\n' > "$LIFECYCLE_ROOT/modules/bootstrap/install.sh"
printf '#!/usr/bin/env bash\nprintf done > "$BOOTSTRAP_LOG"\n' > "$LIFECYCLE_ROOT/modules/bootstrap/post-install.sh"
printf 'bootstrap\n' > "$LIFECYCLE_ROOT/modules/bootstrap/home/.config/bootstrap/config"
printf '%s\n' \
  '[module]' \
  'order = 10' \
  '' \
  '[dependency later]' \
  'command = later' \
  'installer = script' \
  'source = install.sh' > "$LIFECYCLE_ROOT/modules/later/module.ini"
printf '#!/usr/bin/env bash\nexit 1\n' > "$LIFECYCLE_ROOT/modules/later/install.sh"
printf 'later\n' > "$LIFECYCLE_ROOT/modules/later/home/.config/later/config"
chmod +x "$LIFECYCLE_ROOT/install.sh" "$LIFECYCLE_ROOT/scripts/install-deps.sh"
git -C "$LIFECYCLE_ROOT" init -q
if PATH="$LINUX_BIN:$PATH" HOME="$LIFECYCLE_HOME" BOOTSTRAP_LOG="$TEST_ROOT/bootstrap.log" \
  DOTFILES_STATE_FILE="$TEST_ROOT/lifecycle-state/links.tsv" "$LIFECYCLE_ROOT/install.sh" \
  >"$TEST_ROOT/lifecycle.out" 2>&1; then
  echo "Lifecycle test did not surface the later dependency failure." >&2
  exit 1
fi
assert_link "$LIFECYCLE_HOME/.config/bootstrap/config" \
  "$LIFECYCLE_ROOT/modules/bootstrap/home/.config/bootstrap/config"
grep -Fqx done "$TEST_ROOT/bootstrap.log"
[[ ! -e "$LIFECYCLE_HOME/.config/later/config" ]]
