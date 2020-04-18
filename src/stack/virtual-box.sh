#!/bin/bash
# A bash script to install virtual box

log "Installing the virtual box."

sudo add-apt-repository multiverse

sudo apt update
sudo apt install virtualbox

info "Virtual box has been installed successfully.\n"
