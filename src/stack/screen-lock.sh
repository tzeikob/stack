#!/bin/bash
# A bash script to disable screen lock

log "Disabling screen lock."

gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false

info "Screen lock has been disabled successfully.\n"
