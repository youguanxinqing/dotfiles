#!/usr/bin/env bash
#
# nvim 的配置不在这个仓库里：它是自己的 repo（NvChad fork，有自己的历史、LICENSE
# 和 remote），复制进来就是把两条历史揉成一条。但"新机器上 nvim 能用"必须由这里
# 保证 —— 只声明 nvim 二进制的话，新机器第一次起来是一份 NvChad 模板，一个插件都
# 没有，herdr-nvim 的 <leader>a* 全是死键，而且不报错，只是不响应。
# 所以走 script installer：把那个仓库 clone 到 ~/.config/nvim。
#
# 用 SSH 不用 HTTPS：这个 dotfiles 仓库自己就是 git@github.com: 拉下来的，能跑到
# 这一步说明 SSH 已经通了。HTTPS clone 出来的 remote 推不上去，而这是个天天在改的
# 配置仓库 —— 给一个推不动的 remote 比当场 clone 失败更坏，后者至少会喊。

set -euo pipefail

# 变量只为测试留的口子：test.sh 拿一个本地仓库当上游，不碰网络。
REPO="${DOTFILES_NVIM_REPO:-git@github.com:youguanxinqing/nvim.git}"
TARGET="$HOME/.config/nvim"

# 比对 remote 而不是只看"这儿有没有个 git 仓库"：别人的 nvim 配置也满足后者，
# 那样 check 会在一台其实没有这份配置的机器上变绿。代价是改了仓库地址之后
# check 会红，改这里的 REPO 即可。
is_our_clone() {
  [[ -d "$TARGET/.git" ]] || return 1
  [[ "$(git -C "$TARGET" remote get-url origin 2>/dev/null)" == "$REPO" ]]
}

case "${1:-}" in
  check)
    is_our_clone || exit 1
    [[ -f "$TARGET/init.lua" ]] || exit 1
    ;;
  install)
    if is_our_clone; then
      echo "Already cloned: $TARGET"
      exit 0
    fi
    # 目录在但不是这个仓库：可能是手写的配置，可能是别的 fork，里面还可能有没提交
    # 的改动。不覆盖、不备份、不重命名 —— 报出来让人自己决定。
    if [[ -e "$TARGET" ]]; then
      echo "Refusing to replace unmanaged path: $TARGET" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$TARGET")"
    git clone "$REPO" "$TARGET"
    echo "Cloned nvim config: $TARGET"
    # 插件不在这里装。init.lua 首次启动自己 bootstrap lazy 并拉全部插件，那是那份
    # 配置的设计；在这儿 headless sync 一遍只是把同样的事提前，代价是 install.sh
    # 多等几分钟网络。要提前就自己跑：nvim --headless "+Lazy! sync" +qa
    ;;
  clean)
    # 不删。这是个有自己 remote 的仓库，可能有没推的提交 —— 删掉它不是清理，是销毁。
    # 真要换掉自己 rm，和 sublime-text 不卸载编辑器本体是同一条线。
    if [[ -e "$TARGET" ]]; then
      echo "Leaving the nvim config in place: $TARGET"
    else
      echo "Already clean: $TARGET"
    fi
    ;;
  *)
    echo "Usage: $0 check|install|clean" >&2
    exit 2
    ;;
esac
