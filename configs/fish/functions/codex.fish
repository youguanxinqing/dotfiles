# 普通目录没有项目级 Codex 配置；只对这种目录给当前进程传 untrusted，
# 免掉提示但不加载项目内容，也不改 ~/.codex/config.toml。只要 root 到当前目录之间
# 出现 .codex，就交回 Codex 让用户自己决定是否启用其配置、hooks 和 rules。
function codex
    set -l cwd (pwd -P)
    set -l root (command git rev-parse --show-toplevel 2>/dev/null; or echo $cwd)
    set -l dir $cwd
    set -l trust_args

    # --cd 会改变真正的项目根；奇异路径也不适合拼进 TOML key。
    if not contains -- -C $argv; and not contains -- --cd $argv
        and not string match -qr '^(-C.+|--cd=)' -- $argv
        and not string match -qr '[\\"\r\n]' -- $root
        while not test -e "$dir/.codex"
            if test "$dir" = "$root"
                set trust_args -c "projects.\"$root\".trust_level=\"untrusted\""
                break
            end
            set -l parent (path dirname "$dir")
            test "$parent" = "$dir"; and break
            set dir $parent
        end
    end

    command codex $trust_args $argv
end
