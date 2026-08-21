#!/usr/bin/env bash
#
# Herdr 插件不是 CLI，装不进 cli.conf 的 brew/cargo 那套，但 herdr 自己有
# `herdr plugin install`，所以走 script installer 这个口子。
#
# 为什么必须声明：configs/herdr/config.toml 里有多个键绑在 plugin_action 上，
# 而 plugins.json 和 plugins/github/ 都在 .gitignore 里（220M 的插件代码不该进仓库）。
# 不声明的话，新机器 install.sh 跑完、config.toml 也链好了，prefix+t / prefix+p /
# prefix+g 这些键全是死的 —— 插件根本不存在。

set -euo pipefail

# owner/repo[/subdir] | ref | plugin_id
#
# 目标是「新机器上这些键能用」，不是「和某台机器逐字节一样」，所以 ref 一律指向
# 上游发布的东西（tag 优先，没 tag 的用默认分支），不钉死在某个 commit 上 ——
# 钉 commit 只会让新机器装到一份越来越旧的代码，能力反而更容易坏。
# 想锁版本就把 ref 改成具体 tag，重跑 install.sh。
PLUGINS='
cinco/herdr-grep-nvim|v1.0.3|grep-nvim
ZingerLittleBee/Heeler/plugin|main|heeler
thanhdat77/herdr-navigator|v0.3.5|herdr-navigator
persiyanov/herdr-reviewr|v0.29.0|persiyanov.reviewr
AkashJana18/herdr-scratch|main|herdr.scratch
ntindle/herdr-resurrect|main|ntindle.herdr-resurrect
rmarganti/herdr-pluck|v0.3.1|rmarganti.herdr-pluck
'
# 关于上面的 main：它们当初就是不带 ref 装的（走默认分支），而且 herdr-scratch 的
# main 已经跑在 v1.0.1 tag 前面了 —— 写 v1.0.1 反而会把新机器装回更旧的代码。
# resurrect 没发过 tag，所以只能跟 main。

# `herdr plugin list` 每行形如 "- grep-nvim (grep-nvim) enabled [github:...]"。
# 用 -F 而不是正则：plugin_id 里有 "." （herdr.scratch），正则会把它当任意字符。
#
# 只查一次存到变量里，不要每个插件都跑一遍 herdr：`grep -q` 命中就退出、把管道关掉，
# 连着 6 次 SIGPIPE 下来 herdr 会漏报，实测有的插件明明装了也说没装。
ACTION="${1:-}"
case "$ACTION" in
  check) command -v herdr >/dev/null 2>&1 || exit 1 ;;
  install) command -v herdr >/dev/null 2>&1 || {
    echo "herdr is required before its plugins can be installed." >&2
    exit 1
  } ;;
  clean) command -v herdr >/dev/null 2>&1 || exit 0 ;;
  *) echo "Usage: $0 check|install|clean" >&2; exit 2 ;;
esac

PLUGIN_LIST="$(herdr plugin list)"
FAILED=""

apply_plugin() {
  local spec="$1" ref="$2" id="$3" line
  line="$(printf '%s\n' "$PLUGIN_LIST" | grep -F -m 1 -- "- $id (" || true)"

  case "$ACTION" in
    check)
      [[ "$line" == *" enabled "* && "$line" == *"@$ref]" ]] || FAILED="${FAILED}$id "
      ;;
    install)
      if [[ "$line" == *" enabled "* && "$line" == *"@$ref]" ]]; then
        echo "Already installed: herdr plugin $id"
      elif [[ -n "$line" && "$line" == *"@$ref]" ]]; then
        echo "Enabling herdr plugin: $id"
        herdr plugin enable "$id" || FAILED="${FAILED}$id "
      else
        echo "Installing herdr plugin: $id ($spec @ $ref)"
        # Pluck 会读这个命名空间化开关跳过无 checksum 的预编译包；其他插件忽略它。
        HERDR_PLUCK_BUILD_FROM_SOURCE=1 herdr plugin install "$spec" --ref "$ref" --yes || FAILED="${FAILED}$id "
      fi
      ;;
    clean)
      [[ -n "$line" ]] || return 0
      # uninstall 没有 --yes，install 有。
      herdr plugin uninstall "$id" || FAILED="${FAILED}$id "
      ;;
  esac
  return 0
}

# bash 3.2 没有 mapfile，直接喂 here-string。
while IFS='|' read -r spec ref id; do
  [[ -n "${id:-}" ]] || continue
  apply_plugin "$spec" "$ref" "$id"
done <<< "$PLUGINS"

[[ -z "$FAILED" ]] || {
  [[ "$ACTION" == check ]] || echo "Herdr plugin $ACTION failed: $FAILED" >&2
  exit 1
}
