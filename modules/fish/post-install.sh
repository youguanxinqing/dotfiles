#!/usr/bin/env bash

set -euo pipefail

find_fish() {
  command -v fish 2>/dev/null || {
    local candidate
    for candidate in /usr/bin/fish /opt/homebrew/bin/fish /usr/local/bin/fish /home/linuxbrew/.linuxbrew/bin/fish; do
      [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
    done
    return 1
  }
}

fish_bin="$(find_fish || true)"
[[ -n "$fish_bin" ]] || { echo "Fish was not found after dependency installation." >&2; exit 1; }

login_shell=""
current_user="${USER:-$(id -un)}"
if command -v getent >/dev/null 2>&1; then
  login_shell="$(getent passwd "$current_user" 2>/dev/null | awk -F: '{print $7}' || true)"
fi
[[ -n "$login_shell" ]] || login_shell="${SHELL:-}"
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
