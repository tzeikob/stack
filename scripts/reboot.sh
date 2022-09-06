#!/usr/bin/env bash

clean_up () {
  echo "Cleaning up installation files..."

  rm -rf /mnt/root/stack "/mnt/home/$USERNAME/stack"
  cp $LOG "/mnt/home/$USERNAME/stack.log"

  echo "Log file has been saved to /home/$USERNAME/stack.log"

  echo "System has been cleaned up"
}

unmount () {
  umount -R /mnt &&
    echo "Partitions under /mnt have been unmounted" ||
    echo "Ignoring any busy mount points"
}

restart () {
  echo "Rebooting the system in 15 secs (ctrl-c to skip)..."

  sleep 15
  reboot
}

echo -e "\nBooting into the system for the first time..."

source $OPTIONS

clean_up &&
  unmount &&
  restart
