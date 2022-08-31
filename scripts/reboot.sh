#!/usr/bin/env bash

echo -e "\nBooting into the system for the first time..."

echo "Copying all installation files to the new system"

rm -rf /mnt/root/stack
cp -R $HOME /mnt/root/

echo "Installation files have been copied successfully"

umount -R /mnt &&
  echo "Partitions under /mnt have been unmounted" ||
  echo "Ignoring any busy mount points"

echo "Rebooting the system in 15 secs (ctrl-c to skip)..."

sleep 15
reboot
