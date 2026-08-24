#!/usr/bin/env bash

set -euo pipefail

FISH_MODULE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=modules/fish/platform.sh
source "$FISH_MODULE_DIR/platform.sh"

fish_bin="$(fish_find_binary || true)"
[[ -n "$fish_bin" ]] || { echo "Fish was not found after dependency installation." >&2; exit 1; }

if fish_is_omarchy; then
  login_shell="$(fish_login_shell)"
  if [[ "${login_shell##*/}" == fish ]]; then
    echo "Omarchy must keep Bash as the login shell before enabling its Fish handoff." >&2
    echo "Run 'chsh -s /usr/bin/bash', sign out, and run the installer again." >&2
    exit 1
  fi
  fish_install_omarchy_handoff
  echo "Omarchy detected: Bash remains the login shell and interactive terminals use Fish."
  exit 0
fi

login_shell="$(fish_login_shell)"
if [[ "$login_shell" == "$fish_bin" ]]; then
  echo "Fish is already the login shell: $fish_bin"
  exit 0
fi

if [[ ! -t 0 || ! -t 1 ]]; then
  echo "Fish is installed at $fish_bin. Run 'chsh -s $fish_bin' to make it the login shell."
  exit 0
fi

printf 'Set Fish as the default login shell? [y/N] '
IFS= read -r reply
[[ "$reply" == y || "$reply" == Y ]] || { echo "Kept the current login shell."; exit 0; }
command -v chsh >/dev/null 2>&1 || { echo "chsh is required to change the login shell." >&2; exit 1; }

if ! grep -Fqx "$fish_bin" /etc/shells; then
  if ((EUID == 0)); then
    printf '%s\n' "$fish_bin" | tee -a /etc/shells >/dev/null
  elif command -v sudo >/dev/null 2>&1; then
    printf '%s\n' "$fish_bin" | sudo tee -a /etc/shells >/dev/null
  else
    echo "sudo is required to add Fish to /etc/shells." >&2
    exit 1
  fi
fi
chsh -s "$fish_bin"
echo "Fish will be the login shell in new terminal sessions."
