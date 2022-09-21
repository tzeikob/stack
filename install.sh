#!/usr/bin/env bash

set -a
HOME="$(cd $(dirname "$(test -L "$0" && readlink "$0" || echo "$0")") && pwd)"
OPTIONS="$HOME/.options"
LOG="$HOME/all.log"
set +a

run () {
  bash "$HOME/scripts/${1}.sh" > >(tee -a "$LOG") 2>&1
}

install () {
  source "$OPTIONS" || exit 1

  case "$1" in
    "system")
      arch-chroot /mnt "/root/stack/${1}/install.sh" > >(tee -a "$LOG") 2>&1;;
    "desktop" | "apps")
      arch-chroot /mnt runuser -u "$USERNAME" -- "/home/$USERNAME/stack/${1}/install.sh" > >(tee -a "$LOG") 2>&1;;
  esac
}

abort () {
  echo -e "\nError: something fatal went wrong"
  echo "Process exiting with code 1..."
  exit 1
}

clear

cat << EOF
░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░
░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░
░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░
EOF

echo -e "\nWelcome to Stack v1.0.0"
echo -e "Have your development environment on archlinux\n"

if [[ ! -e /etc/arch-release ]]; then
  echo "Error: this is not an archlinux media"
  echo "Process exiting with code 1..."
  exit 1
fi

echo "Let's start by configuring your system"
read -rep "Do you want to proceed? [Y/n] " REPLY
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
  install "system" &&
  install "desktop" &&
  install "apps" &&
  run "reboot" || abort
