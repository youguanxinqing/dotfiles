# extend ssh commmand
function ssh
  switch $argv[1]
    case ls # ssh ls:  list all remotes
      grep ^Host ~/.ssh/config | grep -v '*' | awk "{print \$2 \"\t\" \$4}" 
      return
    case '*'
      command ssh $argv
  end
end
