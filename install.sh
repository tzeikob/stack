#!/usr/bin/env bash

set -a
HOME="$(cd $(dirname "$(test -L "$0" && readlink "$0" || echo "$0")") && pwd)"
OPTIONS="$HOME/.options"
set +a

if [ "$(id -u)" != "0" ]; then
  echo "Error: script must be run as root"
  echo "Process exiting with code 1"
  exit 1
fi

if [ ! -e /etc/arch-release ]; then
  echo "Error: script must be run in an archiso only"
  echo "Process exiting with code 1"
  exit 1
fi

clear

cat << EOF
░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░
░░░▀▀█░░█░░█▀█░█░░░█▀▄░░
░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░
EOF

echo -e "\nWelcome to Stack v1.0.0"
echo "Have your development environment on archlinux"

$HOME/scripts/askme.sh && source $OPTIONS &&
  $HOME/scripts/diskpart.sh &&
  $HOME/scripts/bootstrap.sh &&
  cp -R $HOME /mnt/root &&
  arch-chroot /mnt $HOME/scripts/setup.sh &&
    echo "Unmounting all partitions under '/mnt'..." &&
    (umount -R /mnt || echo "Ignore busy mountings...") &&
    echo "Rebooting the system in 15 secs (ctrl-c to skip)..." &&
    sleep 15 &&
    reboot
