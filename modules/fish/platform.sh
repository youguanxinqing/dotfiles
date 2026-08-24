#!/usr/bin/env bash

# Shared platform and runtime helpers for the Fish module. This file is sourced
# by install.sh and post-install.sh; keep it compatible with macOS Bash 3.2.

FISH_HANDOFF_BEGIN="# >>> dotfiles omarchy fish >>>"
FISH_HANDOFF_END="# <<< dotfiles omarchy fish <<<"

fish_is_omarchy() {
  local os_release omarchy_root

  [[ "$(uname -s)" == Linux ]] || return 1
  os_release="${DOTFILES_OS_RELEASE:-/etc/os-release}"
  if [[ -r "$os_release" ]] &&
    grep -Eq '^[[:space:]]*ID="?omarchy"?[[:space:]]*$' "$os_release"; then
    return 0
  fi

  omarchy_root="${DOTFILES_OMARCHY_ROOT:-/usr/share/omarchy}"
  command -v omarchy >/dev/null 2>&1 && [[ -d "$omarchy_root" ]]
}

fish_find_binary() {
  command -v fish 2>/dev/null || {
    local candidate
    for candidate in /usr/bin/fish /opt/homebrew/bin/fish /usr/local/bin/fish /home/linuxbrew/.linuxbrew/bin/fish; do
      [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
    done
    return 1
  }
}

fish_login_shell() {
  local current_user login_shell
  current_user="${USER:-$(id -un)}"
  login_shell=""
  if command -v getent >/dev/null 2>&1; then
    login_shell="$(getent passwd "$current_user" 2>/dev/null | awk -F: '{print $7}' || true)"
  fi
  [[ -n "$login_shell" ]] || login_shell="${SHELL:-}"
  printf '%s\n' "$login_shell"
}

fish_handoff_target() {
  printf '%s\n' "${DOTFILES_BASHRC:-$HOME/.bashrc}"
}

fish_validate_handoff_target() {
  local target="$1"
  if [[ -L "$target" ]]; then
    echo "Refusing to replace symlinked Bash configuration: $target" >&2
    return 1
  fi
  if [[ -e "$target" && ! -f "$target" ]]; then
    echo "Refusing to replace non-file Bash configuration: $target" >&2
    return 1
  fi
}

fish_validate_handoff_markers() {
  local target="$1" begin_count end_count
  [[ -f "$target" ]] || return 0

  begin_count="$(grep -Fxc "$FISH_HANDOFF_BEGIN" "$target" || true)"
  end_count="$(grep -Fxc "$FISH_HANDOFF_END" "$target" || true)"
  if [[ "$begin_count" == 0 && "$end_count" == 0 ]] ||
    [[ "$begin_count" == 1 && "$end_count" == 1 ]]; then
    return 0
  fi

  echo "Refusing to edit malformed Fish handoff markers in $target." >&2
  return 1
}

fish_strip_handoff() {
  local target="$1"
  awk -v begin="$FISH_HANDOFF_BEGIN" -v end="$FISH_HANDOFF_END" '
    $0 == begin {
      if (skipping || seen) exit 2
      skipping = 1
      seen = 1
      next
    }
    $0 == end {
      if (!skipping) exit 2
      skipping = 0
      separator = 1
      next
    }
    separator {
      separator = 0
      if ($0 == "") next
    }
    !skipping { print }
    END { if (skipping) exit 2 }
  ' "$target"
}

fish_copy_mode() {
  local source="$1" target="$2" mode
  if chmod --reference="$source" "$target" 2>/dev/null; then
    return 0
  fi
  mode="$(stat -f '%Lp' "$source")"
  chmod "$mode" "$target"
}

fish_print_handoff() {
  printf '%s\n' \
    "$FISH_HANDOFF_BEGIN" \
    '# Keep Omarchy session paths available before replacing interactive Bash.' \
    'if [[ -r /usr/share/omarchy/default/bash/env-bootstrap ]]; then' \
    '  source /usr/share/omarchy/default/bash/env-bootstrap' \
    'fi' \
    '' \
    '# Omarchy keeps Bash as the login shell; interactive top-level shells use Fish.' \
    'if [[ $- == *i* ]] && command -v fish >/dev/null 2>&1 &&' \
    '  [[ -z ${BASH_EXECUTION_STRING:-} && ${SHLVL:-1} == 1 ]] &&' \
    '  [[ $(ps --no-header --pid="$PPID" --format=comm 2>/dev/null) != fish ]]; then' \
    "  if shopt -q login_shell; then exec fish --login; else exec fish; fi" \
    'fi' \
    "$FISH_HANDOFF_END"
}

fish_backup_runtime_file() {
  local target="$1" backup_dir backup
  [[ -f "$target" ]] || return 0

  backup_dir="${DOTFILES_BACKUP_DIR:-$HOME/.local/state/dotfiles/backups}"
  mkdir -p "$backup_dir"
  backup="$backup_dir/bashrc.$(date +%Y%m%d-%H%M%S).$$"
  cp -p "$target" "$backup"
  echo "Backed up: $target -> $backup"
}

fish_install_omarchy_handoff() {
  local target stripped desired
  target="$(fish_handoff_target)"
  fish_validate_handoff_target "$target"
  fish_validate_handoff_markers "$target"

  stripped="$(mktemp)"
  desired="$(mktemp)"
  if [[ -f "$target" ]]; then
    fish_strip_handoff "$target" > "$stripped"
  else
    : > "$stripped"
  fi

  fish_print_handoff > "$desired"
  if [[ -s "$stripped" ]]; then
    printf '\n' >> "$desired"
    cat "$stripped" >> "$desired"
  fi

  if [[ -f "$target" ]] && cmp -s "$target" "$desired"; then
    rm -f "$stripped" "$desired"
    echo "Omarchy Fish handoff is already configured: $target"
    return 0
  fi

  fish_backup_runtime_file "$target"
  mkdir -p "$(dirname "$target")"
  if [[ -f "$target" ]]; then
    fish_copy_mode "$target" "$desired"
  else
    chmod 0644 "$desired"
  fi
  mv "$desired" "$target"
  rm -f "$stripped"
  echo "Configured Omarchy Fish handoff: $target"
}

fish_remove_omarchy_handoff() {
  local target stripped
  target="$(fish_handoff_target)"
  [[ -f "$target" ]] || return 0
  fish_validate_handoff_target "$target"
  fish_validate_handoff_markers "$target"
  grep -Fqx "$FISH_HANDOFF_BEGIN" "$target" || return 0

  stripped="$(mktemp)"
  fish_strip_handoff "$target" > "$stripped"
  fish_backup_runtime_file "$target"
  fish_copy_mode "$target" "$stripped"
  mv "$stripped" "$target"
  echo "Removed Omarchy Fish handoff: $target"
}
