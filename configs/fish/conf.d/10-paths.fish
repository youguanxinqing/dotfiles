# Repository commands and user-installed static CLIs share one stable entry
# point. Version-manager paths remain dynamic and are initialized separately.
# Nowledge previously added this same entry to Fish's universal state. Remove
# only that exact legacy value and preserve every unrelated user path.
if set -qU fish_user_paths; and contains -- "$HOME/.local/bin" $fish_user_paths
    set -l retained_user_paths
    for user_path in $fish_user_paths
        if test "$user_path" != "$HOME/.local/bin"
            set -a retained_user_paths "$user_path"
        end
    end
    set -U fish_user_paths $retained_user_paths
end

fish_add_path --global --move --path "$HOME/.local/bin"
