#!/usr/bin/env bash

set -euo pipefail

# subl 只存在于 app bundle 里。Homebrew cask 会把它软链进 $HOMEBREW_PREFIX/bin，
# 但从官网下载、拖进 /Applications 的安装不会 —— 所以 `installer = brew-cask`
# 加 `command = subl` 的组合在手工装的机器上永远检查不过，装完再检查还是不过。
# 这里把两种安装方式收敛到同一个结果：~/.local/bin/subl 指向 app 里的 subl，
# check 落在这条链上，跟 Sublime 是谁装的无关。
LINK_DIR="$HOME/.local/bin"
LINK="$LINK_DIR/subl"
APP_RELATIVE="Sublime Text.app/Contents/SharedSupport/bin/subl"

# 只看标准安装位置。mdfind 能找到任意目录里的 app，但那也会找到 Trash 里和
# 挂载的 dmg 里的副本。
app_bin() {
  local dir
  for dir in "$HOME/Applications" /Applications; do
    if [[ -x "$dir/$APP_RELATIVE" ]]; then
      printf '%s\n' "$dir/$APP_RELATIVE"
      return 0
    fi
  done
  return 1
}

find_brew() {
  local candidate
  for candidate in "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/brew" /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  command -v brew 2>/dev/null
}

case "${1:-}" in
  check)
    target="$(app_bin)" || exit 1
    [[ -L "$LINK" && "$(readlink "$LINK")" == "$target" ]] || exit 1
    ;;
  install)
    if ! target="$(app_bin)"; then
      brew="$(find_brew || true)"
      [[ -n "$brew" ]] || { echo "Homebrew is required to install Sublime Text." >&2; exit 1; }
      "$brew" install --cask sublime-text
      target="$(app_bin)" || { echo "subl was not found after installing Sublime Text." >&2; exit 1; }
    fi
    if [[ -e "$LINK" || -L "$LINK" ]]; then
      if [[ ! -L "$LINK" || "$(readlink "$LINK")" != "$target" ]]; then
        echo "Refusing to replace unmanaged path: $LINK" >&2
        exit 1
      fi
      echo "subl is already linked: $LINK"
      exit 0
    fi
    mkdir -p "$LINK_DIR"
    ln -sfn "$target" "$LINK"
    echo "Linked subl: $LINK -> $target"
    ;;
  clean)
    # 只收回这条链。删掉编辑器本身不是清理，是破坏 —— cask 卸载留给人自己决定。
    target="$(app_bin || true)"
    if [[ -n "$target" && -L "$LINK" && "$(readlink "$LINK")" == "$target" ]]; then
      rm "$LINK"
      echo "Removed link: $LINK"
    else
      echo "Already clean: $LINK"
    fi
    ;;
  *)
    echo "Usage: $0 check|install|clean" >&2
    exit 2
    ;;
esac
