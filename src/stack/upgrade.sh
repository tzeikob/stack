#!/bin/bash
# A bash script to install system upgrades and dependencies

# Upgrade the system dependencies
log "Upgrading the base system with the latest updates."

sudo apt update
sudo apt upgrade

# Remove not used packages
log "Removing any not used packages."

sudo apt autoremove

# Install third-party dependencies
packages=(tree curl unzip htop gconf-service gconf-service-backend gconf2
          gconf2-common libappindicator1 libgconf-2-4 libindicator7
          libpython-stdlib python python-minimal python2.7 python2.7-minimal libatomic1
          gimp vlc)

log "Installing third-party software dependencies."

sudo apt install ${packages[@]}

info "System has been updated successfully.\n"
