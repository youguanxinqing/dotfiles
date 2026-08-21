#!/usr/bin/env bash

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
[[ -f "$ROOT/configs/kitty/theme.conf" ]] || { echo "Kitty theme must be a regular file." >&2; exit 1; }
[[ -x "$ROOT/bin/tmux-cleanup-scratch" && -x "$ROOT/bin/tmux-swap-scratch" && -x "$ROOT/bin/tmux-toggle-scratch" ]] || {
  echo "tmux helpers must be executable." >&2
  exit 1
}
TEST_HOME="$(mktemp -d)"
CONFLICT_HOME="$(mktemp -d)"
LEGACY_HOME="$(mktemp -d)"
FEATURE_ROOT="$(mktemp -d)"
FEATURE_HOME="$(mktemp -d)"
BREW_TEST_ROOT="$(mktemp -d)"
CLI_TEST_ROOT="$(mktemp -d)"
CLI_TEST_HOME="$(mktemp -d)"
BOOTSTRAP_ROOT="$(mktemp -d)"
BOOTSTRAP_HOME="$(mktemp -d)"
GOUP_TEST_ROOT="$(mktemp -d)"
GOUP_TEST_HOME="$(mktemp -d)"
FEATURE_ROOT="$(cd "$FEATURE_ROOT" && pwd -P)"
trap 'rm -rf "$TEST_HOME" "$CONFLICT_HOME" "$LEGACY_HOME" "$FEATURE_ROOT" "$FEATURE_HOME" "$BREW_TEST_ROOT" "$CLI_TEST_ROOT" "$CLI_TEST_HOME" "$BOOTSTRAP_ROOT" "$BOOTSTRAP_HOME" "$GOUP_TEST_ROOT" "$GOUP_TEST_HOME"' EXIT

bash -n "$ROOT/install.sh" "$ROOT/scripts/install-deps.sh" "$ROOT/scripts/installers/goup.sh" "$ROOT/scripts/check-private.sh" "$ROOT/features/herdr/install-plugins.sh"
# 再用 macOS 自带的 3.2 过一遍：上面那个 bash 来自 PATH，本机可能是 5.x，抓不到
# bash 4+ 的写法，而新机器上跑的就是 /bin/bash。
if [[ -x /bin/bash ]]; then
  /bin/bash -n "$ROOT/install.sh" "$ROOT/scripts/install-deps.sh" "$ROOT/scripts/installers/goup.sh" "$ROOT/scripts/check-private.sh" "$ROOT/features/herdr/install-plugins.sh"
fi
HOME="$TEST_HOME" "$ROOT/install.sh" --links-only fish herdr hammerspoon tmux bin
HOME="$TEST_HOME" "$ROOT/install.sh" --links-only fish herdr hammerspoon tmux bin

[[ "$(readlink "$TEST_HOME/.config/fish")" == "$ROOT/configs/fish" ]]
[[ "$(readlink "$TEST_HOME/.config/herdr/config.toml")" == "$ROOT/configs/herdr/config.toml" ]]
[[ "$(readlink "$TEST_HOME/.hammerspoon")" == "$ROOT/configs/hammerspoon" ]]
[[ "$(readlink "$TEST_HOME/.local/bin/herdr-smart-tab")" == "$ROOT/bin/herdr-smart-tab" ]]
[[ "$(readlink "$TEST_HOME/.tmux.conf")" == "$ROOT/configs/tmux/tmux.conf" ]]
[[ "$(readlink "$TEST_HOME/.local/bin/tmux-toggle-scratch")" == "$ROOT/bin/tmux-toggle-scratch" ]]

mkdir -p "$CONFLICT_HOME/.config/fish"
conflict_output="$(HOME="$CONFLICT_HOME" "$ROOT/install.sh" --links-only fish)"
[[ "$conflict_output" == *"Skipped unmanaged path: $CONFLICT_HOME/.config/fish"* ]]
[[ -d "$CONFLICT_HOME/.config/fish" && ! -L "$CONFLICT_HOME/.config/fish" ]]

# Repository-owned links survive source-directory reorganizations.
mkdir -p "$LEGACY_HOME/.config"
ln -s "$ROOT/fish" "$LEGACY_HOME/.config/fish"
HOME="$LEGACY_HOME" "$ROOT/install.sh" --links-only fish >/dev/null
[[ "$(readlink "$LEGACY_HOME/.config/fish")" == "$ROOT/configs/fish" ]]
mkdir -p "$LEGACY_HOME/.tmux"
ln -s "$ROOT/configs/tmux/bin" "$LEGACY_HOME/.tmux/bin"
HOME="$LEGACY_HOME" "$ROOT/install.sh" --links-only tmux >/dev/null
[[ ! -e "$LEGACY_HOME/.tmux/bin" && ! -L "$LEGACY_HOME/.tmux/bin" ]]

# Feature flags add and clean only links owned by that feature.
cp "$ROOT/install.sh" "$FEATURE_ROOT/install.sh"
mkdir -p "$FEATURE_ROOT/features/demo" "$FEATURE_ROOT/demo"
: > "$FEATURE_ROOT/navigation.txt"
printf 'demo=true\n' > "$FEATURE_ROOT/features.conf"
printf 'demo => ~/.config/demo\n' > "$FEATURE_ROOT/features/demo/navigation.txt"
HOME="$FEATURE_HOME" "$FEATURE_ROOT/install.sh" --links-only demo
[[ "$(readlink "$FEATURE_HOME/.config/demo")" == "$FEATURE_ROOT/demo" ]]
if HOME="$FEATURE_HOME" "$FEATURE_ROOT/install.sh" clean demo >/dev/null 2>&1; then
  echo "Installer cleaned an enabled feature" >&2
  exit 1
fi
printf '# demo=true\n' > "$FEATURE_ROOT/features.conf"
HOME="$FEATURE_HOME" "$FEATURE_ROOT/install.sh" clean demo
[[ ! -e "$FEATURE_HOME/.config/demo" && ! -L "$FEATURE_HOME/.config/demo" ]]

# A single install command reaches the Fish login-shell check without requiring a TTY.
mkdir -p "$FEATURE_ROOT/scripts" "$FEATURE_ROOT/bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$@" > "$DEPS_LOG"' > "$FEATURE_ROOT/scripts/install-deps.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FEATURE_ROOT/bin/fish"
chmod +x "$FEATURE_ROOT/scripts/install-deps.sh" "$FEATURE_ROOT/bin/fish"
printf 'demo=true\n' > "$FEATURE_ROOT/features.conf"
printf 'all | demo | demo | brew | demo\n' > "$FEATURE_ROOT/features/demo/cli.conf"
shell_output="$(PATH="$FEATURE_ROOT/bin:/usr/bin:/bin" HOME="$FEATURE_HOME" SHELL=/bin/sh DEPS_LOG="$FEATURE_ROOT/deps.log" \
  "$FEATURE_ROOT/install.sh" --deps-only)"
[[ "$shell_output" == *"Fish is installed at $FEATURE_ROOT/bin/fish"* ]]
grep -Fq "$FEATURE_ROOT/features/demo/cli.conf" "$FEATURE_ROOT/deps.log"

# CLI cleanup removes feature-only entries but keeps shared entries.
mkdir -p "$BREW_TEST_ROOT/bin" "$BREW_TEST_ROOT/home"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'if [[ "$1" == list && ("$2" == --formula || "$2" == --cask) ]]; then' \
  '  [[ "$3" != rustup && "$3" != hammerspoon ]]' \
  'elif [[ "$1" == uninstall ]]; then' \
  '  printf '\''%s\n'\'' "$*" >> "$BREW_LOG"' \
  'elif [[ "$1" == shellenv ]]; then' \
  '  exit 0' \
  'else' \
  '  exit 1' \
  'fi' > "$BREW_TEST_ROOT/bin/brew"
chmod +x "$BREW_TEST_ROOT/bin/brew"
printf '#!/usr/bin/env bash\nexit 0\n' > "$BREW_TEST_ROOT/bin/feature-only"
printf '#!/usr/bin/env bash\nexit 0\n' > "$BREW_TEST_ROOT/bin/feature-cask"
printf '#!/usr/bin/env bash\nexit 0\n' > "$BREW_TEST_ROOT/bin/shared"
printf '#!/usr/bin/env bash\nexit 0\n' > "$BREW_TEST_ROOT/bin/hs"
chmod +x "$BREW_TEST_ROOT/bin/feature-only" "$BREW_TEST_ROOT/bin/feature-cask" "$BREW_TEST_ROOT/bin/shared" "$BREW_TEST_ROOT/bin/hs"
printf 'all | feature-only | feature-only | brew | feature-only\nmacos | feature-cask | feature-cask | brew-cask | feature-cask\nall | shared | shared | brew | shared\n' > "$BREW_TEST_ROOT/feature-cli.conf"
printf 'all | shared | shared | brew | shared\n' > "$BREW_TEST_ROOT/keep-cli.conf"
: > "$BREW_TEST_ROOT/brew.log"
PATH="$BREW_TEST_ROOT/bin:/usr/bin:/bin" HOME="$BREW_TEST_ROOT/home" BREW_LOG="$BREW_TEST_ROOT/brew.log" \
  "$ROOT/scripts/install-deps.sh" --clean "$BREW_TEST_ROOT/feature-cli.conf" "$BREW_TEST_ROOT/keep-cli.conf"
grep -Fqx 'uninstall feature-only' "$BREW_TEST_ROOT/brew.log"
grep -Fqx 'uninstall --cask feature-cask' "$BREW_TEST_ROOT/brew.log"
if grep -Fq shared "$BREW_TEST_ROOT/brew.log"; then
  echo "CLI cleanup removed a shared package" >&2
  exit 1
fi

git config --file "$BREW_TEST_ROOT/gitconfig" core.pager custom-pager
dependency_output="$(PATH="$BREW_TEST_ROOT/bin:/usr/bin:/bin" GIT_CONFIG_GLOBAL="$BREW_TEST_ROOT/gitconfig" \
  "$ROOT/scripts/install-deps.sh" --dry-run)"
[[ "$dependency_output" == *"verify enabled CLI commands"* ]]
[[ "$dependency_output" != *"Installing CLI: hammerspoon"* ]]
[[ "$dependency_output" != *"core.pager"* ]]

# Homebrew bootstrap failure is aggregated without hiding later installer results.
mkdir -p "$BOOTSTRAP_ROOT/scripts/installers" "$BOOTSTRAP_ROOT/bin"
cp "$ROOT/scripts/install-deps.sh" "$BOOTSTRAP_ROOT/scripts/install-deps.sh"
sed -i.bak 's|for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do|for candidate in "$BOOTSTRAP_BREW"; do|' \
  "$BOOTSTRAP_ROOT/scripts/install-deps.sh"
grep -Fq 'for candidate in "$BOOTSTRAP_BREW"' "$BOOTSTRAP_ROOT/scripts/install-deps.sh"
printf '#!/usr/bin/env bash\necho Darwin\n' > "$BOOTSTRAP_ROOT/bin/uname"
printf '#!/usr/bin/env bash\nexit 1\n' > "$BOOTSTRAP_ROOT/bin/curl"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "$1" in' \
  '  check) test -x "$BOOTSTRAP_BIN/demo" ;;' \
  '  install) printf '\''#!/usr/bin/env bash\nexit 0\n'\'' > "$BOOTSTRAP_BIN/demo"; chmod +x "$BOOTSTRAP_BIN/demo" ;;' \
  '  clean) exit 0 ;;' \
  'esac' > "$BOOTSTRAP_ROOT/scripts/installers/demo.sh"
printf 'all | missing-brew | missing-brew | brew | missing-brew\nall | demo | demo | script | scripts/installers/demo.sh\n' > "$BOOTSTRAP_ROOT/cli.conf"
chmod +x "$BOOTSTRAP_ROOT/bin/uname" "$BOOTSTRAP_ROOT/bin/curl" "$BOOTSTRAP_ROOT/scripts/installers/demo.sh"
if PATH="$BOOTSTRAP_ROOT/bin:/usr/bin:/bin" HOME="$BOOTSTRAP_HOME" BOOTSTRAP_BIN="$BOOTSTRAP_ROOT/bin" \
  BOOTSTRAP_BREW="$BOOTSTRAP_ROOT/no-brew" \
  "$BOOTSTRAP_ROOT/scripts/install-deps.sh" >/dev/null 2>&1; then
  echo "Homebrew bootstrap failure was not reported" >&2
  exit 1
fi
[[ -x "$BOOTSTRAP_ROOT/bin/demo" ]]

# goup initializes its environment, installs Go, and cleans idempotently.
mkdir -p "$GOUP_TEST_ROOT/bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "$1" in' \
  '  init) mkdir -p "$HOME/.goup/current/bin"; : > "$HOME/.goup/env" ;;' \
  '  install) printf '\''#!/usr/bin/env bash\nexit 0\n'\'' > "$HOME/.goup/current/bin/go"; chmod +x "$HOME/.goup/current/bin/go" ;;' \
  'esac' > "$GOUP_TEST_ROOT/bin/goup"
printf '#!/usr/bin/env bash\nexit 0\n' > "$GOUP_TEST_ROOT/bin/cargo"
chmod +x "$GOUP_TEST_ROOT/bin/goup" "$GOUP_TEST_ROOT/bin/cargo"
PATH="$GOUP_TEST_ROOT/bin:$GOUP_TEST_HOME/.goup/current/bin:/usr/bin:/bin" HOME="$GOUP_TEST_HOME" \
  "$ROOT/scripts/installers/goup.sh" install
PATH="$GOUP_TEST_ROOT/bin:$GOUP_TEST_HOME/.goup/current/bin:/usr/bin:/bin" HOME="$GOUP_TEST_HOME" \
  "$ROOT/scripts/installers/goup.sh" check
PATH="$GOUP_TEST_ROOT/bin:/usr/bin:/bin" HOME="$GOUP_TEST_HOME" "$ROOT/scripts/installers/goup.sh" clean
PATH="$GOUP_TEST_ROOT/bin:/usr/bin:/bin" HOME="$GOUP_TEST_HOME" "$ROOT/scripts/installers/goup.sh" clean

# A custom installer gives arbitrary Git/download flows the same lifecycle.
mkdir -p "$CLI_TEST_ROOT/scripts/installers" "$CLI_TEST_ROOT/bin"
cp "$ROOT/scripts/install-deps.sh" "$CLI_TEST_ROOT/scripts/install-deps.sh"
printf '#!/usr/bin/env bash\n[[ "$1" == shellenv ]]\n' > "$CLI_TEST_ROOT/bin/brew"
printf '#!/usr/bin/env bash\necho Linux\n' > "$CLI_TEST_ROOT/bin/uname"
chmod +x "$CLI_TEST_ROOT/bin/brew" "$CLI_TEST_ROOT/bin/uname"
printf 'linux | fail | fail-cli | script | scripts/installers/fail.sh\nlinux | demo | demo-cli | script | scripts/installers/demo.sh\nmacos | mac-only | mac-only | script | scripts/installers/mac-only.sh\n' > "$CLI_TEST_ROOT/cli.conf"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "$1" in' \
  '  check | install) exit 1 ;;' \
  '  clean) exit 0 ;;' \
  'esac' > "$CLI_TEST_ROOT/scripts/installers/fail.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'case "$1" in' \
  '  check) command -v demo-cli >/dev/null 2>&1 ;;' \
  '  install) printf '\''#!/usr/bin/env bash\nexit 0\n'\'' > "$CLI_TEST_BIN/demo-cli"; chmod +x "$CLI_TEST_BIN/demo-cli" ;;' \
  '  clean) rm -f "$CLI_TEST_BIN/demo-cli" ;;' \
  'esac' > "$CLI_TEST_ROOT/scripts/installers/demo.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "$1" in' \
  '  check) test -e "$CLI_TEST_BIN/mac-only" ;;' \
  '  install) touch "$CLI_TEST_BIN/mac-only" ;;' \
  '  clean) rm -f "$CLI_TEST_BIN/mac-only" ;;' \
  'esac' > "$CLI_TEST_ROOT/scripts/installers/mac-only.sh"
export CLI_TEST_BIN="$CLI_TEST_ROOT/bin"
if PATH="$CLI_TEST_ROOT/bin:/usr/bin:/bin" HOME="$CLI_TEST_HOME" "$CLI_TEST_ROOT/scripts/install-deps.sh"; then
  echo "Dependency installation ignored a failed CLI" >&2
  exit 1
fi
[[ -x "$CLI_TEST_ROOT/bin/demo-cli" ]]
[[ ! -e "$CLI_TEST_ROOT/bin/mac-only" ]]
PATH="$CLI_TEST_ROOT/bin:/usr/bin:/bin" HOME="$CLI_TEST_HOME" "$CLI_TEST_ROOT/scripts/install-deps.sh" \
  --clean "$CLI_TEST_ROOT/cli.conf"
[[ ! -e "$CLI_TEST_ROOT/bin/demo-cli" ]]

echo "Install checks passed."
