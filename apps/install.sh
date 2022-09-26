#!/usr/bin/env bash

set -Eeo pipefail

install_document_viewers () {
  echo "Installing various document viewers..."

  sudo pacman -S --noconfirm xournalpp poppler foliate || exit 1

  yay -S --noconfirm --useask --removemake --nodiffmenu evince-no-gnome > /dev/null || exit 1

  echo "Document viewers have been installed"
}

install_code () {
  echo "Installing the visual studio code..."

  sudo pacman -S --noconfirm code

  echo -e "Visual studio code has been installed\n"
}

install_atom () {
  echo "Installing the atom editor..."

  yay -S --noconfirm atom

  echo -e "Atom has been installed\n"
}

install_sublime () {
  echo "Installing the sublime text editor..."

  yay -S --noconfirm sublime-text-4

  echo -e "Sublime text has been installed\n"
}

install_neovim () {
  echo "Installing the neovim editor..."

  sudo pacman -S --noconfirm neovim

  echo -e "Neovim has been installed\n"
}

install_firefox () {
  echo "Installing the firefox browser..."

  sudo pacman -S --noconfirm firefox

  echo -e "Firefox has been installed\n"
}

install_chrome () {
  echo "Installing the chrome browser..."

  yay -S --noconfirm google-chrome

  echo -e "Chrome has been installed\n"
}

install_brave () {
  echo "Installing the brave browser..."

  yay -S --noconfirm brave-bin

  echo -e "Brave has been installed\n"
}

install_tor () {
  echo "Installing the tor browser..."

  sudo pacman -S --noconfirm tor

  echo -e "Tor has been installed\n"
}

install () {
  declare -n APPS=${1^^}

  for APP in "${APPS[@]}"; do
    install_${APP} || exit 1
  done

  unset APPS
}

setup_mimes () {
  echo "Setting up application mime types..."

  cp ~/stack/apps/mimes/app.list ~/.config/mimeapps.list
  chmod 644 ~/.config/mimeapps.list

  echo "Application mime types have been set"
}

echo -e "\nStarting the apps installation process..."

if [[ "$(id -u)" == "0" ]]; then
  echo -e "\nError: process must be run as non root user"
  echo "Process exiting with code 1..."
  exit 1
fi

source ~/stack/.options

install_document_viewers &&
  install "editors" &&
  install "browsers" &&
  setup_mimes

echo -e "\nSetting up apps has been completed"
echo "Moving to the next process..."
sleep 5
