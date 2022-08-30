#!/usr/bin/env bash

set -a
HOME="$(cd $(dirname "$(test -L "$0" && readlink "$0" || echo "$0")") && pwd)"
OPTIONS="$HOME/.options"
set +a

run () {
  local SCRIPT=$1
  local USER=$2

  if [ -z "$USER" ]; then
    bash $HOME/scripts/${SCRIPT}.sh
  elif [ "$USER" = "root" ]; then
    arch-chroot /mnt $HOME/scripts/${SCRIPT}.sh
  else
    echo "TODO: run $SCRIPT as $USER"
  fi
}

reboot () {
  echo "Unmounting all partitions under '/mnt'..."
  umount -R /mnt || echo "Ignore any busy mountings..."

  echo "Rebooting the system in 15 secs (ctrl-c to skip)..."
  sleep 15
  reboot
}

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

run "askme" &&
  run "diskpart" &&
  run "bootstrap" &&
  run "setup" "root" &&
  reboot
