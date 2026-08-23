#!/usr/bin/env bash

# Module discovery and link lifecycle for install.sh. Keep this file compatible
# with macOS Bash 3.2; module.ini is a strict INI-like data format, never sourced.

MODULE_NAMES=()
MODULE_DIRS=()
MODULE_PLATFORMS=()
MODULE_DEFAULTS=()
MODULE_ORDERS=()
SELECTED_MODULE_NAMES=()
SELECTED_MODULE_DIRS=()
PLATFORM=""
STATE_FILE="${DOTFILES_STATE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/links.tsv}"

PARSED_MODULE_PLATFORMS=""
PARSED_MODULE_DEFAULT=""
PARSED_MODULE_ORDER=""
PARSED_DEP_IDS=()
PARSED_DEP_PLATFORMS=()
PARSED_DEP_COMMANDS=()
PARSED_DEP_INSTALLERS=()
PARSED_DEP_SOURCES=()
PARSED_DEP_SEEN=()
PARSED_LINK_IDS=()
PARSED_LINK_PLATFORMS=()
PARSED_LINK_MODES=()
PARSED_LINK_SOURCES=()
PARSED_LINK_TARGETS=()
PARSED_LINK_SEEN=()

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

detect_platform() {
  case "$(uname -s)" in
    Darwin) PLATFORM=macos ;;
    Linux) PLATFORM=linux ;;
    *) echo "Only macOS and Linux are supported." >&2; exit 1 ;;
  esac
}

platform_matches() {
  local platforms=",${1// /},"
  [[ "$platforms" == *,all,* || "$platforms" == *,"$PLATFORM",* ]]
}

ini_error() {
  local conf="$1" line_number="$2" message="$3"
  echo "$conf:$line_number: $message" >&2
  exit 1
}

validate_platform_list() {
  local conf="$1" value="$2" item old_ifs found=0
  [[ "$value" != ,* && "$value" != *, && "$value" != *,,* ]] || {
    echo "$conf: module platforms contain an empty value" >&2
    exit 1
  }
  old_ifs="$IFS"
  IFS=,
  for item in $value; do
    item="$(trim_value "$item")"
    case "$item" in
      all|macos|linux) found=1 ;;
      *) IFS="$old_ifs"; echo "$conf: invalid platform: $item" >&2; exit 1 ;;
    esac
  done
  IFS="$old_ifs"
  ((found)) || { echo "$conf: module platforms cannot be empty" >&2; exit 1; }
}

section_id_exists() {
  local wanted="$1" item
  shift
  for item in "$@"; do
    [[ "$item" == "$wanted" ]] && return 0
  done
  return 1
}

parse_module_ini() {
  local conf="$1" line line_number=0 header section="" section_index=-1
  local key value seen id module_seen=0 MODULE_SEEN_KEYS=""

  PARSED_MODULE_PLATFORMS=all
  PARSED_MODULE_DEFAULT=true
  PARSED_MODULE_ORDER=50
  PARSED_DEP_IDS=()
  PARSED_DEP_PLATFORMS=()
  PARSED_DEP_COMMANDS=()
  PARSED_DEP_INSTALLERS=()
  PARSED_DEP_SOURCES=()
  PARSED_DEP_SEEN=()
  PARSED_LINK_IDS=()
  PARSED_LINK_PLATFORMS=()
  PARSED_LINK_MODES=()
  PARSED_LINK_SOURCES=()
  PARSED_LINK_TARGETS=()
  PARSED_LINK_SEEN=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_number += 1))
    line="$(trim_value "$line")"
    [[ -n "$line" ]] || continue
    case "$line" in \#*|\;*) continue ;; esac

    if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
      header="$(trim_value "${BASH_REMATCH[1]}")"
      case "$header" in
        module)
          ((module_seen == 0)) || ini_error "$conf" "$line_number" "duplicate [module] section"
          module_seen=1
          section=module
          section_index=-1
          ;;
        dependency\ *)
          ((module_seen)) || ini_error "$conf" "$line_number" "[module] must appear before dependency sections"
          id="$(trim_value "${header#dependency }")"
          [[ "$id" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || ini_error "$conf" "$line_number" "invalid dependency id: $id"
          section_id_exists "$id" "${PARSED_DEP_IDS[@]}" && ini_error "$conf" "$line_number" "duplicate dependency section: $id"
          PARSED_DEP_IDS+=("$id")
          PARSED_DEP_PLATFORMS+=(all)
          PARSED_DEP_COMMANDS+=("")
          PARSED_DEP_INSTALLERS+=("")
          PARSED_DEP_SOURCES+=("")
          PARSED_DEP_SEEN+=("")
          section=dependency
          section_index=$((${#PARSED_DEP_IDS[@]} - 1))
          ;;
        link\ *)
          ((module_seen)) || ini_error "$conf" "$line_number" "[module] must appear before link sections"
          id="$(trim_value "${header#link }")"
          [[ "$id" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || ini_error "$conf" "$line_number" "invalid link id: $id"
          section_id_exists "$id" "${PARSED_LINK_IDS[@]}" && ini_error "$conf" "$line_number" "duplicate link section: $id"
          PARSED_LINK_IDS+=("$id")
          PARSED_LINK_PLATFORMS+=(all)
          PARSED_LINK_MODES+=("")
          PARSED_LINK_SOURCES+=("")
          PARSED_LINK_TARGETS+=("")
          PARSED_LINK_SEEN+=("")
          section=link
          section_index=$((${#PARSED_LINK_IDS[@]} - 1))
          ;;
        *) ini_error "$conf" "$line_number" "unknown section: [$header]" ;;
      esac
      continue
    fi

    [[ -n "$section" ]] || ini_error "$conf" "$line_number" "entry appears before a section"
    [[ "$line" == *=* ]] || ini_error "$conf" "$line_number" "expected key = value"
    key="$(trim_value "${line%%=*}")"
    value="$(trim_value "${line#*=}")"
    [[ "$key" =~ ^[a-z][a-z0-9_-]*$ ]] || ini_error "$conf" "$line_number" "invalid key: $key"
    [[ -n "$value" ]] || ini_error "$conf" "$line_number" "empty value for $key"

    case "$section" in
      module)
        seen="$MODULE_SEEN_KEYS"
        [[ "|$seen|" != *"|$key|"* ]] || ini_error "$conf" "$line_number" "duplicate module key: $key"
        MODULE_SEEN_KEYS="${seen:+$seen|}$key"
        case "$key" in
          platforms) PARSED_MODULE_PLATFORMS="$value" ;;
          default)
            [[ "$value" == true || "$value" == false ]] || ini_error "$conf" "$line_number" "default must be true or false"
            PARSED_MODULE_DEFAULT="$value"
            ;;
          order)
            [[ "$value" =~ ^[0-9]+$ ]] || ini_error "$conf" "$line_number" "order must be numeric"
            PARSED_MODULE_ORDER="$value"
            ;;
          *) ini_error "$conf" "$line_number" "unknown module key: $key" ;;
        esac
        ;;
      dependency)
        seen="${PARSED_DEP_SEEN[$section_index]}"
        [[ "|$seen|" != *"|$key|"* ]] || ini_error "$conf" "$line_number" "duplicate dependency key: $key"
        PARSED_DEP_SEEN[$section_index]="${seen:+$seen|}$key"
        case "$key" in
          platform)
            case "$value" in all|macos|linux) ;; *) ini_error "$conf" "$line_number" "invalid dependency platform: $value" ;; esac
            PARSED_DEP_PLATFORMS[$section_index]="$value"
            ;;
          command) PARSED_DEP_COMMANDS[$section_index]="$value" ;;
          installer) PARSED_DEP_INSTALLERS[$section_index]="$value" ;;
          source) PARSED_DEP_SOURCES[$section_index]="$value" ;;
          *) ini_error "$conf" "$line_number" "unknown dependency key: $key" ;;
        esac
        ;;
      link)
        seen="${PARSED_LINK_SEEN[$section_index]}"
        [[ "|$seen|" != *"|$key|"* ]] || ini_error "$conf" "$line_number" "duplicate link key: $key"
        PARSED_LINK_SEEN[$section_index]="${seen:+$seen|}$key"
        case "$key" in
          platform)
            case "$value" in all|macos|linux) ;; *) ini_error "$conf" "$line_number" "invalid link platform: $value" ;; esac
            PARSED_LINK_PLATFORMS[$section_index]="$value"
            ;;
          mode) PARSED_LINK_MODES[$section_index]="$value" ;;
          source) PARSED_LINK_SOURCES[$section_index]="$value" ;;
          target) PARSED_LINK_TARGETS[$section_index]="$value" ;;
          *) ini_error "$conf" "$line_number" "unknown link key: $key" ;;
        esac
        ;;
    esac
  done < "$conf"

  ((module_seen)) || { echo "$conf: missing [module] section" >&2; exit 1; }
  validate_platform_list "$conf" "$PARSED_MODULE_PLATFORMS"

  for section_index in "${!PARSED_DEP_IDS[@]}"; do
    [[ -n "${PARSED_DEP_COMMANDS[$section_index]}" ]] || { echo "$conf: dependency ${PARSED_DEP_IDS[$section_index]} is missing command" >&2; exit 1; }
    [[ "${PARSED_DEP_COMMANDS[$section_index]}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || {
      echo "$conf: dependency ${PARSED_DEP_IDS[$section_index]} has invalid command: ${PARSED_DEP_COMMANDS[$section_index]}" >&2
      exit 1
    }
    case "${PARSED_DEP_INSTALLERS[$section_index]}" in
      brew|brew-cask|cargo|fnm|go|npm|rustup|script) ;;
      "") echo "$conf: dependency ${PARSED_DEP_IDS[$section_index]} is missing installer" >&2; exit 1 ;;
      *) echo "$conf: dependency ${PARSED_DEP_IDS[$section_index]} has invalid installer: ${PARSED_DEP_INSTALLERS[$section_index]}" >&2; exit 1 ;;
    esac
    [[ -n "${PARSED_DEP_SOURCES[$section_index]}" ]] || { echo "$conf: dependency ${PARSED_DEP_IDS[$section_index]} is missing source" >&2; exit 1; }
    if [[ "${PARSED_DEP_INSTALLERS[$section_index]}" != script && ! "${PARSED_DEP_SOURCES[$section_index]}" =~ ^[A-Za-z0-9@._+/:=-]+$ ]]; then
      echo "$conf: dependency ${PARSED_DEP_IDS[$section_index]} has invalid source: ${PARSED_DEP_SOURCES[$section_index]}" >&2
      exit 1
    fi
    if [[ "${PARSED_DEP_INSTALLERS[$section_index]}" == brew-cask && "${PARSED_DEP_PLATFORMS[$section_index]}" != macos ]]; then
      echo "$conf: dependency ${PARSED_DEP_IDS[$section_index]} must set platform = macos for brew-cask" >&2
      exit 1
    fi
  done

  for section_index in "${!PARSED_LINK_IDS[@]}"; do
    case "${PARSED_LINK_MODES[$section_index]}" in
      tree|overlay) ;;
      "") echo "$conf: link ${PARSED_LINK_IDS[$section_index]} is missing mode" >&2; exit 1 ;;
      *) echo "$conf: link ${PARSED_LINK_IDS[$section_index]} has invalid mode: ${PARSED_LINK_MODES[$section_index]}" >&2; exit 1 ;;
    esac
    [[ -n "${PARSED_LINK_SOURCES[$section_index]}" ]] || { echo "$conf: link ${PARSED_LINK_IDS[$section_index]} is missing source" >&2; exit 1; }
    [[ "${PARSED_LINK_SOURCES[$section_index]}" != /* && "${PARSED_LINK_SOURCES[$section_index]}" != .. && "${PARSED_LINK_SOURCES[$section_index]}" != ../* && "${PARSED_LINK_SOURCES[$section_index]}" != */.. && "${PARSED_LINK_SOURCES[$section_index]}" != */../* ]] || {
      echo "$conf: link ${PARSED_LINK_IDS[$section_index]} source must stay inside the repository" >&2
      exit 1
    }
    [[ "${PARSED_LINK_TARGETS[$section_index]}" == "~/"* ]] || { echo "$conf: link ${PARSED_LINK_IDS[$section_index]} target must start with ~/" >&2; exit 1; }
  done
}

discover_modules() {
  local conf dir name records sorted order
  detect_platform
  records="$(mktemp)"
  sorted="$(mktemp)"

  for conf in "$ROOT"/modules/*/module.ini; do
    [[ -f "$conf" ]] || continue
    dir="${conf%/module.ini}"
    name="${dir##*/}"
    [[ "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || {
      echo "Invalid module directory name: $name" >&2
      rm -f "$records" "$sorted"
      exit 1
    }
    parse_module_ini "$conf"
    order=$((10#$PARSED_MODULE_ORDER))
    printf '%08d|%s|%s|%s|%s\n' "$order" "$name" "$dir" "$PARSED_MODULE_PLATFORMS" "$PARSED_MODULE_DEFAULT" >> "$records"
  done

  [[ -s "$records" ]] || {
    echo "No modules found under $ROOT/modules." >&2
    rm -f "$records" "$sorted"
    exit 1
  }
  sort -t '|' -k1,1n -k2,2 "$records" > "$sorted"

  while IFS='|' read -r order name dir parsed_platforms parsed_default; do
    order="${order#"${order%%[!0]*}"}"
    [[ -n "$order" ]] || order=0
    MODULE_ORDERS+=("$order")
    MODULE_NAMES+=("$name")
    MODULE_DIRS+=("$dir")
    MODULE_PLATFORMS+=("$parsed_platforms")
    MODULE_DEFAULTS+=("$parsed_default")
  done < "$sorted"
  rm -f "$records" "$sorted"
}

module_index() {
  local wanted="$1" index
  for index in "${!MODULE_NAMES[@]}"; do
    [[ "${MODULE_NAMES[$index]}" == "$wanted" ]] && { printf '%s\n' "$index"; return; }
  done
  return 1
}

module_requested() {
  local name="$1" wanted
  ((${#CONFIGS[@]} == 0)) && return 0
  for wanted in "${CONFIGS[@]}"; do
    [[ "$wanted" == "$name" ]] && return 0
  done
  return 1
}

select_modules() {
  local wanted index name
  SELECTED_MODULE_NAMES=()
  SELECTED_MODULE_DIRS=()

  for wanted in "$@"; do
    index="$(module_index "$wanted" || true)"
    [[ -n "$index" ]] || { echo "Unknown module: $wanted" >&2; exit 2; }
    platform_matches "${MODULE_PLATFORMS[$index]}" || {
      echo "Module $wanted is not available on $PLATFORM." >&2
      exit 2
    }
  done

  for index in "${!MODULE_NAMES[@]}"; do
    name="${MODULE_NAMES[$index]}"
    platform_matches "${MODULE_PLATFORMS[$index]}" || continue
    if ((${#CONFIGS[@]} == 0)); then
      [[ "${MODULE_DEFAULTS[$index]}" == true ]] || continue
    else
      module_requested "$name" || continue
    fi
    SELECTED_MODULE_NAMES+=("$name")
    SELECTED_MODULE_DIRS+=("${MODULE_DIRS[$index]}")
  done
}

list_modules() {
  local index availability
  printf '%-24s %-12s %-8s %s\n' MODULE PLATFORMS DEFAULT STATUS
  for index in "${!MODULE_NAMES[@]}"; do
    availability=unavailable
    platform_matches "${MODULE_PLATFORMS[$index]}" && availability=available
    printf '%-24s %-12s %-8s %s\n' \
      "${MODULE_NAMES[$index]}" "${MODULE_PLATFORMS[$index]}" \
      "${MODULE_DEFAULTS[$index]}" "$availability"
  done
}

resolve_dependency_source() {
  local module_dir="$1" installer="$2" source="$3" module_rel
  if [[ "$installer" != script ]]; then
    printf '%s\n' "$source"
    return
  fi

  [[ "$source" != /* && "$source" != .. && "$source" != ../* && "$source" != */.. && "$source" != */../* ]] || {
    echo "$module_dir/module.ini: script source must stay inside its module" >&2
    exit 1
  }
  module_rel="${module_dir#"$ROOT/"}"
  source="$module_rel/$source"
  [[ "$source" != /* && "$source" != ../* && "$source" != */../* && "$source" != */.. && "$source" != .. ]] || {
    echo "$module_dir/module.ini: script source must stay inside the repository" >&2
    exit 1
  }
  [[ -f "$ROOT/$source" ]] || { echo "$module_dir/module.ini: missing script: $source" >&2; exit 1; }
  printf '%s\n' "$source"
}

emit_module_dependencies() {
  local module_dir="$1" conf="$module_dir/module.ini" index source
  parse_module_ini "$conf"
  for index in "${!PARSED_DEP_IDS[@]}"; do
    source="$(resolve_dependency_source "$module_dir" "${PARSED_DEP_INSTALLERS[$index]}" "${PARSED_DEP_SOURCES[$index]}")"
    printf '%s | %s | %s | %s | %s\n' \
      "${PARSED_DEP_PLATFORMS[$index]}" "${PARSED_DEP_IDS[$index]}" \
      "${PARSED_DEP_COMMANDS[$index]}" "${PARSED_DEP_INSTALLERS[$index]}" "$source"
  done
}

write_dependency_manifest() {
  local output="$1" module_dir
  shift
  : > "$output"
  for module_dir in "$@"; do
    emit_module_dependencies "$module_dir" >> "$output"
  done
}

install_selected_dependencies() {
  local manifest args=() status
  manifest="$(mktemp)"
  write_dependency_manifest "$manifest" "${SELECTED_MODULE_DIRS[@]}"
  if [[ ! -s "$manifest" ]]; then
    rm -f "$manifest"
    return 0
  fi
  ((DRY_RUN)) && args+=(--dry-run)
  if "$ROOT/scripts/install-deps.sh" "${args[@]}" "$manifest"; then
    status=0
  else
    status=$?
  fi
  rm -f "$manifest"
  return "$status"
}

resolve_target() {
  local target="$1" relative
  [[ "$target" == "~/"* ]] || { echo "Module target must start with ~/: $target" >&2; exit 1; }
  relative="${target#\~/}"
  if [[ -n "$relative" ]]; then
    printf '%s\n' "$HOME/$relative"
  else
    printf '%s\n' "$HOME"
  fi
}

record_link() {
  local module="$1" source="$2" target="$3" temp
  ((DRY_RUN)) && return
  mkdir -p "$(dirname "$STATE_FILE")"
  temp="$STATE_FILE.tmp.$$"
  if [[ -f "$STATE_FILE" ]]; then
    awk -F '\t' -v target="$target" '$3 != target' "$STATE_FILE" > "$temp"
  else
    : > "$temp"
  fi
  printf '%s\t%s\t%s\n' "$module" "$source" "$target" >> "$temp"
  mv "$temp" "$STATE_FILE"
}

link_one() {
  local module="$1" source="$2" target="$3" current
  [[ -e "$source" || -L "$source" ]] || { echo "Missing source: $source" >&2; exit 1; }

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    if [[ "$current" == "$source" ]]; then
      echo "Already linked: $target"
      record_link "$module" "$source" "$target"
      return
    fi
    if [[ "$current" == "$ROOT/"* ]]; then
      if ((DRY_RUN)); then
        printf '+ ln -sfn %q %q\n' "$source" "$target"
      else
        ln -sfn "$source" "$target"
        echo "Relinked: $target"
      fi
      record_link "$module" "$source" "$target"
      return
    fi
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    echo "Skipped unmanaged path: $target"
    return
  fi

  if ((DRY_RUN)); then
    printf '+ mkdir -p %q\n' "$(dirname "$target")"
    printf '+ ln -s %q %q\n' "$source" "$target"
  else
    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
    echo "Linked: $target"
  fi
  record_link "$module" "$source" "$target"
}

link_overlay() {
  local module="$1" source_rel="$2" target_spec="$3" source_root target_root file suffix
  source_rel="${source_rel#./}"
  source_root="$ROOT/$source_rel"
  target_root="$(resolve_target "$target_spec")"
  [[ -d "$source_root" ]] || { echo "Overlay source must be a directory: $source_rel" >&2; exit 1; }

  while IFS= read -r file; do
    [[ -n "$file" && (-f "$ROOT/$file" || -L "$ROOT/$file") ]] || continue
    suffix="${file#"$source_rel"/}"
    link_one "$module" "$ROOT/$file" "$target_root/$suffix"
  done < <(git -C "$ROOT" ls-files --cached --others --exclude-standard -- "$source_rel")
}

link_tree() {
  local module="$1" source_rel="$2" target_spec="$3"
  source_rel="${source_rel#./}"
  link_one "$module" "$ROOT/$source_rel" "$(resolve_target "$target_spec")"
}

link_parsed_module() {
  local module="$1" module_dir="$2" index
  parse_module_ini "$module_dir/module.ini"
  for index in "${!PARSED_LINK_IDS[@]}"; do
    platform_matches "${PARSED_LINK_PLATFORMS[$index]}" || continue
    case "${PARSED_LINK_MODES[$index]}" in
      tree) link_tree "$module" "${PARSED_LINK_SOURCES[$index]}" "${PARSED_LINK_TARGETS[$index]}" ;;
      overlay) link_overlay "$module" "${PARSED_LINK_SOURCES[$index]}" "${PARSED_LINK_TARGETS[$index]}" ;;
    esac
  done
}

link_module_home() {
  local module="$1" module_dir="$2" home_rel
  [[ -d "$module_dir/home" ]] || return 0
  home_rel="${module_dir#"$ROOT/"}/home"
  link_overlay "$module" "$home_rel" "~/"
}

link_selected_modules() {
  local index module module_dir
  for index in "${!SELECTED_MODULE_DIRS[@]}"; do
    module="${SELECTED_MODULE_NAMES[$index]}"
    module_dir="${SELECTED_MODULE_DIRS[$index]}"
    link_module_home "$module" "$module_dir"
    link_parsed_module "$module" "$module_dir"
  done
  return 0
}

run_selected_hooks() {
  local hook_name="$1" index hook
  for index in "${!SELECTED_MODULE_DIRS[@]}"; do
    hook="${SELECTED_MODULE_DIRS[$index]}/$hook_name"
    [[ -f "$hook" ]] || continue
    if ((DRY_RUN)); then
      printf '+ bash %q\n' "$hook"
    else
      bash "$hook"
    fi
  done
  return 0
}

clean_recorded_links() {
  local module="$1" temp state_module source target
  [[ -f "$STATE_FILE" ]] || return 0
  temp="$STATE_FILE.tmp.$$"
  : > "$temp"
  while IFS=$'\t' read -r state_module source target; do
    if [[ "$state_module" != "$module" ]]; then
      printf '%s\t%s\t%s\n' "$state_module" "$source" "$target" >> "$temp"
      continue
    fi
    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
      if ((DRY_RUN)); then
        printf '+ rm %q\n' "$target"
        printf '%s\t%s\t%s\n' "$state_module" "$source" "$target" >> "$temp"
      else
        rm "$target"
        echo "Removed link: $target"
      fi
    else
      echo "Skipped link no longer owned by $module: $target"
    fi
  done < "$STATE_FILE"
  if ((DRY_RUN)); then
    rm -f "$temp"
  else
    mv "$temp" "$STATE_FILE"
  fi
}

clean_selected_module() {
  local name="$1" index module_dir target_manifest keep_manifest args=(--clean) status
  local keep_dirs=()
  index="$(module_index "$name")"
  module_dir="${MODULE_DIRS[$index]}"
  clean_recorded_links "$name"

  target_manifest="$(mktemp)"
  keep_manifest="$(mktemp)"
  write_dependency_manifest "$target_manifest" "$module_dir"
  if [[ ! -s "$target_manifest" ]]; then
    rm -f "$target_manifest" "$keep_manifest"
    return 0
  fi

  for index in "${!MODULE_DIRS[@]}"; do
    [[ "${MODULE_NAMES[$index]}" == "$name" ]] && continue
    platform_matches "${MODULE_PLATFORMS[$index]}" || continue
    keep_dirs+=("${MODULE_DIRS[$index]}")
  done
  write_dependency_manifest "$keep_manifest" "${keep_dirs[@]}"
  ((DRY_RUN)) && args+=(--dry-run)
  if [[ -s "$keep_manifest" ]]; then
    args+=("$target_manifest" "$keep_manifest")
  else
    args+=("$target_manifest")
  fi
  if "$ROOT/scripts/install-deps.sh" "${args[@]}"; then
    status=0
  else
    status=$?
  fi
  rm -f "$target_manifest" "$keep_manifest"
  return "$status"
}
