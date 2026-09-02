# dotfiles profile 只装跨机器稳定的偏好；基础 config.toml 继续留给 Codex 写入
# 项目信任、插件和 hook 状态。普通目录没有项目级 Codex 配置；只对这种目录给
# 当前进程传 untrusted，免掉提示但不加载项目内容，也不改基础 config.toml。
# 只要 root 到当前目录之间出现 .codex，就交回 Codex 让用户自己决定是否启用
# 其配置、hooks 和 rules。
function codex
    set -l cwd (pwd -P)
    set -l root (command git rev-parse --show-toplevel 2>/dev/null; or echo $cwd)
    set -l dir $cwd
    set -l profile_args
    set -l trust_args
    set -l profile_supported true
    set -l command_name
    set -l option_takes_value false

    # 这些管理命令不进入 agent runtime，Codex 会拒绝同时传 --profile。
    # 普通 prompt 与 runtime 子命令不在这里列举，因此新能力默认仍能拿到偏好。
    for arg in $argv
        if test "$option_takes_value" = true
            set option_takes_value false
            continue
        end
        switch $arg
            case --
                break
            case -c --config --remote --remote-auth-token-env -i --image -m --model \
                --local-provider -p --profile -s --sandbox -C --cd --add-dir \
                -a --ask-for-approval
                set option_takes_value true
            case '-c*' '-i*' '-m*' '-p*' '-s*' '-C*' '-a*' '--*=*' '-*'
                continue
            case '*'
                set command_name $arg
                break
        end
    end
    if contains -- $command_name agents login logout plugin app-server \
        remote-control app completion update doctor features apply migrate-rollouts cloud \
        exec-server help
        set profile_supported false
    end

    # 显式 -p/--profile 永远优先。profile 尚未安装或 CODEX_HOME 指向别处时，
    # 保持原生 Codex 行为，避免 Fish 配置反过来成为启动前置条件。
    set -l codex_config_home "$HOME/.codex"
    if set -q CODEX_HOME
        set codex_config_home "$CODEX_HOME"
    end
    if not contains -- -p $argv; and not contains -- --profile $argv
        and not string match -qr '^(-p.+|--profile=)' -- $argv
        and test "$profile_supported" = true
        and test -f "$codex_config_home/dotfiles.config.toml"
        set profile_args --profile dotfiles
    end

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

    command codex $profile_args $trust_args $argv
end
