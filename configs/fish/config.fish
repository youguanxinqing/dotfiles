# System/vendor conf.d files run before config.fish. Omarchy's Fish package
# initializes Starship and its own fzf bindings there, so re-apply the
# repository-owned interactive UI last. Calling the binding function here also
# guarantees that Fish autoloads it before checking for user bindings.
if status is-interactive
    source "$__fish_config_dir/functions/fish_prompt.fish"
    source "$__fish_config_dir/functions/fish_right_prompt.fish"
    fish_user_key_bindings
end

# Machine-local overrides stay outside the repository.
set -l local_config "$HOME/.config/fish/local.d/local.fish"
if test -r "$local_config"
    source "$local_config"
end
