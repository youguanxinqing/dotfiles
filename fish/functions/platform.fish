
# get_my_platform
# probably returns: windows, linux, darwin, unknown
function get_my_platform

  if test (uname) = "Darwin"
    echo "darwin"
  else if test (uname) = "Linux"
    # windows or linux
    if string match -q "*Microsoft*" (cat /proc/version)
      echo "windows"
    else
      echo "linux"
    end
  else
    echo "unknown"
  end

end

function is_wsl2
  if test (uname) = "Linux"
    if string match -q "*WSL2*" (cat /proc/version)
      echo "true"
      return
    end
  end
  
  echo "false"
end

function command_exists
    if command -q $argv[1]
      echo "true"
    else
      echo "false"
    end
end