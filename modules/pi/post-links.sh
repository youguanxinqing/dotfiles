#!/usr/bin/env bash

set -euo pipefail

# models.json 是种子，不是链接：magpie 这类本机代理会把自己的模型表写进去，链接会让
# 这些本机状态落进公开仓库。只在新机器上没有它时放一份，之后归这台机器自己。
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)"
target="$HOME/.pi/agent/models.json"
if [[ ! -e "$target" && ! -L "$target" ]]; then
  mkdir -p "${target%/*}"
  cp "$ROOT/modules/pi/models.json" "$target"
  echo "Seeded: $target"
fi
