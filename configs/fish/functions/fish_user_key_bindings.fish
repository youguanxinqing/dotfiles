function fish_user_key_bindings
    # fzf's Fish integration installs the default Ctrl-R history and Ctrl-T
    # file widgets (plus Alt-C). Fish invokes this function after its preset
    # bindings are ready, so the fzf bindings win without double-loading them.
    type -q fzf; or return
    fzf --fish | source

    # Recent fzf releases replaced the classic command sequence with
    # timestamps. Restore the earlier official Fish presentation while keeping
    # Ctrl-T and Alt-C from the installed version.
    set -gx FZF_CTRL_R_OPTS '--with-nth=1..'
    source "$__fish_config_dir/functions/fzf-history-widget.fish"
end
