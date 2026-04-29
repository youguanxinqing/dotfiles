function fc --description "Edit last command in nvim, then execute it (bash fc)"
    set -l mode default
    for a in $argv
        switch $a
            case -l --list
                set mode list
            case -h --help
                echo "Usage: fc          edit previous command in nvim, then run"
                echo "       fc -l       pick a command from history via fzf, then edit & run"
                return 0
            case '*'
                echo "fc: unknown argument: $a" >&2
                return 2
        end
    end

    set -l last_cmd

    if test $mode = list
        if not type -q fzf
            echo "fc: fzf not found in PATH" >&2
            return 1
        end

        # 流式过滤 NUL 分隔的历史: 跳过 fc 自身, 多行命令保留内部换行,
        # 再交给 fzf --read0 让它按行自然展开多行项.
        # string collect 防止命令替换把多行选中再次拆成数组.
        set -l selected (history --null \
            | while read --null e
                if test -n "$e"; and not string match -rq '^\s*fc(\s|$)' -- "$e"
                    printf '%s\0' $e
                end
            end \
            | fzf --read0 --no-sort --tiebreak=index --prompt='fc> ' \
            | string collect)

        if test -z "$selected"
            return 130
        end
        set last_cmd $selected
    else
        # 默认分支: 优先用上次 fc 编辑后的命令, 实现链式接力编辑
        # (fish 的 eval 不会写入 history, 所以必须自己缓存)
        if set -q __fc_last_run; and test -n "$__fc_last_run"
            set last_cmd $__fc_last_run
        else
            for entry in (history --max=20)
                if test -n "$entry"; and not string match -rq '^\s*fc(\s|$)' -- "$entry"
                    set last_cmd $entry
                    break
                end
            end
        end
    end

    if test -z "$last_cmd"
        echo "fc: no command found" >&2
        return 1
    end

    set -l tmpdir (mktemp -d)
    or begin
        echo "fc: failed to create temp dir" >&2
        return 1
    end
    set -l tmpfile "$tmpdir/last-command.fish"

    printf '%s\n' "$last_cmd" >$tmpfile

    nvim $tmpfile
    set -l rc $status

    if test $rc -ne 0
        rm -rf $tmpdir
        echo "fc: editor exited with status $rc, aborting" >&2
        return $rc
    end

    # 注意: string collect 必须是最后一步, 否则 string trim 输出会按行
    # 重新被命令替换拆成数组, 多行命令的换行就丢了
    set -l edited (cat $tmpfile | string collect)
    rm -rf $tmpdir

    if test -z "$edited"
        return 0
    end

    # 记下这次 edited, 让紧跟的下一次 fc 在它基础上继续改
    set -g __fc_last_run "$edited"

    echo "$edited"
    eval $edited
end

# 跑了任何非 fc 的命令就让缓存失效, fc 回退到从 history 取
function __fc_invalidate --on-event fish_postexec
    if not string match -rq '^\s*fc(\s|$)' -- "$argv[1]"
        set -e __fc_last_run
    end
end
