function __dotfiles_number_fzf_history
    set -l index 1

    while read -lz entry
        printf '%d\t%s\0' $index "$entry"
        set index (math $index + 1)
    end
end

function fzf-history-widget -d 'Show command history with classic sequence numbers'
    set -l command_line (commandline)
    set -l current_line (commandline -L)
    set -l total_lines (count $command_line)
    set -l fzf_query (string escape -- $command_line[$current_line])

    set -lx FZF_DEFAULT_OPTS (__fzf_defaults '' \
        '--nth=2.. --scheme=history --no-multi --no-multi-line' \
        '--no-wrap --wrap-sign="\t↳ " --highlight-line' \
        "--bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS" \
        '--accept-nth=2.. --delimiter="\t" --tabstop=4 --read0 --print0')
    set -lx FZF_DEFAULT_OPTS_FILE

    # Match fzf's classic Fish integration: number the history from oldest to
    # newest, then reverse the picker so recent commands appear first.
    test -z "$fish_private_mode"; and builtin history merge
    if set -l result (builtin history -z --reverse \
            | __dotfiles_number_fzf_history \
            | eval (__fzfcmd) --tac --query=$fzf_query \
            | string split0)
        if test "$total_lines" -eq 1
            commandline -- $result
        else
            set -l before (math $current_line - 1)
            set -l after (math $current_line + 1)
            commandline -- $command_line[1..$before] $result
            commandline -a -- '' $command_line[$after..-1]
        end
    end

    commandline -f repaint
end
