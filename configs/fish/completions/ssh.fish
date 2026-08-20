complete -c ssh -f

# Format MUST be:
# Host host-name # desc
complete -c ssh -a '(grep ^Host ~/.ssh/config | grep -v \'*\' | awk "{print \$2 \"\t\" \$4}" )' -d "remote host"

