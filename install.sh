#!/usr/bin/env bash

clear

echo "Stack v0.0.1"
echo -e "Starting installation process...\n"

if [[ "$(id -u)" != "0" ]]; then
  echo "Error: script must be run as root"
  echo "Process exiting with code 1"
  exit 1
fi

if [[ ! -e /etc/arch-release ]]; then
  echo "Error: script must be run in an archiso only"
  echo "Process exiting with code 1"
  exit 1
fi

bash scripts/askme.sh &&
  bash scripts/bootstrap.sh &&
  bash scripts/diskpart.sh &&
  bash scripts/base.sh &&
  arch-chroot /mnt /usr/bin/runuser -u $username -- /scripts/stack.sh &&
    echo "Unmounting all partitions under '/mnt'..." &&
    umount -R /mnt || echo "Ignoring any busy mounted points..." &&
    echo "Rebooting the system in 15 secs (ctrl-c to skip)..." &&
    sleep 15 &&
    reboot
