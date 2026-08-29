#!/usr/bin/env bash

set -euo pipefail

# 懒猫微服客户端。上游只发布裸二进制 + latest-version.json 里的 SHA-256，没有
# tap/crate/npm 包，所以走 script 安装器而不是某个包管理器。
HCLIENT_CLI_VERSION=1.5.1
HCLIENT_CLI_BIN="${HCLIENT_CLI_BIN:-$HOME/.local/bin/hclient-cli}"
HCLIENT_CLI_BASE_URL="${HCLIENT_CLI_BASE_URL:-https://dl.lazycat.cloud/hclient-cli}"
HCLIENT_CLI_PS="${HCLIENT_CLI_PS:-ps}"

# 下载目录必须是文件级变量，不能是 install_binary 的 local：EXIT trap 是在函数返回之后
# 才跑的，那时 local 已经出栈，set -u 会把清理本身变成一次报错。
HCLIENT_CLI_TEMP_DIR=""
discard_temp_dir() {
  [[ -z "$HCLIENT_CLI_TEMP_DIR" ]] || rm -rf "$HCLIENT_CLI_TEMP_DIR"
}
trap discard_temp_dir EXIT HUP INT TERM

sha256_of() {
  # macOS 自带 /sbin/sha256sum，但 `-c` 的行为和 GNU 版不完全一致；只取摘要再比字符串。
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# hclient-cli 自带 `upgrade`，会把二进制换成 latest-version.json 里的版本。要求精确
# 等于 pin 的话，下一次 install.sh 会把用户刚升上去的版本降回来，还白下 42M；所以 pin
# 是下限而不是等号。想强制统一到某个版本就改 HCLIENT_CLI_VERSION 并手动重装。
version_at_least() {
  local have="$1" want="$2" oldest
  if [[ "$have" == "$want" ]]; then
    return 0
  fi
  # 空版本号会排在最前面，于是自然被判成不满足下限。
  oldest="$(printf '%s\n%s\n' "$have" "$want" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)"
  [[ "$oldest" == "$want" ]]
}

binary_ok() {
  local reported
  [[ -x "$HCLIENT_CLI_BIN" ]] || return 1
  reported="$("$HCLIENT_CLI_BIN" -version 2>/dev/null || true)"
  version_at_least "${reported#v}" "$HCLIENT_CLI_VERSION"
}

# 摘要表就是"支持哪些目标"的唯一来源：认不出的组合在这里报错，不用再单独维护一份
# 平台白名单，也不会出现加了架构却忘了加摘要、最后炸在 set -u 上的情况。
select_asset() {
  local os arch
  os="${HCLIENT_CLI_OS:-$(uname -s)}"
  arch="${HCLIENT_CLI_ARCH:-$(uname -m)}"
  case "$os" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
  esac
  case "$arch" in
    x86_64) arch=amd64 ;;
    aarch64) arch=arm64 ;;
  esac

  case "$os-$arch" in
    darwin-arm64) HCLIENT_CLI_ASSET_SHA256=f3f20f9bc700cd05ef8e1386ab3f3bc404ee507d9f5310bff8ec6ac51da1c465 ;;
    darwin-amd64) HCLIENT_CLI_ASSET_SHA256=77d86d671d8f830c5eccaf1862c3c15eb3026153fd5aa08f7f2fcc40f6a87aff ;;
    linux-amd64) HCLIENT_CLI_ASSET_SHA256=a0cdebcb652bdae4ba26ff96827c558f368af0673ad910545b4499f9897cfa6c ;;
    linux-arm64) HCLIENT_CLI_ASSET_SHA256=348c55c87a4c345ea9c0591eba308e7b286b34096543b1e47e4e2457c5832ede ;;
    *) echo "Unsupported hclient-cli target: $os-$arch" >&2; return 1 ;;
  esac

  HCLIENT_CLI_ASSET_SHA256="${HCLIENT_CLI_SHA256:-$HCLIENT_CLI_ASSET_SHA256}"
  HCLIENT_CLI_DOWNLOAD_URL="${HCLIENT_CLI_DOWNLOAD_URL:-$HCLIENT_CLI_BASE_URL/v$HCLIENT_CLI_VERSION/hclient-cli-$os-$arch}"
}

install_binary() {
  local candidate actual reported
  command -v curl >/dev/null 2>&1 || { echo "curl is required to install hclient-cli." >&2; return 1; }

  select_asset
  HCLIENT_CLI_TEMP_DIR="$(mktemp -d)"
  candidate="$HCLIENT_CLI_TEMP_DIR/hclient-cli"

  curl -fsSL --retry 3 --output "$candidate" "$HCLIENT_CLI_DOWNLOAD_URL"
  actual="$(sha256_of "$candidate")"
  [[ "$actual" == "$HCLIENT_CLI_ASSET_SHA256" ]] || {
    echo "hclient-cli checksum mismatch: expected $HCLIENT_CLI_ASSET_SHA256, got $actual" >&2
    return 1
  }

  # 摘要过了还要再问一次版本：这道检查抓的不是坏下载，而是升级时改了摘要表却漏改
  # HCLIENT_CLI_VERSION（或者反过来）。
  chmod 0755 "$candidate"
  reported="$("$candidate" -version 2>&1 || true)"
  version_at_least "${reported#v}" "$HCLIENT_CLI_VERSION" || {
    echo "Downloaded hclient-cli reported '$reported', expected at least v$HCLIENT_CLI_VERSION." >&2
    return 1
  }

  # 就地替换而不是先删后写：daemon 可能正开着 TUN，抽走 inode 会让它重启不来。
  mkdir -p "$(dirname "$HCLIENT_CLI_BIN")"
  install -m 0755 "$candidate" "$HCLIENT_CLI_BIN.new"
  mv "$HCLIENT_CLI_BIN.new" "$HCLIENT_CLI_BIN"
}

remove_binary() {
  local holders
  if [[ ! -e "$HCLIENT_CLI_BIN" && ! -L "$HCLIENT_CLI_BIN" ]]; then
    return 0
  fi

  # 一次读进变量再匹配：`ps | grep -q` 会把 SIGPIPE 反馈成 pipefail 失败，看起来像没人占用。
  holders="$("$HCLIENT_CLI_PS" -ax -o comm= 2>/dev/null || true)"
  case "$holders" in
    *"$HCLIENT_CLI_BIN"*)
      echo "hclient-cli is still running from $HCLIENT_CLI_BIN; run 'hclient-cli stop-daemon' first." >&2
      return 1
      ;;
  esac

  rm -f "$HCLIENT_CLI_BIN"
  echo "Removed $HCLIENT_CLI_BIN. hclient-cli's own config, managed startup, and box state were left untouched."
}

case "${1:-}" in
  check)
    binary_ok
    ;;
  install)
    binary_ok || install_binary
    ;;
  clean)
    remove_binary
    ;;
  *)
    echo "Usage: $0 check|install|clean" >&2
    exit 2
    ;;
esac
