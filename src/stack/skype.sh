#!/bin/bash
# A bash script to install skype

log "Downloading the latest version of skype."

wget -q --show-progress -P $temp https://repo.skype.com/latest/skypeforlinux-64.deb

log "Installing skype using deb packaging."

sudo dpkg -i $temp/skypeforlinux-64.deb
rm -rf $temp/skypeforlinux-64.deb

info "Skype has been installed successfully.\n"
