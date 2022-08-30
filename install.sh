#!/usr/bin/env bash

set -a
HOME="$(cd $(dirname "$(test -L "$0" && readlink "$0" || echo "$0")") && pwd)"
OPTIONS="$HOME/.options"
LOG="$HOME/all.log"
set +a

run () {
  local SCRIPT=$1
  local USER=$2

  if [ -z "$USER" ]; then
    bash $HOME/scripts/${SCRIPT}.sh 2>&1 | tee -a $LOG
  elif [ "$USER" = "root" ]; then
    arch-chroot /mnt $HOME/scripts/${SCRIPT}.sh 2>&1 | tee -a $LOG
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

clear

cat << EOF
░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░
░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░
░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░
EOF

echo -e "\nWelcome to Stack v1.0.0"
echo -e "Have your development environment on archlinux\n"

echo "Let's start by configuring your system"
read -p "Do you want to proceed? [Y/n] " REPLY
REPLY="${REPLY:-"yes"}"
REPLY="${REPLY,,}"

if [[ ! "$REPLY" =~ ^(y|yes)$ ]]; then
  echo "Exiting stack installation..."
  exit 0
fi

echo

run "askme" &&
  run "diskpart" &&
  run "bootstrap" &&
  run "setup" "root" &&
  reboot
