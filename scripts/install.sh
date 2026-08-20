#!/usr/bin/env bash
#
# 按 navigation.txt 的映射，把 repo 里的某个目录软链到它该去的地方。
#   bash scripts/install.sh fish   ->  ln -sfn <repo>/fish ~/.config/fish

set -x

FLAG=$1
if [ -z "$FLAG" ]; then
  echo "usage: install.sh <dir>   (dir 取自 navigation.txt 第一列)" >&2
  exit 1
fi

# repo 根目录从脚本自身位置推出来，克隆到哪都能跑。
cd "$(dirname "$(readlink -f "$0")")/.." || exit 1

if [ ! -d "$FLAG" ]; then
  echo "no such directory in repo: $FLAG" >&2
  exit 1
fi

# navigation.txt 每行形如 "fish => ~/.config/fish"，取第三列。
TARGET=$(awk -v want="$FLAG" '$1 == want { print $3 }' navigation.txt)
if [ -z "$TARGET" ]; then
  echo "$FLAG is not mapped in navigation.txt" >&2
  exit 1
fi

# awk 不展开 ~，自己来。
TARGET="${TARGET/#\~/$HOME}"

# -n 是关键：目标已经是软链时，不带 -n 的 ln 会钻进去建 <target>/<FLAG>。
ln -sfn "$(pwd)/$FLAG" "$TARGET"
