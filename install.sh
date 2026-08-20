#!/usr/bin/env bash

set -eo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
MODE=all
ACTION=install
DRY_RUN=0
CONFIGS=()
FEATURE_NAMES=()
FEATURE_VALUES=()
ENABLED_FEATURES=()
FEATURE_CLI_MANIFESTS=()
MANIFESTS=("$ROOT/navigation.txt")

usage() {
  cat <<'EOF'
Usage: ./install.sh [--deps-only | --links-only] [--dry-run] [config ...]
       ./install.sh clean [--dry-run] <feature>

With no options, install dependencies and link core plus enabled features.
Pass config names to limit links, for example: ./install.sh --links-only fish tmux
Set a feature to false or comment it out before cleaning it.
Full and dependency-only installs verify dependencies and offer to configure Fish.
EOF
}

[[ "${1:-}" == clean ]] && { ACTION=clean; shift; }

while (($#)); do
  case "$1" in
    --deps-only) MODE=deps ;;
    --links-only) MODE=links ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) CONFIGS+=("$1") ;;
  esac
  shift
done

load_features() {
  local line name value existing
  [[ -f "$ROOT/features.conf" ]] || { echo "Missing feature config: $ROOT/features.conf" >&2; exit 1; }

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^([a-z0-9][a-z0-9_-]*)[[:space:]]*=[[:space:]]*(true|false)$ ]] || {
      echo "Invalid feature entry: $line" >&2
      exit 1
    }
    name="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    for existing in "${FEATURE_NAMES[@]}"; do
      [[ "$existing" != "$name" ]] || { echo "Duplicate feature: $name" >&2; exit 1; }
    done
    FEATURE_NAMES+=("$name")
    FEATURE_VALUES+=("$value")
    if [[ "$value" == true ]]; then
      ENABLED_FEATURES+=("$name")
    fi
  done < "$ROOT/features.conf"
}

feature_value() {
  local wanted="$1" index
  for index in "${!FEATURE_NAMES[@]}"; do
    [[ "${FEATURE_NAMES[$index]}" == "$wanted" ]] && { echo "${FEATURE_VALUES[$index]}"; return; }
  done
  return 1
}

load_feature_manifests() {
  local name dir found
  for name in "${ENABLED_FEATURES[@]}"; do
    dir="$ROOT/features/$name"
    [[ -d "$dir" ]] || { echo "Missing feature directory: $dir" >&2; exit 1; }
    found=0
    if [[ -f "$dir/cli.conf" ]]; then
      FEATURE_CLI_MANIFESTS+=("$dir/cli.conf")
      found=1
    fi
    if [[ -f "$dir/navigation.txt" ]]; then
      MANIFESTS+=("$dir/navigation.txt")
      found=1
    fi
    ((found)) || { echo "Feature has no cli.conf or navigation.txt: $name" >&2; exit 1; }
  done
}

validate_entry() {
  local source="$1" arrow="$2" target="$3"
  [[ "$arrow" == "=>" && "$target" == "~/"* ]] || {
    echo "Invalid navigation entry: $source $arrow $target" >&2
    exit 1
  }
}

is_requested() {
  local source="$1" name requested
  name="${source#configs/}"
  name="${name%%/*}"
  ((${#CONFIGS[@]} == 0)) && return 0
  for requested in "${CONFIGS[@]}"; do
    [[ "$requested" == "$source" || "$requested" == "$name" ]] && return 0
  done
  return 1
}

link_manifest() {
  local manifest="$1" source arrow target current
  while read -r source arrow target; do
    [[ -z "$source" || "$source" == \#* ]] && continue
    validate_entry "$source" "$arrow" "$target"
    is_requested "$source" || continue

    source="$ROOT/$source"
    target="$HOME/${target#\~/}"
    [[ -e "$source" ]] || { echo "Missing source: $source" >&2; exit 1; }

    if [[ -L "$target" ]]; then
      current="$(readlink "$target")"
      if [[ "$current" == "$source" ]]; then
        echo "Already linked: $target"
        continue
      fi
      if [[ "$current" == "$ROOT/"* ]]; then
        if ((DRY_RUN)); then
          printf '+ ln -sfn %q %q\n' "$source" "$target"
        else
          ln -sfn "$source" "$target"
          echo "Relinked: $target"
        fi
        continue
      fi
    fi
    if [[ -e "$target" || -L "$target" ]]; then
      echo "Skipped unmanaged path: $target"
      continue
    fi

    if ((DRY_RUN)); then
      printf '+ mkdir -p %q\n' "$(dirname "$target")"
      printf '+ ln -s %q %q\n' "$source" "$target"
    else
      mkdir -p "$(dirname "$target")"
      ln -s "$source" "$target"
      echo "Linked: $target"
    fi
  done < "$manifest"
}

clean_links() {
  local manifest="$1" source arrow target
  [[ -f "$manifest" ]] || return 0
  while read -r source arrow target; do
    [[ -z "$source" || "$source" == \#* ]] && continue
    validate_entry "$source" "$arrow" "$target"
    source="$ROOT/$source"
    target="$HOME/${target#\~/}"

    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
      if ((DRY_RUN)); then
        printf '+ rm %q\n' "$target"
      else
        rm "$target"
        echo "Removed link: $target"
      fi
    elif [[ -e "$target" || -L "$target" ]]; then
      echo "Skipped unmanaged path: $target"
    else
      echo "Already clean: $target"
    fi
  done < "$manifest"
}

find_fish() {
  command -v fish 2>/dev/null || {
    local candidate
    for candidate in /opt/homebrew/bin/fish /usr/local/bin/fish /home/linuxbrew/.linuxbrew/bin/fish; do
      [[ -x "$candidate" ]] && { echo "$candidate"; return; }
    done
    return 1
  }
}

configure_fish_shell() {
  local fish_bin reply
  if ((DRY_RUN)); then
    echo "+ verify Fish and prompt to make it the login shell when needed"
    return
  fi

  fish_bin="$(find_fish || true)"
  [[ -n "$fish_bin" ]] || { echo "Fish was not found after dependency installation." >&2; exit 1; }
  if [[ "${SHELL:-}" == "$fish_bin" ]]; then
    echo "Fish is already the login shell: $fish_bin"
    return
  fi
  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "Fish is installed at $fish_bin. Run 'chsh -s $fish_bin' to make it the login shell."
    return
  fi

  printf 'Set Fish as the default login shell? [y/N] '
  IFS= read -r reply
  [[ "$reply" == y || "$reply" == Y ]] || { echo "Kept the current login shell."; return; }
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
}

load_features
load_feature_manifests

if [[ "$ACTION" == clean ]]; then
  [[ "$MODE" == all && ${#CONFIGS[@]} -eq 1 ]] || { usage >&2; exit 2; }
  feature="${CONFIGS[0]}"
  value="$(feature_value "$feature" || true)"
  feature_dir="$ROOT/features/$feature"
  [[ -d "$feature_dir" ]] || { echo "Unknown feature: $feature" >&2; exit 2; }
  [[ "$value" != true ]] || { echo "Disable $feature in features.conf before cleaning it." >&2; exit 1; }

  if [[ -f "$feature_dir/cli.conf" ]]; then
    keep_cli_manifests=("$ROOT/cli.conf")
    for enabled_feature in "${ENABLED_FEATURES[@]}"; do
      cli_manifest="$ROOT/features/$enabled_feature/cli.conf"
      [[ -f "$cli_manifest" ]] && keep_cli_manifests+=("$cli_manifest")
    done
    args=(--clean)
    ((DRY_RUN)) && args+=(--dry-run)
    "$ROOT/scripts/install-deps.sh" "${args[@]}" "$feature_dir/cli.conf" "${keep_cli_manifests[@]}"
  fi
  clean_links "$feature_dir/navigation.txt"
  exit 0
fi

if [[ "$MODE" == deps && ${#CONFIGS[@]} -gt 0 ]]; then
  echo "Config names require --links-only" >&2
  exit 2
fi

if [[ "$MODE" != links ]]; then
  args=()
  ((DRY_RUN)) && args+=(--dry-run)
  "$ROOT/scripts/install-deps.sh" "${args[@]}" "${FEATURE_CLI_MANIFESTS[@]}"
fi

if [[ "$MODE" == deps ]]; then
  configure_fish_shell
  exit 0
fi

for requested in "${CONFIGS[@]}"; do
  found=0
  for manifest in "${MANIFESTS[@]}"; do
    if awk -v wanted="$requested" '$2 == "=>" { source = $1; sub(/^configs\//, "", source); split(source, part, "/"); if ($1 == wanted || source == wanted || part[1] == wanted) found = 1 } END { exit !found }' "$manifest"; then
      found=1
      break
    fi
  done
  ((found)) || { echo "Unknown config: $requested" >&2; exit 2; }
done

# Retire the old application-private helper link after moving tmux commands to ~/.local/bin.
retired_tmux_bin="$HOME/.tmux/bin"
if is_requested configs/tmux/tmux.conf && [[ -L "$retired_tmux_bin" ]] &&
  [[ "$(readlink "$retired_tmux_bin")" == "$ROOT/configs/tmux/bin" ]]; then
  if ((DRY_RUN)); then
    printf '+ rm %q\n' "$retired_tmux_bin"
  else
    rm "$retired_tmux_bin"
    echo "Removed retired link: $retired_tmux_bin"
  fi
fi

for manifest in "${MANIFESTS[@]}"; do
  link_manifest "$manifest"
done

if [[ "$MODE" == all ]]; then
  configure_fish_shell
fi
