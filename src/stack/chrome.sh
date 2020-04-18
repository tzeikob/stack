#!/bin/bash
# A bash script to install chrome

log "Downloading the latest version of chrome."

wget -q --show-progress -P $temp https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

log "Installing chrome using deb packaging."

sudo dpkg -i $temp/google-chrome-stable_current_amd64.deb
rm -rf $temp/google-chrome-stable_current_amd64.deb

info "Chrome has been installed successfully.\n"
