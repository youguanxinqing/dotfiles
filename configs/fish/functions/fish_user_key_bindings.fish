function fish_user_key_bindings
    # fzf's Fish integration installs the default Ctrl-R history and Ctrl-T
    # file widgets (plus Alt-C). Fish invokes this function after its preset
    # bindings are ready, so the fzf bindings win without double-loading them.
    type -q fzf; or return
    fzf --fish | source
end
