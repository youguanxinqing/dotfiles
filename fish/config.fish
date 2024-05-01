if status is-interactive
    # Commands to run in interactive sessions can go here
end

function fish_right_prompt
  echo "<<< "
  date "+%y-%m-%d %H:%M:%S"
end

function fish_prompt
  echo -n -s (set_color red) '@'(whoami) ' '\
    (set_color yellow) (prompt_pwd) \
    (set_color yellow) (fish_git_prompt) '$ '
end

source ~/.config/fish/conf.d/alias.fish
source ~/.config/fish/conf.d/cdpath.fish
source ~/.config/fish/conf.d/dev.fish

fish_user_key_bindings

