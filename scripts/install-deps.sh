#!/usr/bin/env bash

set -eo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
ACTION=install
DRY_RUN=0
CLI_MANIFESTS=()
FAILED_CLIS=()
HOMEBREW_INSTALL_COMMIT=cced90146ea6d3057c03a636b668fef177415eb3
export PATH="$HOME/.cargo/bin:$HOME/.goup/current/bin:$HOME/go/bin:$PATH"

[[ "${1:-}" == --clean ]] && { ACTION=clean; shift; }
while (($#)); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --*)
      echo "Usage: $0 [--dry-run] [cli.conf ...] | --clean [--dry-run] <cli.conf> [keep-cli.conf ...]" >&2
      exit 2
      ;;
    *) CLI_MANIFESTS+=("$1") ;;
  esac
  shift
done

run() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  ((DRY_RUN)) || "$@"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

parse_cli_line() {
  local manifest="$1" line_number="$2" line="$3" extra

  line="${line%%#*}"
  line="$(trim "$line")"
  [[ -n "$line" ]] || return 1

  IFS='|' read -r CLI_PLATFORM CLI_ID CLI_COMMAND CLI_INSTALLER CLI_SOURCE extra <<< "$line"
  CLI_PLATFORM="$(trim "$CLI_PLATFORM")"
  CLI_ID="$(trim "$CLI_ID")"
  CLI_COMMAND="$(trim "$CLI_COMMAND")"
  CLI_INSTALLER="$(trim "$CLI_INSTALLER")"
  CLI_SOURCE="$(trim "$CLI_SOURCE")"
  extra="$(trim "${extra:-}")"

  [[ -z "$extra" ]] || { echo "$manifest:$line_number: too many fields" >&2; exit 1; }
  case "$CLI_PLATFORM" in all|macos|linux) ;; *) echo "$manifest:$line_number: invalid platform: $CLI_PLATFORM" >&2; exit 1 ;; esac
  [[ "$CLI_ID" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || { echo "$manifest:$line_number: invalid CLI id: $CLI_ID" >&2; exit 1; }
  [[ "$CLI_COMMAND" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || { echo "$manifest:$line_number: invalid command: $CLI_COMMAND" >&2; exit 1; }
  case "$CLI_INSTALLER" in brew|brew-cask|cargo|fnm|go|npm|rustup|script) ;; *) echo "$manifest:$line_number: invalid installer: $CLI_INSTALLER" >&2; exit 1 ;; esac
  [[ -n "$CLI_SOURCE" ]] || { echo "$manifest:$line_number: missing source" >&2; exit 1; }
  [[ "$CLI_INSTALLER" != brew-cask || "$CLI_PLATFORM" == macos ]] || {
    echo "$manifest:$line_number: brew-cask requires the macos platform" >&2
    exit 1
  }

  if [[ "$CLI_INSTALLER" == script ]]; then
    [[ "$CLI_SOURCE" != /* && "$CLI_SOURCE" != ../* && "$CLI_SOURCE" != */../* && "$CLI_SOURCE" != */.. ]] || {
      echo "$manifest:$line_number: script source must stay inside the repository" >&2
      exit 1
    }
    [[ -f "$ROOT/$CLI_SOURCE" ]] || { echo "$manifest:$line_number: missing script: $CLI_SOURCE" >&2; exit 1; }
  elif [[ ! "$CLI_SOURCE" =~ ^[A-Za-z0-9@._+/:=-]+$ ]]; then
    echo "$manifest:$line_number: invalid source: $CLI_SOURCE" >&2
    exit 1
  fi
}

platform_matches() {
  [[ "$CLI_PLATFORM" == all || "$CLI_PLATFORM" == "$OS" ]]
}

find_brew() {
  command -v brew 2>/dev/null || {
    local candidate
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
      [[ -x "$candidate" ]] && { echo "$candidate"; return; }
    done
    return 1
  }
}

refresh_environment() {
  ((DRY_RUN)) && return
  if [[ -n "${BREW:-}" ]]; then
    eval "$("$BREW" shellenv bash)"
    if "$BREW" list --formula rustup >/dev/null 2>&1; then
      export PATH="$("$BREW" --prefix rustup)/bin:$PATH"
    fi
  fi
  if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --shell bash)"
  fi
}

run_as_root() {
  if ((EUID == 0)); then
    run "$@"
  elif command -v sudo >/dev/null 2>&1; then
    run sudo "$@"
  elif ((DRY_RUN)); then
    run sudo "$@"
  else
    echo "sudo is required to install Homebrew prerequisites." >&2
    return 1
  fi
}

install_linux_prerequisites() {
  if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update &&
      run_as_root apt-get install -y build-essential procps curl file git
  elif command -v dnf >/dev/null 2>&1; then
    run_as_root dnf group install -y development-tools &&
      run_as_root dnf install -y procps-ng curl file git
  elif command -v pacman >/dev/null 2>&1; then
    run_as_root pacman -S --needed base-devel procps-ng curl file git
  else
    echo "Install a compiler, procps, curl, file, and git before Homebrew." >&2
    return 1
  fi
}

needs_brew() {
  local manifest line line_number
  for manifest in "$@"; do
    [[ -f "$manifest" ]] || { echo "Missing CLI manifest: $manifest" >&2; exit 1; }
    line_number=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      ((line_number += 1))
      if parse_cli_line "$manifest" "$line_number" "$line" && platform_matches \
        && [[ "$CLI_INSTALLER" == brew || "$CLI_INSTALLER" == brew-cask ]] \
        && ! command -v "$CLI_COMMAND" >/dev/null 2>&1; then
        return 0
      fi
    done < "$manifest"
  done
  return 1
}

install_homebrew() {
  local installer status

  [[ "$OS" != linux ]] || install_linux_prerequisites || return
  if ((DRY_RUN)); then
    echo "+ download and run the Homebrew installer from https://brew.sh"
    BREW=brew
    return
  fi
  command -v curl >/dev/null 2>&1 || { echo "curl is required to install Homebrew." >&2; return 1; }

  installer="$(mktemp)"
  curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/$HOMEBREW_INSTALL_COMMIT/install.sh" -o "$installer" || {
    status=$?
    rm -f "$installer"
    return "$status"
  }
  env NONINTERACTIVE=1 /bin/bash "$installer" || {
    status=$?
    rm -f "$installer"
    return "$status"
  }
  rm -f "$installer"
  BREW="$(find_brew || true)"
  [[ -n "$BREW" ]] || { echo "Homebrew was not found after installation." >&2; return 1; }
}

cli_is_installed() {
  local command="${1:-$CLI_COMMAND}" installer="${2:-$CLI_INSTALLER}" source="${3:-$CLI_SOURCE}"
  case "$installer" in
    script) bash "$ROOT/$source" check >/dev/null 2>&1 ;;
    brew-cask) command -v "$command" >/dev/null 2>&1 || { [[ -n "${BREW:-}" ]] && "$BREW" list --cask "$source" >/dev/null 2>&1; } ;;
    rustup) command -v "$command" >/dev/null 2>&1 && rustup show active-toolchain >/dev/null 2>&1 ;;
    *) command -v "$command" >/dev/null 2>&1 ;;
  esac
}

cli_is_managed() {
  local command="$1" installer="$2" source="$3"
  case "$installer" in
    brew) [[ -n "${BREW:-}" ]] && "$BREW" list --formula "$source" >/dev/null 2>&1 ;;
    brew-cask) [[ -n "${BREW:-}" ]] && "$BREW" list --cask "$source" >/dev/null 2>&1 ;;
    cargo) command -v cargo >/dev/null 2>&1 && cargo install --list | grep -Fq "$source v" ;;
    npm) command -v npm >/dev/null 2>&1 && npm list --global --depth=0 "$source" >/dev/null 2>&1 ;;
    script) return 0 ;;
    *) command -v "$command" >/dev/null 2>&1 ;;
  esac
}

install_cli() {
  if cli_is_installed; then
    echo "Already installed: $CLI_ID"
    return
  fi

  echo "Installing CLI: $CLI_ID ($CLI_INSTALLER)"
  case "$CLI_INSTALLER" in
    brew)
      [[ -n "${BREW:-}" ]] || { echo "Homebrew is required to install $CLI_ID." >&2; return 1; }
      run "$BREW" install "$CLI_SOURCE"
      ;;
    brew-cask)
      [[ -n "${BREW:-}" ]] || { echo "Homebrew is required to install $CLI_ID." >&2; return 1; }
      run "$BREW" install --cask "$CLI_SOURCE"
      ;;
    cargo)
      command -v cargo >/dev/null 2>&1 || { echo "cargo is required to install $CLI_ID." >&2; return 1; }
      run cargo install "$CLI_SOURCE"
      ;;
    fnm)
      command -v fnm >/dev/null 2>&1 || { echo "fnm is required to install $CLI_ID." >&2; return 1; }
      if [[ "$CLI_SOURCE" == lts ]]; then run fnm install --lts; else run fnm install "$CLI_SOURCE"; fi
      ;;
    go)
      command -v go >/dev/null 2>&1 || { echo "Go is required to install $CLI_ID; install it with goup first." >&2; return 1; }
      run go install "$CLI_SOURCE"
      ;;
    npm)
      command -v npm >/dev/null 2>&1 || { echo "npm is required to install $CLI_ID." >&2; return 1; }
      run npm install --global "$CLI_SOURCE"
      ;;
    rustup)
      command -v rustup >/dev/null 2>&1 || { echo "rustup is required to install $CLI_ID." >&2; return 1; }
      run rustup default "$CLI_SOURCE"
      ;;
    script)
      run bash "$ROOT/$CLI_SOURCE" install
      ;;
  esac || return

  ((DRY_RUN)) && return
  refresh_environment || return
  cli_is_installed || {
    echo "CLI check failed after installation: $CLI_ID ($CLI_COMMAND)" >&2
    return 1
  }
}

install_manifest() {
  local manifest="$1" line line_number=0
  [[ -f "$manifest" ]] || { echo "Missing CLI manifest: $manifest" >&2; exit 1; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_number += 1))
    parse_cli_line "$manifest" "$line_number" "$line" || continue
    platform_matches || continue
    install_cli || FAILED_CLIS+=("$CLI_ID")
  done < "$manifest"
}

verify_manifest() {
  local manifest="$1" line line_number=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_number += 1))
    parse_cli_line "$manifest" "$line_number" "$line" || continue
    platform_matches || continue
    cli_is_installed || {
      echo "CLI check failed: $CLI_ID ($CLI_COMMAND)" >&2
      exit 1
    }
  done < "$manifest"
}

is_kept() {
  local wanted_id="$1" wanted_installer="$2" wanted_source="$3" manifest line line_number
  for manifest in "${KEEP_MANIFESTS[@]}"; do
    line_number=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      ((line_number += 1))
      parse_cli_line "$manifest" "$line_number" "$line" || continue
      platform_matches || continue
      [[ "$CLI_ID" == "$wanted_id" || ("$CLI_INSTALLER" == "$wanted_installer" && "$CLI_SOURCE" == "$wanted_source") ]] && return 0
    done < "$manifest"
  done
  return 1
}

clean_cli() {
  local id="$CLI_ID" command="$CLI_COMMAND" installer="$CLI_INSTALLER" source="$CLI_SOURCE"

  if is_kept "$id" "$installer" "$source"; then
    echo "Kept shared CLI: $id"
    return
  fi
  if ! cli_is_managed "$command" "$installer" "$source"; then
    echo "Already clean: $id"
    return
  fi

  case "$installer" in
    brew)
      [[ -n "${BREW:-}" ]] || { echo "Homebrew is required to clean $id." >&2; exit 1; }
      run "$BREW" uninstall "$source"
      ;;
    brew-cask)
      [[ -n "${BREW:-}" ]] || { echo "Homebrew is required to clean $id." >&2; exit 1; }
      run "$BREW" uninstall --cask "$source"
      ;;
    cargo) run cargo uninstall "$source" ;;
    npm) run npm uninstall --global "$source" ;;
    script) run bash "$ROOT/$source" clean ;;
    *)
      echo "Automatic cleanup is not supported for the $installer installer; use a script installer for $id." >&2
      exit 1
      ;;
  esac
}

clean_manifest() {
  local manifest="$1" line line_number=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_number += 1))
    parse_cli_line "$manifest" "$line_number" "$line" || continue
    platform_matches || continue
    clean_cli
  done < "$manifest"
}

case "$(uname -s)" in
  Darwin) OS=macos ;;
  Linux) OS=linux ;;
  *) echo "Only macOS and Linux are supported." >&2; exit 1 ;;
esac

if [[ "$ACTION" == clean ]]; then
  ((${#CLI_MANIFESTS[@]} >= 1)) || { echo "A feature CLI manifest is required." >&2; exit 2; }
  TARGET_MANIFEST="${CLI_MANIFESTS[0]}"
  KEEP_MANIFESTS=("${CLI_MANIFESTS[@]:1}")
  [[ -f "$TARGET_MANIFEST" ]] || { echo "Missing CLI manifest: $TARGET_MANIFEST" >&2; exit 1; }
  for manifest in "${KEEP_MANIFESTS[@]}"; do
    [[ -f "$manifest" ]] || { echo "Missing CLI manifest: $manifest" >&2; exit 1; }
  done
  BREW="$(find_brew || true)"
  refresh_environment
  clean_manifest "$TARGET_MANIFEST"
  exit 0
fi

CLI_MANIFESTS=("$ROOT/cli.conf" "${CLI_MANIFESTS[@]}")
if needs_brew "${CLI_MANIFESTS[@]}"; then
  BREW="$(find_brew || true)"
  if [[ -z "$BREW" ]] && ! install_homebrew; then
    echo "Homebrew installation failed; continuing to check all CLIs." >&2
  fi
else
  BREW="$(find_brew || true)"
fi
refresh_environment

for manifest in "${CLI_MANIFESTS[@]}"; do
  install_manifest "$manifest"
done

if ((${#FAILED_CLIS[@]})); then
  printf 'CLI installation failed: %s\n' "${FAILED_CLIS[*]}" >&2
  exit 1
fi

if ((DRY_RUN)); then
  echo "+ verify enabled CLI commands"
else
  refresh_environment
  for manifest in "${CLI_MANIFESTS[@]}"; do
    verify_manifest "$manifest"
  done
  echo "CLI check passed."
fi

run git config --global core.pager delta
run git config --global interactive.diffFilter "delta --color-only"
run git config --global delta.navigate true
run git config --global merge.conflictStyle zdiff3
