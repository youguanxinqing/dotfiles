#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

BIN="$ROOT/bin/worktree-links"

MAIN="$TEST_ROOT/main"
SIBLING="$TEST_ROOT/sibling"
WT="$TEST_ROOT/wt"

# 建站目录先建出来：源不存在时 worktree_dir 会落到「skip 源缺失」那条早退，把
# 「它没被跳过」这个 bug 一起掩盖掉。而真实情况下建站目录一定是存在的（worktree 就
# 摆在里面），那时没跳过就会撞上未知条目分支 —— 退 1 加一条通知。
mkdir -p "$MAIN" "$SIBLING/frontend/node_modules" "$TEST_ROOT/wts"
git -c init.defaultBranch=main init -q "$MAIN"
git -C "$MAIN" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$MAIN" worktree add -q "$WT" -b wt

printf 'layout python\n' >"$MAIN/.envrc"
printf 'name: main\n' >"$MAIN/.tmuxinator.yml"
mkdir -p "$MAIN/.claude/skills/probe" "$MAIN/backend/config/local"
printf 'db: local\n' >"$MAIN/backend/config/local/config.yaml"

cat >"$MAIN/.worktree-links" <<EOF
# 注释和空行都要被跳过

worktree_dir ../wts
dir   volumes/logs
link  .envrc
link  .claude/skills/probe
copy  backend/config/local/config.yaml
copy  .tmuxinator.yml
link  frontend/node_modules $SIBLING
link  never-committed
EOF

out="$("$BIN" "$WT")"
assert_link "$WT/.envrc" "$MAIN/.envrc"
assert_link "$WT/.claude/skills/probe" "$MAIN/.claude/skills/probe"
assert_link "$WT/frontend/node_modules" "$SIBLING/frontend/node_modules"
[[ -d "$WT/volumes/logs" ]] || die "dir did not create volumes/logs"
[[ -f "$WT/backend/config/local/config.yaml" && ! -L "$WT/backend/config/local/config.yaml" ]] ||
  die "copy left a symlink instead of a real file"
assert_contains "$out" 'skip     never-committed'
# worktree_dir 是 herdr-worktree 的建站位置，这个脚本要整行忽略。认成未知条目就是退 1
# （上面那个命令替换在 set -e 下直接失败掉），认成 dir/link 就会在输出里留下痕迹。
[[ "$out" != *'../wts'* ]] || die "worktree_dir was acted on instead of ignored: $out"

# 二次运行是幂等的：同样退出 0，且什么都不重建。
out="$("$BIN" "$WT")"
assert_contains "$out" 'ok       .envrc'
assert_contains "$out" 'ok       .tmuxinator.yml'
assert_link "$WT/.envrc" "$MAIN/.envrc"

# copy 的目标是旧软链时换成真文件 —— 有些工具（tmuxinator）不跟软链走。
rm "$WT/.tmuxinator.yml"
ln -s "$MAIN/.tmuxinator.yml" "$WT/.tmuxinator.yml"
"$BIN" "$WT" >/dev/null
[[ -f "$WT/.tmuxinator.yml" && ! -L "$WT/.tmuxinator.yml" ]] ||
  die "copy did not replace the stale symlink with a real file"

# 源换了位置的旧软链要重新指过去，否则它一直悄悄指着不存在的路径。
MOVED="$TEST_ROOT/moved"
mkdir -p "$MOVED/frontend/node_modules"
sed "s|$SIBLING\$|$MOVED|" "$MAIN/.worktree-links" >"$TEST_ROOT/manifest.new"
mv "$TEST_ROOT/manifest.new" "$MAIN/.worktree-links"
out="$("$BIN" "$WT")"
assert_contains "$out" 'relinked frontend/node_modules'
assert_link "$WT/frontend/node_modules" "$MOVED/frontend/node_modules"

# 目标已经是真文件时不覆盖，而且要以失败退出：静默跳过等于让人自己去发现。
rm "$WT/frontend/node_modules"
printf 'hand written\n' >"$WT/frontend/node_modules"
if out="$("$BIN" "$WT" 2>&1)"; then
  echo "worktree-links overwrote a real file or hid the conflict." >&2
  exit 1
fi
assert_contains "$out" 'blocked  frontend/node_modules'
[[ $(<"$WT/frontend/node_modules") == 'hand written' ]] ||
  die "the hand-written file was overwritten"
rm "$WT/frontend/node_modules"

# 生产路径：路径来自 herdr 的事件 JSON，仓库根仍然由 git 决定。
rm "$WT/.envrc"
event="{\"event\":\"worktree_created\",\"data\":{\"type\":\"worktree_created\",\"worktree\":{\"path\":\"$WT\"}}}"
HERDR_PLUGIN_EVENT_JSON="$event" "$BIN" >/dev/null
assert_link "$WT/.envrc" "$MAIN/.envrc"

# 没有清单的仓库彻底无感 —— 事件会为每个仓库触发，这条是别的项目不受影响的保证。
rm "$MAIN/.worktree-links"
"$BIN" "$WT" >/dev/null

# 不是 worktree 的路径要报错，不能当成「没有清单」静默通过。
if "$BIN" "$TEST_ROOT" >/dev/null 2>&1; then
  echo "worktree-links accepted a path outside any git repository." >&2
  exit 1
fi

# -h 打出来的整份东西本身必须是一份合法清单：`-h > .worktree-links` 就是新仓库的
# 起点，所以每行都得是注释。示例行漏个 # 或者格式说明漂了，要在这里炸出来，而不是
# 等某个仓库粘进去之后才发现。
WT2="$TEST_ROOT/wt2"
git -C "$MAIN" worktree add -q "$WT2" -b wt2
"$BIN" -h >"$MAIN/.worktree-links"
out="$("$BIN" "$WT2")"
[ -z "$out" ] || die "the -h template is not fully commented out: $out"
[[ "$(ls -A "$WT2")" == '.git' ]] || die "the -h template provisioned something"
git -C "$MAIN" worktree remove --force "$WT2"

git -C "$MAIN" worktree remove --force "$WT"
