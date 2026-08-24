# Homebrew's rustup formula is keg-only. Its opt link is stable across upgrades
# and contains the rustup proxies for cargo, rustc, rustfmt, and related tools.
if set -q HOMEBREW_PREFIX
    fish_add_path --global --move --path "$HOMEBREW_PREFIX/opt/rustup/bin"
end

# fnm creates a per-shell path for the selected Node version. Do not export a
# multishell path from non-interactive desktop/login environment probes.
if status is-interactive; and type -q fnm
    fnm env --shell fish | source
end

# goup's environment supports both the default Go toolchain and session-local
# selection, so it cannot be replaced by a fixed go/gofmt symlink.
if test -r "$HOME/.goup/env"
    source "$HOME/.goup/env"
    set -e GOROOT
    # goup's env script registers its directories in fish_user_paths, which Fish
    # keeps behind everything appended to $PATH from here. Homebrew's go — pulled
    # in as a dependency of gopls, goimports and staticcheck — would then win and
    # defeat goup's version selection, so move goup ahead explicitly.
    fish_add_path --global --move --path "$HOME/.goup/bin" "$HOME/.goup/current/bin"
end
