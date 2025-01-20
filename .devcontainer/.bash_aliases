alias gitlog='git --no-pager log --graph --oneline --remotes -n20'
alias gitpush='git push -u origin HEAD'
alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias .....='cd ../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'
alias tfp='terraform workspace list && terraform plan -lock=false'
alias tfa='terraform workspace list && terraform apply'
alias tfaa='terraform workspace list && terraform apply --auto-approve'
alias tfi='terraform init'
alias tfw='terraform workspace'
alias tf='terraform'
alias tfws='terraform workspace select'
alias tff='terraform fmt'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias fixdocker='sudo chmod 666 /var/run/docker.sock'
