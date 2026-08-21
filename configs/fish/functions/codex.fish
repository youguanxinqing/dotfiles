# 免掉每进一个新目录就弹一次的 "Do you trust this directory?"。
#
# codex 的信任表是 ~/.codex/config.toml 里的 [projects."<path>"]，按 git repo
# root 精确匹配 —— 不向上继承，所以信任 ~ 或 ~/Projects 都没用，只能逐 root 登记。
# --sandbox / --ask-for-approval 也绕不过去（0.149.0 实测）。这里就在启动前
# 把当前 root 补进去，等价于每次手动按 "1. Yes"。
function codex
    set -l root (command git rev-parse --show-toplevel 2>/dev/null; or pwd)
    set -l home (set -q CODEX_HOME; and echo $CODEX_HOME; or echo ~/.codex)
    set -l conf $home/config.toml

    # 路径带引号会写出坏掉的 TOML，让 codex 整个起不来，这种就交回给它自己问
    if test -f $conf; and not string match -q '*"*' -- $root
        if not grep -qF "[projects.\"$root\"]" $conf
            printf '\n[projects."%s"]\ntrust_level = "trusted"\n' $root >>$conf
        end
    end

    command codex $argv
end
