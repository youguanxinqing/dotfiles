#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/testlib.sh
source "${DOTFILES_TEST_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}/scripts/tests/testlib.sh"
new_test_root

BIN="$ROOT/bin/herdr-worktree"
STUB="$TEST_ROOT/stub"
LOG="$TEST_ROOT/calls.log"
NEWWT="$TEST_ROOT/newwt"
HERDR_TEST_PATH="$STUB:$(dirname -- "$(command -v git)"):$(dirname -- "$(command -v jq)"):$TEST_SYSTEM_PATH"
mkdir -p "$STUB" "$NEWWT" "$TEST_ROOT/parent/x" "$TEST_ROOT/parent/y" "$TEST_ROOT/other/z"
: >"$LOG"

# 主 checkout + 一个真 remote：起点解析和 fetch 都走真 git，只有 herdr 和 bm 是 stub。
REMOTE="$TEST_ROOT/remote.git"
MAIN="$TEST_ROOT/main"
git -c init.defaultBranch=master init -q --bare "$REMOTE"
git -c init.defaultBranch=master init -q "$MAIN"
git -C "$MAIN" -c user.email=t@t -c user.name=t commit -q --allow-empty -m first
git -C "$MAIN" remote add origin "$REMOTE"
git -C "$MAIN" push -q origin master
git -C "$MAIN" remote set-head origin -a >/dev/null 2>&1

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'echo "herdr $*" >> "$STUB_LOG"' \
  'case "$1 $2" in' \
  '  "worktree list")' \
  '    printf "{\"result\":{\"worktrees\":[" ' \
  '    printf "{\"branch\":\"main\",\"path\":\"%s\",\"is_linked_worktree\":false}," "$STUB_ROOT/main"' \
  '    printf "{\"branch\":\"x\",\"path\":\"%s/parent/x\",\"is_linked_worktree\":true}," "$STUB_ROOT"' \
  '    printf "{\"branch\":\"y\",\"path\":\"%s/parent/y\",\"is_linked_worktree\":true}," "$STUB_ROOT"' \
  '    printf "{\"branch\":\"z\",\"path\":\"%s/other/z\",\"is_linked_worktree\":true,\"open_workspace_id\":\"W9\"}" "$STUB_ROOT"' \
  '    printf "]}}"' \
  '    ;;' \
  '  "worktree create")' \
  '    printf "{\"result\":{\"workspace\":{\"workspace_id\":\"W1\",\"active_tab_id\":\"W1:t1\"},\"worktree\":{\"path\":\"%s\"}}}" "$STUB_ROOT/newwt"' \
  '    ;;' \
  '  "worktree open")' \
  '    printf "{\"result\":{\"already_open\":true}}"' \
  '    ;;' \
  '  "tab list") printf "{\"result\":{\"tabs\":[{\"tab_id\":\"a\"},{\"tab_id\":\"b\"}]}}" ;;' \
  '  *) ;;' \
  'esac' >"$STUB/herdr"

# bm 是 fish function，所以脚本走 fish -c —— stub 把关键的三样记下来：
# 目标 workspace、传给 bm 的参数、以及运行时的 cwd（bm 靠它推 root/session）。
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'echo "fish ws=${HERDR_WORKSPACE_ID:-none} cwd=$PWD args=$*" >> "$STUB_LOG"' >"$STUB/fish"

printf '%s\n' '#!/usr/bin/env bash' 'echo "smart-tab ws=${HERDR_ACTIVE_WORKSPACE_ID:-none} $*" >> "$STUB_LOG"' >"$STUB/herdr-smart-tab"
chmod +x "$STUB"/*

run() {
  PATH="$HERDR_TEST_PATH" STUB_LOG="$LOG" STUB_ROOT="$TEST_ROOT" \
    HERDR_BIN_PATH="$STUB/herdr" HERDR_ACTIVE_PANE_CWD="${RUN_CWD:-$MAIN}" "$BIN" "$@"
}

# 远端在克隆之后又往前走了一格：不 fetch 的话 origin/master 还停在旧 commit，
# --base 就会照着旧 commit 开分支 —— 这正是 herdr 自己不做、脚本必须补的一步。
git -C "$MAIN" -c user.email=t@t -c user.name=t commit -q --allow-empty -m second
git -C "$MAIN" push -q origin master
git -C "$MAIN" update-ref refs/remotes/origin/master HEAD~1
[[ $(git -C "$MAIN" rev-parse origin/master) != $(git -C "$MAIN" rev-parse master) ]] ||
  die "the fixture failed to leave origin/master behind master"

# 建站位置由清单说，不再从现有 worktree 的分布反推。
printf 'worktree_dir %s\n' "$TEST_ROOT/wts" >"$MAIN/.worktree-links"
run create feature-x >/dev/null
calls="$(<"$LOG")"

assert_contains "$calls" "--path $TEST_ROOT/wts/feature-x"
assert_contains "$calls" '--branch feature-x'
assert_contains "$calls" "--cwd $MAIN"
assert_contains "$calls" '--base origin/master'
[[ $(git -C "$MAIN" rev-parse origin/master) == $(git -C "$MAIN" rev-parse master) ]] ||
  die "herdr-worktree did not fetch before branching off origin/master"

# 布局必须贴到 herdr 刚建的那个 workspace 上：不显式给 HERDR_WORKSPACE_ID，
# bootmux --append 会静默贴到当前聚焦的 workspace 去（实测踩过）。
assert_contains "$calls" "fish ws=W1 cwd=$NEWWT args=-c bm --append --no-attach"
# 布局贴上后 herdr 自带的那个光 shell tab 要收掉，再按仓库约定重编号。
assert_contains "$calls" 'herdr tab close W1:t1'
# 只给新 workspace 重编号：renumber-all 会遍历所有 workspace，实测 2.5s。
assert_contains "$calls" 'smart-tab ws=W1 renumber-positions'
if [[ "$calls" == *'renumber-all'* ]]; then
  echo "herdr-worktree renumbered every workspace instead of the new one." >&2
  exit 1
fi

# 相对路径是相对主 checkout 的，而且故意不展平：git worktree add 存的是解析过的
# 绝对路径，展平这一步没人需要。
: >"$LOG"
printf 'worktree_dir ../wts\n' >"$MAIN/.worktree-links"
run create rel-x >/dev/null
assert_contains "$(<"$LOG")" "--path $MAIN/../wts/rel-x"

# 没有清单就不传 --path，交给 herdr 的默认目录。stub 的列表里 parent/ 底下有两个
# worktree，所以这条同时是「众数那套逻辑没有回来」的回归测试。
: >"$LOG"
rm "$MAIN/.worktree-links"
run create no-manifest >/dev/null
calls="$(<"$LOG")"
assert_contains "$calls" '--branch no-manifest'
if [[ "$calls" == *'--path'* ]]; then
  echo "herdr-worktree invented a worktree path with no manifest to say where." >&2
  exit 1
fi

# 已经开着的 worktree 只 focus，不再贴一遍布局。
: >"$LOG"
run open z >/dev/null
calls="$(<"$LOG")"
assert_contains "$calls" "worktree open --cwd $MAIN --path $TEST_ROOT/other/z --focus"
if [[ "$calls" == *'fish ws='* ]]; then
  echo "herdr-worktree re-applied the layout to an already-open worktree." >&2
  exit 1
fi

# 不存在的分支要报错，不能静默建一个新的。
: >"$LOG"
if run open nope >/dev/null 2>&1; then
  echo "herdr-worktree opened a branch that has no worktree." >&2
  exit 1
fi
if [[ "$(<"$LOG")" == *'worktree create'* ]]; then
  echo "herdr-worktree created a worktree while asked to open one." >&2
  exit 1
fi

# 用法错误走 2，和仓库里其他脚本一致。
for bad in create bogus; do
  status=0
  run "$bad" >/dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] || die "herdr-worktree exited $status instead of 2 on '$bad'"
done

# fzf 的 change:reload 分支：缓存行原样透传，末尾 create 行跟着当前输入走。
printf 'x\t~/parent/x\t0\n' >"$TEST_ROOT/cache"
out="$("$BIN" __list "$TEST_ROOT/cache" 'my/branch')"
assert_contains "$out" 'my/branch'
assert_contains "$out" '__create__'
[[ $(printf '%s\n' "$out" | wc -l) -eq 2 ]] ||
  die "__list emitted more than the cached row plus the create row"
out="$("$BIN" __list "$TEST_ROOT/cache" '')"
assert_contains "$out" '+ create (auto)'

# 缓存不在时 __list 得自己把列表算出来：fzf 的 change:reload 会掐掉正在算的那个
# 进程，所以「缓存没写成」是常态而不是错误分支。算完还要落盘给后续 reload 用。
list() {
  PATH="$HERDR_TEST_PATH" STUB_LOG="$LOG" STUB_ROOT="$TEST_ROOT" \
    HERDR_BIN_PATH="$STUB/herdr" "$BIN" __list "$@"
}
: >"$LOG"
rm -f "$TEST_ROOT/fresh"
out="$(list "$TEST_ROOT/fresh" '' "$MAIN")"
assert_contains "$out" "$TEST_ROOT/parent/x"
assert_contains "$out" '__create__'
assert_contains "$(<"$TEST_ROOT/fresh")" "$TEST_ROOT/parent/y"

# 缓存在了就读缓存，不再打一次 herdr —— 每个按键都触发 reload，这条不能退化。
: >"$LOG"
out="$(list "$TEST_ROOT/fresh" 'zz' "$MAIN")"
assert_contains "$out" 'zz'
assert_contains "$out" "$TEST_ROOT/parent/x"
if [[ "$(<"$LOG")" == *'worktree list'* ]]; then
  echo "herdr-worktree re-queried herdr on a cache hit." >&2
  exit 1
fi

# 从 linked worktree 里按这个键是常态（人就待在某个 worktree 里），而 herdr 拒绝
# 从 worktree 出发开/建（linked_worktree_source），所以 --cwd 必须换算回主 checkout。
: >"$LOG"
git -C "$MAIN" worktree add -q "$TEST_ROOT/inside" -b inside
RUN_CWD="$TEST_ROOT/inside" run create from-worktree >/dev/null
calls="$(<"$LOG")"
assert_contains "$calls" "--cwd $MAIN"
if [[ "$calls" == *"--cwd $TEST_ROOT/inside"* ]]; then
  echo "herdr-worktree passed a linked worktree as the source repo." >&2
  exit 1
fi

# 主 checkout 是手读 .git 的 gitfile 算出来的（不 exec git），所以从 worktree 的子目录
# 里按键也必须往上找得到 —— 认错形状就会把 --cwd 指到另一个仓库上去。
mkdir -p "$TEST_ROOT/inside/deep/er"
: >"$LOG"
RUN_CWD="$TEST_ROOT/inside/deep/er" run create from-subdir >/dev/null
assert_contains "$(<"$LOG")" "--cwd $MAIN"

# 不在 git 仓库里要报错，而不是拿 $PWD 猜一个仓库出来。
printf 'not a gitdir\n' >"$TEST_ROOT/other/.git"
if PATH="$HERDR_TEST_PATH" STUB_LOG="$LOG" STUB_ROOT="$TEST_ROOT" \
  HERDR_BIN_PATH="$STUB/herdr" HERDR_ACTIVE_PANE_CWD="$TEST_ROOT/other" \
  "$BIN" create anything >/dev/null 2>&1; then
  echo "herdr-worktree accepted a cwd outside any git repository." >&2
  exit 1
fi

# ctrl-d 是删除，所以这条路要有回归测试：列表是起了 fzf 之后才在后台算的，parent 手上
# 没有那份数组，删哪个只能看行里带的 open_workspace_id / 路径。按「重新 load 一遍的第
# N 行」删就会在列表变过之后删错 worktree。
# 对话框要求 stdin/stdout 是终端，用 python3 起一个 pty；没有 python3 就跳过这段。
if command -v python3 >/dev/null 2>&1; then
  # stub fzf 回放 $STUB_ROOT/fzf.out（@ROW3@ 换成收到的第 3 行），第二次当 esc 退出，
  # 否则 dialog 的循环不结束。
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'cat > "$STUB_ROOT/fzf.in"' \
    'n=$(( $(cat "$STUB_ROOT/fzf.n" 2>/dev/null || echo 0) + 1 ))' \
    'echo "$n" > "$STUB_ROOT/fzf.n"' \
    '[ "$n" -eq 1 ] || exit 130' \
    'sed -e "s|@ROW3@|$(sed -n 3p "$STUB_ROOT/fzf.in")|" "$STUB_ROOT/fzf.out"' >"$STUB/fzf"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "PATH=\"$HERDR_TEST_PATH\" STUB_LOG=\"$LOG\" STUB_ROOT=\"$TEST_ROOT\" \\" \
    "  HERDR_BIN_PATH=\"$STUB/herdr\" HERDR_ACTIVE_PANE_CWD=\"$MAIN\" \"$BIN\"" >"$TEST_ROOT/pty.sh"
  chmod +x "$STUB/fzf" "$TEST_ROOT/pty.sh"
  # query / key / 选中行三行齐：ctrl-d 删第 3 行
  printf '\nctrl-d\n@ROW3@\n' >"$TEST_ROOT/fzf.out"
  : >"$LOG"
  rm -f "$TEST_ROOT/fzf.n"
  printf 'y' | python3 -c 'import pty,sys; sys.exit(pty.spawn(sys.argv[1:]))' \
    "$TEST_ROOT/pty.sh" >"$TEST_ROOT/pty.out" 2>&1 || true
  calls="$(<"$LOG")"
  # z 是开着的，得经 herdr 关掉 workspace 再摘，不能直接 git worktree remove。
  assert_contains "$calls" 'worktree remove --workspace W9'
  # 隐藏列必须齐：真路径 + open 的 workspace（--with-nth 1,2 只显示前两列）。
  rowz="$(sed -n 3p "$TEST_ROOT/fzf.in")"
  assert_contains "$rowz" "$TEST_ROOT/other/z"
  assert_contains "$rowz" 'W9'
  # 摘完要回到列表继续，而不是关掉弹窗：第二次 fzf 调用就是这个。
  [[ $(<"$TEST_ROOT/fzf.n") -eq 2 ]] ||
    die "the dialog did not return to the list after ctrl-d"

  # 没有选中行时 fzf 只吐 query（--expect 的 key 行是空的，命令替换又把尾部换行
  # 吃掉），所以输出可能只有一行。纯参数展开切分必须在这种输入下也不误判成选中了
  # 某一行 —— 误判就会去 open 一个空路径，而不是按输入建分支。
  printf 'newbranch\n\n' >"$TEST_ROOT/fzf.out"
  : >"$LOG"
  rm -f "$TEST_ROOT/fzf.n"
  printf 'y' | python3 -c 'import pty,sys; sys.exit(pty.spawn(sys.argv[1:]))' \
    "$TEST_ROOT/pty.sh" >"$TEST_ROOT/pty.out" 2>&1 || true
  calls="$(<"$LOG")"
  assert_contains "$calls" '--branch newbranch'
  if [[ "$calls" == *'worktree open'* ]]; then
    echo "herdr-worktree opened a row when fzf reported no selection." >&2
    exit 1
  fi
fi
