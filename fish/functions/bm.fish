function bm --description 'start (or stop) a workspace from the global bootmux layout'
    set -l root (git rev-parse --show-toplevel 2>/dev/null)

    if test $status -ne 0
        echo "Not inside a git repository"
        return 1
    end

    set -l branch (git branch --show-current)

    if test -z "$branch"
        set branch (git rev-parse --short HEAD)
    end

    set -l common (git rev-parse --path-format=absolute --git-common-dir)

    if test (basename "$common") = ".git"
        set repo (basename (dirname "$common"))
    else
        set repo (basename "$root")
    end

    # feature/foo -> feature-foo
    set -l session "$repo-$branch"
    set session (string replace -a "/" "-" "$session")

    # 太长时 repo 前缀缩成首字母 (awesome-backend -> ab)
    if test (string length "$session") -gt 20
        set -l abbr ""
        for w in (string split "-" "$repo")
            set abbr "$abbr"(string sub -l 1 "$w")
        end
        set session (string replace -a "/" "-" "$abbr-$branch")
    end

    # 全局模板是唯一事实源。bootmux 的 herdr 后端按 canonicalize 后的
    # config 路径记 ownership，同一路径同时只允许一个活 workspace，
    # 软链又会被解析回源文件 —— 所以每个 session 物化一份副本，
    # 路径唯一、内容每次从全局模板刷新。
    set -l template ~/.config/tmuxinator/dev.yml
    set -l conf ~/.cache/bootmux-bm/$session.yml
    mkdir -p ~/.cache/bootmux-bm
    cp $template $conf

    if test "$argv[1]" = stop
        bootmux stop -p $conf root=$root session=$session $argv[2..]
    else
        bootmux start -p $conf root=$root session=$session $argv
    end
end
