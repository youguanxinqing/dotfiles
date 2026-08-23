# Machine-local overrides stay outside the repository.
set -l local_config "$HOME/.config/fish/local.d/local.fish"
if test -r "$local_config"
    source "$local_config"
end
