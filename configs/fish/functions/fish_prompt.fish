function fish_prompt
    echo -n -s (set_color red) '@'(whoami) ' ' \
        (set_color yellow) (prompt_pwd) \
        (set_color yellow) (fish_git_prompt) '$ '
end
