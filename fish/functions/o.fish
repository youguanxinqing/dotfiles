function __om_find_procfile_root --description "Find nearest parent dir containing Procfile within current git repo"
    set -l start_dir (pwd)

    # 当前目录如果都不在 git 仓库里，直接失败
    git -C "$start_dir" rev-parse --show-toplevel >/dev/null 2>/dev/null
    or return 1

    set -l git_root (git -C "$start_dir" rev-parse --show-toplevel 2>/dev/null)
    test -n "$git_root"
    or return 1

    set -l dir "$start_dir"

    while true
        # 只在同一个 git 仓库范围内向上找
        if test "$dir" != "$git_root"
            string match -q "$git_root*" "$dir"
            or return 1
        end

        if test -f "$dir/Procfile"
            echo "$dir"
            return 0
        end

        if test "$dir" = "$git_root"
            break
        end

        set -l parent (dirname "$dir")
        if test "$parent" = "$dir"
            break
        end
        set dir "$parent"
    end

    return 1
end


function o --description "Run overmind from nearest parent dir containing Procfile"
    # 如果用户显式指定了 Procfile，就直接尊重它
    if set -q OVERMIND_PROCFILE
        command overmind $argv
        return $status
    end

    set -l root (__om_find_procfile_root)
    if test $status -ne 0
        echo "om: no Procfile found in current directory or parent directories within this git repo" >&2
        return 1
    end

    set -l old_pwd (pwd)
    cd "$root"
    or begin
        echo "om: failed to cd into $root" >&2
        return 1
    end

    command overmind $argv
    set -l rc $status

    cd "$old_pwd" >/dev/null 2>/dev/null
    return $rc
end
