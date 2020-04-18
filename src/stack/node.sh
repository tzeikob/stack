#!/bin/bash
# A bash script to install node via nvm

log "Installing node via nvm."

bash /home/$USER/dropbox/stack/node/nvm.sh

source ~/.bashrc
source /home/$USER/.nvm/nvm.sh

nvm install --lts
nvm install node
nvm use --lts

log "Currently installed node versions:"
nvm ls

info "Node has been installed successfully in /home/$USER/.nvm/versions/node.\n"
