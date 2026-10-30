#!/usr/bin/env bash
#
# Pi 扩展包走 pi 自己的 `pi install`：声明写进 ~/.pi/agent/settings.json，代码装进
# ~/.pi/agent/npm，两样都是运行时状态，不进仓库。这里只保证「这些包被声明了」——
# settings.json 里已声明但还没装的包，pi 下次启动会自己补装。
#
# NixOS 不走这里：nix/home.nix 把 pi-open-tui 钉在 nix store 里，由 pi-settings.py
# 把 settings.json 里的 npm:pi-open-tui 改写成本地路径。两边别同时管一台机器。

set -euo pipefail

# 不钉版本：`pi update --extensions` 跳过钉了版本的包，钉了只会让新机器装旧代码。
PACKAGES='
npm:pi-knowledge
npm:nowledge-mem-pi
npm:pi-open-tui
'

ACTION="${1:-}"
case "$ACTION" in
  check) command -v pi >/dev/null 2>&1 || exit 1 ;;
  install) command -v pi >/dev/null 2>&1 || {
    echo "pi is required before its packages can be installed." >&2
    exit 1
  } ;;
  clean) command -v pi >/dev/null 2>&1 || exit 0 ;;
  *) echo "Usage: $0 check|install|clean" >&2; exit 2 ;;
esac

# `pi list` 每个包一行 "  <source>"，下一行缩进更深的是安装路径。只跑一次：pi 冷启动
# 要一秒多。用 here-string 而不是管道：grep -q 命中即退，pipefail 会把上游的 SIGPIPE
# 当成没匹配。
LIST="$(pi list)"
FAILED=""
for source in $PACKAGES; do
  configured=0
  grep -Fqx -- "  $source" <<<"$LIST" && configured=1
  case "$ACTION" in
    check) ((configured)) || exit 1 ;;
    install)
      if ((configured)); then
        echo "Already declared: $source"
      else
        pi install "$source" || FAILED="$FAILED $source"
      fi
      ;;
    clean)
      if ((configured)); then
        pi remove "$source" || FAILED="$FAILED $source"
      fi
      ;;
  esac
done

if [[ -n "$FAILED" ]]; then
  echo "Pi packages failed:$FAILED" >&2
  exit 1
fi
