function is_wsl2
  if test (uname) = "Linux"
    if string match -q "*WSL2*" (cat /proc/version)
      echo "true"
      return
    end
  end
  
  echo "false"
end
