# install.sh publishes repository commands into ~/.local/bin, so PATH does not
# depend on where the dotfiles repository was cloned.
fish_add_path --global --move --path \
  "$HOME/.local/bin" \
  "$HOME/.fzf/bin" \
  "$HOME/go/bin" \
  "$HOME/.cargo/bin" \
  "$HOME/.local/share/fnm"
