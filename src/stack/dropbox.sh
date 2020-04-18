#!/bin/bash
# A bash script to install and sync dropbox

# Set dropbox home
dropbox_home=/home/$USER/dropbox

log "Creating dropbox home folder $dropbox_home."

mkdir -p $dropbox_home

log "Installing the latest verion of dropbox."

dropbox_list=/etc/apt/sources.list.d/dropbox.list
sudo touch $dropbox_list
sudo echo "deb [arch=i386,amd64] http://linux.dropbox.com/ubuntu $(lsb_release -cs) main" | sudo tee -a $dropbox_list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1C61A2656FB57B7E4DE0F4C1FC918B335044912E

sudo apt update
sudo apt install python3-gpg dropbox

info "Dropbox has been installed successfully.\n"

log "Starting the dropbox and sync daemon."

dropbox start -i &>/dev/null

# Prevent process to jump to the next step before dropbox has been synced
while true; do
  output=$(dropbox status | sed -n 1p)
  echo -ne "$output                                   \r"

  if [[ $output == "Up to date" ]]; then
    info "Dropbox files have been synced to $dropbox_home."
    break
  fi
done

info "Sync has been completed successfully.\n"
