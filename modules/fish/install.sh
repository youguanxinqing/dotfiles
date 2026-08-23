#!/usr/bin/env bash

set -euo pipefail

FISH_MODULE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=modules/fish/platform.sh
source "$FISH_MODULE_DIR/platform.sh"

fish_install_state_file() {
  printf '%s\n' "${DOTFILES_FISH_INSTALL_STATE:-$HOME/.local/state/dotfiles/fish-installer}"
}

record_install_method() {
  local method="$1" state_file temp
  state_file="$(fish_install_state_file)"
  mkdir -p "$(dirname "$state_file")"
  temp="$state_file.tmp.$$"
  printf '%s\n' "$method" > "$temp"
  mv "$temp" "$state_file"
}

run_as_root() {
  if ((EUID == 0)); then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "sudo is required to install Fish through the system package manager." >&2
    return 1
  fi
}

check_fish() {
  fish_find_binary >/dev/null 2>&1 || return 1
  if fish_is_omarchy; then
    command -v omarchy-setup-fish >/dev/null 2>&1
  fi
}

install_fish() {
  [[ "$(uname -s)" == Linux ]] || {
    echo "The Fish script installer is only used on Linux." >&2
    return 1
  }

  if fish_is_omarchy; then
    command -v omarchy >/dev/null 2>&1 || {
      echo "Omarchy was detected, but its omarchy command is unavailable." >&2
      return 1
    }
    echo "Installing Fish through Omarchy's supported integration package."
    omarchy pkg add omarchy-fish
    record_install_method omarchy
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root apt-get install -y fish
    record_install_method apt
  elif command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y fish
    record_install_method dnf
  elif command -v pacman >/dev/null 2>&1; then
    run_as_root pacman -S --needed fish
    record_install_method pacman
  else
    echo "No supported Linux package manager was found for Fish (apt-get, dnf, or pacman)." >&2
    return 1
  fi
}

clean_fish() {
  local state_file method login_shell
  fish_remove_omarchy_handoff
  state_file="$(fish_install_state_file)"
  if [[ ! -f "$state_file" ]]; then
    echo "Kept Fish: this dotfiles installer did not record installing it."
    return 0
  fi

  login_shell="$(fish_login_shell)"
  if [[ "${login_shell##*/}" == fish ]]; then
    echo "Refusing to uninstall the active Fish login shell." >&2
    echo "Change the login shell to Bash, sign out, and run clean again." >&2
    return 1
  fi

  method="$(sed -n '1p' "$state_file")"
  case "$method" in
    omarchy)
      command -v omarchy >/dev/null 2>&1 || {
        echo "The recorded Omarchy package cannot be removed because omarchy is unavailable." >&2
        return 1
      }
      omarchy pkg drop omarchy-fish
      ;;
    apt) run_as_root apt-get remove -y fish ;;
    dnf) run_as_root dnf remove -y fish ;;
    pacman) run_as_root pacman -Rns fish ;;
    *)
      echo "Unknown recorded Fish installer: $method" >&2
      return 1
      ;;
  esac
  rm -f "$state_file"
}

case "${1:-}" in
  check) check_fish ;;
  install) install_fish ;;
  clean) clean_fish ;;
  *) echo "Usage: $0 check|install|clean" >&2; exit 2 ;;
esac
