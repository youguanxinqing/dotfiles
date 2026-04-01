function __om_find_procfile_root --description "Find nearest parent dir containing Procfile within current git repo"
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    or return 1

    # 用 git 自身的路径构建当前目录，避免 macOS 大小写不一致
    set -l prefix (git rev-parse --show-prefix 2>/dev/null)
    set -l dir (string replace -r '/$' '' "$git_root/$prefix")

    while true
        if test -f "$dir/Procfile"
            echo "$dir"
            return 0
        end

        if test "$dir" = "$git_root"
            break
        end

        set dir (dirname "$dir")
    end

    return 1
end


function o --description "Run overmind from nearest parent dir containing Procfile"
    # 如果用户显式指定了 Procfile，就直接尊重它
    if set -q OVERMIND_PROCFILE
        command overmind $argv
        return $status
    end

    # 如果什么参数都没有, 就执行 overmind -h
    if test (count $argv) -eq 0
        command overmind -h
        return $status
    end

    # 如果执行 o -h, 也需要执行 overmind -h
    if contains -- -h $argv; or contains -- --help $argv
        command overmind -h
        return $status
    end

    set -l root (__om_find_procfile_root)
    if test $status -ne 0
        echo "o: no Procfile found in current directory or parent directories within this git repo" >&2
        return 1
    end

    set -l old_pwd (pwd)
    cd "$root"
    or begin
        echo "o: failed to cd into $root" >&2
        return 1
    end

    # 直接连接当前终端，保留 overmind 自己的实时输出和交互行为
    command overmind $argv
    set -l rc $status

    cd "$old_pwd" >/dev/null 2>/dev/null
    return $rc
end
