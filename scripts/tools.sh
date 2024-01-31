#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the postman client.
install_postman () {
  echo 'Installing the postman client...'

  yay -S --noconfirm --removemake postman-bin || exit 1

  echo -e 'Postman client has been installed\n'
}

# Installs the mongodb compass client.
install_compass () {
  echo 'Installing the mongodb compass client...'

  yay -S --noconfirm --removemake mongodb-compass || exit 1

  echo -e 'Mongodb compass client has been installed\n'
}

# Installs the free version of the studio3t client.
install_studio3t () {
  echo 'Installing the studio3t client...'

  yay -S --noconfirm --removemake studio-3t || exit 1

  echo -e 'Studio3t client has been installed\n'
}

# Installs the free version of the dbeaver client.
install_dbeaver () {
  echo 'Installing the dbeaver client...'

  # Select the jre provider instead of jdk
  printf '%s\n' 2 y | sudo pacman -S dbeaver || exit 1

  echo -e 'Dbeaver client has been installed\n'
}

# Installs the discord.
install_discord () {
  echo 'Installing the discord...'

  sudo pacman -S --noconfirm discord || exit 1

  echo -e 'Discord has been installed\n'
}

# Installs the slack.
install_slack () {
  echo 'Installing the slack...'

  yay -S --noconfirm --removemake slack-desktop || exit 1

  echo -e 'Slack has been installed\n'
}

# Installs the skype.
install_skype () {
  echo 'Installing the skype...'

  yay -S --noconfirm --removemake skypeforlinux-stable-bin || exit 1

  echo -e 'Skype has been installed\n'
}

# Installs the irssi client.
install_irssi () {
  echo 'Installing the irssi client...'

  sudo pacman -S --noconfirm irssi || exit 1

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || exit 1

  local desktop_file="${desktop_home}/irssi.desktop"

  printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    'Name=Irssi' \
    'comment=Console IRC Client' \
    'Exec=irssi' \
    'Terminal=true' \
    'Icon=irssi' \
    'Catogories=Chat;IRC;Console' \
    'Keywords=Chat;IRC;Console' | sudo tee "${desktop_file}" > /dev/null || exit 1

  echo -e 'Irssi client has been installed\n'
}

# Installs the filezilla client.
install_filezilla () {
  echo 'Installing the filezilla client...'

  sudo pacman -S --noconfirm filezilla || exit 1

  echo -e 'Filezilla client has been installed\n'
}

# Installs the virtual box.
install_virtual_box () {
  echo 'Installing the virtual box...'

  local kernels=''
  kernels="$(get_setting 'kernels' | jq -cer 'join(" ")')" || exit 1

  local pckgs='virtualbox virtualbox-guest-iso'

  if match "${kernels}" 'stable'; then
    pckgs+=' virtualbox-host-modules-arch'
  fi

  if match "${kernels}" 'lts'; then
    pckgs+=' virtualbox-host-dkms'
  fi

  sudo pacman -S --noconfirm ${pckgs} || exit 1

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  sudo usermod -aG vboxusers "${user_name}" || exit 1

  echo "User ${user_name} added to the vboxusers user group"

  echo -e 'Virtual box has been installed\n'
}

# Installs the vmware.
install_vmware () {
  echo 'Installing the vmware...'

  sudo pacman -S --noconfirm fuse2 gtkmm pcsclite libcanberra || exit 1
  yay -S --noconfirm --needed --removemake vmware-workstation || exit 1

  echo 'Enabling vmware services...'

  sudo systemctl enable vmware-networks.service &&
    sudo systemctl enable vmware-usbarbitrator.service || exit 1

  echo 'Services have been enabled'

  echo -e 'Vmware has been installed\n'
}

echo -e '\nStarting the tools installation process...'

if equals "$(id -u)" 0; then
  echo -e '\nProcess must be run as non root user'
  exit 1
fi

install_postman &&
  install_compass &&
  install_studio3t &&
  install_dbeaver &&
  install_discord &&
  install_slack &&
  install_skype &&
  install_irssi &&
  install_filezilla &&
  install_virtual_box &&
  install_vmware

echo -e '\nTools installation process has been completed'
echo 'Moving to the reboot process...'
sleep 5
