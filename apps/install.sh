#!/usr/bin/env bash

set -Eeo pipefail

install_firefox () {
  echo "Installing the firefox browser..."

  sudo pacman -S --noconfirm firefox || exit 1

  echo -e "Firefox has been installed\n"
}

install_chrome () {
  echo "Installing the chrome browser..."

  yay -S --noconfirm google-chrome || exit 1

  echo -e "Chrome has been installed\n"
}

install_brave () {
  echo "Installing the brave browser..."

  yay -S --noconfirm brave-bin || exit 1

  echo -e "Brave has been installed\n"
}

install_tor () {
  echo "Installing the tor browser..."

  yay -S --noconfirm tor tor-browser || exit 1

  echo -e "Tor has been installed\n"
}

install_code () {
  echo "Installing the visual studio code..."

  sudo pacman -S --noconfirm code || exit 1

  echo -e "Visual studio code has been installed\n"
}

install_sublime () {
  echo "Installing the sublime text editor..."

  yay -S --noconfirm sublime-text-4 || exit 1

  echo -e "Sublime text has been installed\n"
}

install_neovim () {
  echo "Installing the neovim editor..."

  sudo pacman -S --noconfirm neovim || exit 1

  echo -e "Neovim has been installed\n"
}

install_postman () {
  echo "Installing the postman..."

  yay -S --noconfirm postman-bin || exit 1

  echo -e "Postman has been installed\n"
}

install_compass () {
  echo "Installing mongodb compass..."

  yay -S --noconfirm mongodb-compass || exit 1

  echo -e "MongoDB Compass has been installed\n"
}

install_robo3t () {
  echo "Installing Robo3t..."

  yay -S --noconfirm robo3t-bin || exit 1

  echo -e "Robo3t has been installed\n"
}

install_studio3t () {
  echo "Installing Studio3t..."

  yay -S --noconfirm studio-3t || exit 1

  echo -e "Studio3t has been installed\n"
}

install_dbeaver () {
  echo "Installing the DBeaver..."

  sudo pacman -S --noconfirm dbeaver || exit 1

  echo -e "Dbeaver has been installed\n"
}

install_libreoffice () {
  echo "Installing the libre office..."

  sudo pacman -S --noconfirm libreoffice-fresh || exit 1

  echo -e "Libre office has been installed\n"
}

install_xournal () {
  echo "Installing the hand write xounral++ editor..."

  sudo pacman -S --noconfirm xournalpp || exit 1

  echo -e "Xounral++ has been installed\n"
}

install_foliate () {
  echo "Installing the epub foliate viewer..."

  sudo pacman -S --noconfirm foliate || exit 1

  echo -e "Foliate has been installed\n"
}

install_evince () {
  echo "Installing the evince pdf viewer..."

  yay -S --noconfirm --useask --removemake --nodiffmenu evince-no-gnome poppler > /dev/null || exit 1

  echo -e "Evince viewer has been installed\n"
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

install "browsers" &&
  install "editors" &&
  install "clients" &&
  install "office" &&
  setup_mimes

echo -e "\nSetting up apps has been completed"
echo "Moving to the next process..."
sleep 5
