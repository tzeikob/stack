#!/bin/bash
# A bash script to install more system laguages

# Install language packages
log "Installing the greek language packages."

sudo apt install `check-language-support -l el`

# Add languages to the keyboard layout
log "Adding greek layout into the keyboard input sources."

gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'gr')]"

# Set regional back to US
log "Set regional formats back to US."

sudo update-locale LANG=en_US.UTF-8
sudo update-locale LANGUAGE=
sudo update-locale LC_CTYPE="en_US.UTF-8"
sudo update-locale LC_NUMERIC=en_US.UTF-8
sudo update-locale LC_TIME=en_US.UTF-8
sudo update-locale LC_COLLATE="en_US.UTF-8"
sudo update-locale LC_MONETARY=en_US.UTF-8
sudo update-locale LC_MESSAGES="en_US.UTF-8"
sudo update-locale LC_PAPER=en_US.UTF-8
sudo update-locale LC_NAME=en_US.UTF-8
sudo update-locale LC_ADDRESS=en_US.UTF-8
sudo update-locale LC_TELEPHONE=en_US.UTF-8
sudo update-locale LC_MEASUREMENT=en_US.UTF-8
sudo update-locale LC_IDENTIFICATION=en_US.UTF-8
sudo update-locale LC_ALL=
locale

info "System languages have been updated successfully.\n"
