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

install_eclipse () {
  echo "Installing eclipse..."

  yay -S --noconfirm eclipse-jee || exit 1

  echo -e "Eclipse has been installed\n"
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

install_slack () {
  echo "Installing the slack..."

  yay -S --noconfirm slack-desktop || exit 1

  echo -e "Slack has been installed\n"
}

install_discord () {
  echo "Installing the discord..."

  sudo pacman -S --noconfirm discord || exit 1

  echo -e "Discord has been installed\n"
}

install_skype () {
  echo "Installing the skype..."

  yay -S --noconfirm skypeforlinux-stable-bin || exit 1

  echo -e "Skype has been installed\n"
}

install_teams () {
  echo "Installing the teams..."

  yay -S --noconfirm teams || exit 1

  echo -e "Teams has been installed\n"
}

install_irssi () {
  echo "Installing irssi client..."

  sudo pacman -S --noconfirm irssi || exit 1

  sudo cp ~/stack/apps/irssi/desktop /usr/share/applications/irssi.desktop

  echo -e "Irssi clinet has been installed\n"
}

install_libreoffice () {
  echo "Installing the libre office..."

  sudo pacman -S --noconfirm libreoffice-fresh || exit 1

  echo -e "Libre office has been installed\n"
}

install_xournal () {
  echo "Installing the hand write xounral++ editor..."

  sudo pacman -S --noconfirm xournalpp || exit 1

  printf '%s\n' \
    'application/x-xojpp=com.github.xournalapp.xournalapp.desktop' \
    'application/x-xopp=com.github.xournalapp.xournalapp.desktop' \
    'application/x-xopt=com.github.xournalapp.xournalapp.desktop' >> ~/.config/mimeapps.list

  echo "Mime types has been added"
  echo -e "Xounral++ has been installed\n"
}

install_foliate () {
  echo "Installing the epub foliate viewer..."

  sudo pacman -S --noconfirm foliate || exit 1

  printf '%s\n' \
    'application/epub+zip=com.github.johnfactotum.Foliate.desktop' >> ~/.config/mimeapps.list

  echo "Mime types has been added"
  echo -e "Foliate has been installed\n"
}

install_evince () {
  echo "Installing the evince pdf viewer..."

  yay -S --noconfirm --useask --removemake --nodiffmenu evince-no-gnome poppler > /dev/null || exit 1

  printf '%s\n' \
    'application/pdf=org.gnome.Evince.desktop' >> ~/.config/mimeapps.list

  echo "Mime types has been added"
  echo -e "Evince viewer has been installed\n"
}

install_teamviewer () {
  echo "Installing the team viewer... "

  yay -S --noconfirm teamviewer || exit 1

  echo "Enabling daemon service..."

  sudo systemctl enable teamviewerd || exit 1

  echo "Daemon service has been enabled"

  echo -e "Team viewer has been installed\n"
}

install_anydesk () {
  echo "Installing the AnyDesk... "

  yay -S --noconfirm anydesk-bin || exit 1

  echo "Enabling daemon service..."

  sudo systemctl enable anydesk || exit 1

  echo "Daemon service has been enabled"

  echo -e "AnyDesk has been installed\n"
}

install_tigervnc () {
  echo "Installing the TigerVNC... "

  sudo pacman -S --noconfirm tigervnc remmina libvncserver || exit 1

  echo -e "TigerVNC has been installed\n"
}

install_filezilla () {
  echo "Installing the Filezilla... "

  sudo pacman -S --noconfirm filezilla || exit 1

  echo -e "Filezilla has been installed\n"
}

install_rclone () {
  echo "Installing the RClone... "

  sudo pacman -S --noconfirm rclone || exit 1

  echo -e "RClone has been installed\n"
}

install_transmission () {
  echo "Installing the Transmission... "

  sudo pacman -S --noconfirm transmission-cli transmission-gtk || exit 1

  echo -e "Transmission has been installed\n"
}

install_docker () {
  echo "Installing the docker engine..."

  sudo pacman -S --noconfirm docker docker-compose || exit 1

  echo "Enabling the docker service..."

  sudo systemctl enable docker.service || exit 1

  echo "Docker service has been enabled"

  sudo usermod -aG docker "$USERNAME"

  echo "User added to the docker user group"

  echo -e "Docker has been installed\n"
}

install_virtualbox () {
  echo "Installing the Virtual Box..."

  local PKGS="virtualbox virtualbox-guest-iso"

  if [[ "${KERNELS[@]}" =~ stable ]]; then
    PKGS="$PKGS virtualbox-host-modules-arch"
  fi

  if [[ "${KERNELS[@]}" =~ lts ]]; then
    PKGS="$PKGS virtualbox-host-dkms"
  fi

  sudo pacman -S --noconfirm $PKGS || exit 1

  sudo usermod -aG vboxusers "$USERNAME"

  echo "User added to the vboxusers user group"

  echo -e "Virtual Box has been installed\n"
}

install_vmware () {
  echo "Installing the VMware..."

  sudo pacman -S --noconfirm fuse2 gtkmm pcsclite libcanberra &&
    yay -S --noconfirm --needed vmware-workstation  > /dev/null || exit 1

  echo "Enabling vmware services..."

  sudo systemctl enable vmware-networks.service &&
  sudo systemctl enable vmware-usbarbitrator.service || exit 1

  echo "Services has been enabled"

  echo -e "Vmware has been installed\n"
}

echo -e "\nStarting the apps installation process..."

if [[ "$(id -u)" == "0" ]]; then
  echo -e "\nError: process must be run as non root user"
  echo "Process exiting with code 1..."
  exit 1
fi

source ~/stack/.options

for APP in "${APPS[@]}"; do
  install_${APP}
done

echo -e "\nSetting up apps has been completed"
echo "Moving to the next process..."
sleep 5
