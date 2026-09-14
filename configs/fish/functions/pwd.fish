function pwd --wraps pwd --description "pwd; with arguments, print each one's absolute path"
    # 无参数或走 -L/-P 这类 flag 时，保持 builtin pwd 的原样行为
    if not set -q argv[1]; or string match -qr '^-' -- $argv[1]
        builtin pwd $argv
        return
    end

    for arg in $argv
        # ponytail: 按 $PWD 拼接再 normalize，而不是 `path resolve`——
        # resolve 会展开符号链接，在 /tmp 这种目录下就跟裸 pwd 的输出对不上了
        switch $arg
            case '/*'
                path normalize -- $arg
            case '*'
                path normalize -- $PWD/$arg
        end
    end
end
