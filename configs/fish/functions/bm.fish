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

    # 布局唯一事实源：~/.config/tmuxinator/dev.yml。
    # 需要 bootmux >= 0.3.0：herdr 归属键含渲染后的项目名，
    # 多个 worktree 才能共用同一份配置。
    if test "$argv[1]" = stop
        bootmux stop dev root=$root session=$session $argv[2..]
    else
        bootmux start dev root=$root session=$session $argv
    end
end
