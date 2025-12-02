function cargo
  if set -q __cargo_done
    command cargo $argv
  else
    source "$HOME/.cargo/env.fish"
    set -g __cargo_done 1
    command cargo $argv
  end
end
