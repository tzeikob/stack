#!/usr/bin/env bash

set -Eeo pipefail

revoke () {
  local PERMISSION=$1

  case "$PERMISSION" in
   "nopasswd")
      local RULE="%wheel ALL=(ALL:ALL) NOPASSWD: ALL"
      sed -i "s/^\($RULE\)/# \1/" /mnt/etc/sudoers

      if ! cat /mnt/etc/sudoers | grep -q "^# $RULE"; then
        echo "Error: failed to revoke nopasswd permission from wheel group"
        exit 1
      fi;;
  esac

  echo "Permission $PERMISSION has been revoked"
}

clean_up () {
  echo "Cleaning up the system..."

  rm -rf /mnt/root/stack
  rm -rf "/mnt/home/$USERNAME/stack"

  echo "Installation files have been removed"
  echo "System clean up has been completed"
}

restart () {
  echo "Rebooting the system in 15 secs (ctrl-c to skip)..."

  cp "$LOG" "/mnt/home/$USERNAME/stack.log"
  umount -R /mnt || echo "Ignoring busy mount points"

  sleep 15
  reboot
}

echo -e "\nBooting into the system for the first time..."

source "$OPTIONS"

revoke "nopasswd" &&
  clean_up &&
  restart
