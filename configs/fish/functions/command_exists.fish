function command_exists
    if command -q $argv[1]
      echo "true"
    else
      echo "false"
    end
end
