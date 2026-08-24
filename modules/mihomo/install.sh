#!/usr/bin/env bash

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
MIHOMO_VERSION=1.19.30
MIHOMO_BIN="${MIHOMO_BIN:-$HOME/.local/bin/mihomo}"
MIHOMO_CONFIG_DIR="${MIHOMO_CONFIG_DIR:-$HOME/.config/mihomo}"
MIHOMO_UNIT_SOURCE="$ROOT/modules/mihomo/mihomo.service"
MIHOMO_UNIT_TARGET="${MIHOMO_UNIT_TARGET:-$HOME/.config/systemd/user/mihomo.service}"
MIHOMO_SYSTEMCTL="${MIHOMO_SYSTEMCTL:-systemctl}"
MIHOMO_SETCAP="${MIHOMO_SETCAP:-setcap}"
MIHOMO_GETCAP="${MIHOMO_GETCAP:-getcap}"

binary_version_ok() {
  local output
  [[ -x "$MIHOMO_BIN" ]] || return 1
  output="$("$MIHOMO_BIN" -v 2>&1 || true)"
  [[ "$output" == *"Mihomo Meta v$MIHOMO_VERSION "* ]]
}

capabilities_ok() {
  local output
  command -v "$MIHOMO_GETCAP" >/dev/null 2>&1 || return 1
  output="$("$MIHOMO_GETCAP" "$MIHOMO_BIN" 2>/dev/null || true)"
  [[ "$output" == *cap_net_admin* && "$output" == *cap_net_raw* && "$output" == *"=ep"* ]]
}

unit_ok() {
  [[ -L "$MIHOMO_UNIT_TARGET" ]] && [[ "$(readlink "$MIHOMO_UNIT_TARGET")" == "$MIHOMO_UNIT_SOURCE" ]]
}

service_ready() {
  command -v "$MIHOMO_SYSTEMCTL" >/dev/null 2>&1 || return 1
  "$MIHOMO_SYSTEMCTL" --user is-enabled --quiet mihomo.service >/dev/null 2>&1 || return 1
  [[ ! -e "$MIHOMO_CONFIG_DIR/config.yaml" ]] || \
    "$MIHOMO_SYSTEMCTL" --user is-active --quiet mihomo.service >/dev/null 2>&1
}

run_as_root() {
  if [[ -n "${MIHOMO_ROOT_RUNNER:-}" ]]; then
    "$MIHOMO_ROOT_RUNNER" "$@"
  elif ((EUID == 0)); then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "sudo is required to grant mihomo network capabilities." >&2
    return 1
  fi
}

install_capability_tools() {
  if command -v "$MIHOMO_SETCAP" >/dev/null 2>&1 && command -v "$MIHOMO_GETCAP" >/dev/null 2>&1; then
    return
  fi

  if command -v omarchy >/dev/null 2>&1; then
    omarchy pkg add libcap
  elif command -v pacman >/dev/null 2>&1; then
    run_as_root pacman -S --needed libcap
  elif command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get install -y libcap2-bin
  elif command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y libcap
  else
    echo "Install setcap and getcap before installing mihomo." >&2
    return 1
  fi

  command -v "$MIHOMO_SETCAP" >/dev/null 2>&1 && command -v "$MIHOMO_GETCAP" >/dev/null 2>&1
}

select_asset() {
  local arch="${MIHOMO_ARCH:-$(uname -m)}"
  case "$arch" in
    x86_64|amd64)
      MIHOMO_ASSET="mihomo-linux-amd64-v$MIHOMO_VERSION.gz"
      MIHOMO_ASSET_SHA256=cf06ce2c7d1421bdbda14ee4a5b6046672dc35ebf8eecd8e77504ec3c0ed9a84
      ;;
    aarch64|arm64)
      MIHOMO_ASSET="mihomo-linux-arm64-v$MIHOMO_VERSION.gz"
      MIHOMO_ASSET_SHA256=58896873736d28628f66de3677c8654fa0f180662523148e136cff4f6e890069
      ;;
    *)
      echo "Unsupported mihomo architecture: $arch" >&2
      return 1
      ;;
  esac

  MIHOMO_DOWNLOAD_URL="${MIHOMO_DOWNLOAD_URL:-https://github.com/MetaCubeX/mihomo/releases/download/v$MIHOMO_VERSION/$MIHOMO_ASSET}"
  MIHOMO_ASSET_SHA256="${MIHOMO_SHA256:-$MIHOMO_ASSET_SHA256}"
}

install_binary() {
  local temp_dir archive candidate output
  command -v curl >/dev/null 2>&1 || { echo "curl is required to install mihomo." >&2; return 1; }
  command -v gzip >/dev/null 2>&1 || { echo "gzip is required to install mihomo." >&2; return 1; }
  command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required to install mihomo." >&2; return 1; }

  select_asset
  temp_dir="$(mktemp -d)"
  archive="$temp_dir/$MIHOMO_ASSET"
  candidate="$temp_dir/mihomo"
  trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

  curl -fsSL --retry 3 --output "$archive" "$MIHOMO_DOWNLOAD_URL"
  printf '%s  %s\n' "$MIHOMO_ASSET_SHA256" "$archive" | sha256sum -c -
  gzip -dc "$archive" > "$candidate"
  chmod 0755 "$candidate"
  output="$("$candidate" -v 2>&1 || true)"
  [[ "$output" == *"Mihomo Meta v$MIHOMO_VERSION "* ]] || {
    echo "Downloaded mihomo binary did not report v$MIHOMO_VERSION." >&2
    return 1
  }

  mkdir -p "$(dirname "$MIHOMO_BIN")"
  install -m 0755 "$candidate" "$MIHOMO_BIN.new"
  mv "$MIHOMO_BIN.new" "$MIHOMO_BIN"
  rm -rf "$temp_dir"
  trap - EXIT HUP INT TERM
}

install_capabilities() {
  install_capability_tools
  run_as_root "$MIHOMO_SETCAP" 'cap_net_admin,cap_net_raw=+ep' "$MIHOMO_BIN"
  capabilities_ok || {
    echo "mihomo network capability check failed after setcap." >&2
    return 1
  }
}

install_unit() {
  local backup
  mkdir -p "$(dirname "$MIHOMO_UNIT_TARGET")"
  if unit_ok; then
    return
  fi

  if [[ -e "$MIHOMO_UNIT_TARGET" || -L "$MIHOMO_UNIT_TARGET" ]]; then
    backup="$MIHOMO_UNIT_TARGET.backup.$(date +%Y%m%d%H%M%S).$$"
    mv "$MIHOMO_UNIT_TARGET" "$backup"
    echo "Backed up existing mihomo service: $backup"
  fi
  ln -s "$MIHOMO_UNIT_SOURCE" "$MIHOMO_UNIT_TARGET"
}

configure_service() {
  command -v "$MIHOMO_SYSTEMCTL" >/dev/null 2>&1 || {
    echo "systemctl is required to configure the mihomo user service." >&2
    return 1
  }
  "$MIHOMO_SYSTEMCTL" --user daemon-reload
  "$MIHOMO_SYSTEMCTL" --user enable mihomo.service
  if [[ -e "$MIHOMO_CONFIG_DIR/config.yaml" ]]; then
    "$MIHOMO_SYSTEMCTL" --user restart mihomo.service
  else
    echo "mihomo is installed but not started: missing $MIHOMO_CONFIG_DIR/config.yaml"
  fi
}

case "${1:-}" in
  check)
    binary_version_ok && capabilities_ok && unit_ok && service_ready
    ;;
  install)
    binary_version_ok || install_binary
    capabilities_ok || install_capabilities
    install_unit
    configure_service
    ;;
  clean)
    echo "mihomo cleanup is intentionally manual; proxy configuration and service state were left untouched."
    ;;
  *)
    echo "Usage: $0 check|install|clean" >&2
    exit 2
    ;;
esac
