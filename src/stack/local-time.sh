#!/bin/bash
# A bash script to set the local RTC time

log "Setting the system to use local time instead of UTC."

timedatectl set-local-rtc 1 --adjust-system-clock
gsettings set org.gnome.desktop.interface clock-show-date true

info "System has been set to use local time successfully.\n"
