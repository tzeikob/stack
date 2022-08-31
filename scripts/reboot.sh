#!/usr/bin/env bash

echo "Booting into the system for the first time..."

umount -R /mnt &&
  echo "Partitions under /mnt have been unmounted" ||
  echo "Ignoring some busy mount points"

echo -e "\nRebooting the system in 15 secs (ctrl-c to skip)..."

sleep 15
reboot
