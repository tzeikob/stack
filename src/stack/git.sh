#!/bin/bash
# A bash script to install git

log "Installing the git."

ppa="git-core/ppa"

if ! grep -q "^deb .*$ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
 sudo add-apt-repository ppa:$ppa
 sudo apt update
fi

sudo apt install git

read -p "Enter your git username:($USER) " username

if [[ $username == "" ]]; then
 username = $USER
fi

git config --global user.name "$username"

log "Git username has been set to $(git config --global user.name)."

read -p "Enter your git email:($USER@$HOSTNAME) " email

if [[ $email == "" ]]; then
 email = $USER@$HOSTNAME
fi

git config --global user.email "$email"

log "Git email has been set to $(git config --global user.email)."

info "Git has been installed successfully.\n"
