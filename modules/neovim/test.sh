#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

NVIM="$ROOT/modules/neovim/install.sh"
TEST_HOME="$TEST_ROOT/home"
mkdir -p "$TEST_HOME"

# 本地仓库当上游：这套断言讲的是 clone/refuse/clean 的行为，不是 GitHub 通不通。
UPSTREAM="$TEST_ROOT/upstream"
mkdir -p "$UPSTREAM"
git -C "$UPSTREAM" init -q -b main
printf 'return {}\n' > "$UPSTREAM/init.lua"
git -C "$UPSTREAM" add init.lua
# 身份不带 @：check-private.sh 会把任何 a@b 当成邮箱拦下来，而这只是个假作者。
git -C "$UPSTREAM" -c user.email=test -c user.name=test commit -qm init
export DOTFILES_NVIM_REPO="$UPSTREAM"

CONFIG="$TEST_HOME/.config/nvim"

# 没 clone 之前 check 必须失败，否则 install 永远不会被触发。
! HOME="$TEST_HOME" "$NVIM" check || die "check passed before the clone existed"
HOME="$TEST_HOME" "$NVIM" install
[ -f "$CONFIG/init.lua" ] || die "install produced no init.lua"
HOME="$TEST_HOME" "$NVIM" check
# 幂等：重跑不该报错，也不该重新 clone。
HOME="$TEST_HOME" "$NVIM" install
HOME="$TEST_HOME" "$NVIM" check

# clean 不碰配置 —— 里面可能有没推的提交。
HOME="$TEST_HOME" "$NVIM" clean
[ -f "$CONFIG/init.lua" ] || die "clean deleted the nvim config"
HOME="$TEST_HOME" "$NVIM" check

# 别人的配置：不覆盖，也不让 check 变绿。
rm -rf "$CONFIG"
mkdir -p "$CONFIG"
printf 'not ours\n' > "$CONFIG/init.lua"
! HOME="$TEST_HOME" "$NVIM" install 2>/dev/null || die "install replaced an unmanaged nvim config"
grep -q 'not ours' "$CONFIG/init.lua" || die "install overwrote an unmanaged nvim config"
! HOME="$TEST_HOME" "$NVIM" check || die "check passed on an unrelated nvim config"
HOME="$TEST_HOME" "$NVIM" clean
grep -q 'not ours' "$CONFIG/init.lua" || die "clean deleted an unmanaged nvim config"

# 空目录也算别人的：clone 进一个已存在的目录会直接失败，不如自己先喊。
rm -rf "$CONFIG"
mkdir -p "$CONFIG"
! HOME="$TEST_HOME" "$NVIM" install 2>/dev/null || die "install wrote into an existing directory"

echo "neovim checks passed."
