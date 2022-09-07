#!/usr/bin/env bash

set -a
HOME="$(cd $(dirname "$(test -L "$0" && readlink "$0" || echo "$0")") && pwd)"
OPTIONS="$HOME/.options"
LOG="$HOME/all.log"
set +a

run () {
  bash $HOME/scripts/${1}.sh 2>&1 | tee -a $LOG
}

setup () {
  arch-chroot /mnt /root/stack/scripts/${1}.sh 2>&1 | tee -a $LOG
}

install () {
  source $OPTIONS
  arch-chroot /mnt runuser -u $USERNAME -- /home/$USERNAME/stack/scripts/${1}/setup.sh 2>&1 | tee -a $LOG
}

copy () {
  cp -R "${1}" "${2}"
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
  copy "$HOME" "/mnt/root" &&
  setup "system" &&
  install "desktop" &&
  run "reboot"
