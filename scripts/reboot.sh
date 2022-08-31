#!/usr/bin/env bash

copy_files () {
  echo "Copying all installation files to the new system"

  rm -rf /mnt/root/stack
  cp -R $HOME /mnt/root/

  echo "Installation files have been copied successfully"
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

copy_files &&
  unmount &&
  restart
