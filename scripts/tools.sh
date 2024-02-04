#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the postman client.
install_postman () {
  echo -e 'Installing the postman client...'

  yay -S --noconfirm --removemake postman-bin || fail 'Failed to install postman'

  echo -e 'Postman client has been installed'
}

# Installs the mongodb compass client.
install_compass () {
  echo -e 'Installing the mongodb compass client...'

  yay -S --noconfirm --removemake mongodb-compass || fail 'Failed to install mongo compass'

  echo -e 'Mongodb compass client has been installed'
}

# Installs the free version of the studio3t client.
install_studio3t () {
  echo -e 'Installing the studio3t client...'

  yay -S --noconfirm --removemake studio-3t || fail 'Failed to install studio-3t'

  echo -e 'Studio3t client has been installed'
}

# Installs the free version of the dbeaver client.
install_dbeaver () {
  echo -e 'Installing the dbeaver client...'

  # Select the jre provider instead of jdk
  printf '%s\n' 2 y | sudo pacman -S dbeaver ||
    fail 'Failed to install dbeaver client'

  echo -e 'Dbeaver client has been installed'
}

# Installs the discord.
install_discord () {
  echo -e 'Installing the discord...'

  sudo pacman -S --noconfirm discord || fail 'Failed to install discord'

  echo -e 'Discord has been installed'
}

# Installs the slack.
install_slack () {
  echo -e 'Installing the slack...'

  yay -S --noconfirm --removemake slack-desktop ||
    fail 'Failed to install slack'

  echo -e 'Slack has been installed'
}

# Installs the skype.
install_skype () {
  echo -e 'Installing the skype...'

  yay -S --noconfirm --removemake skypeforlinux-stable-bin ||
    fail 'Failed to install skype'

  echo -e 'Skype has been installed'
}

# Installs the irssi client.
install_irssi () {
  echo -e 'Installing the irssi client...'

  sudo pacman -S --noconfirm irssi || fail 'Failed to install irssi client'

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || fail

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
    'Keywords=Chat;IRC;Console' | sudo tee "${desktop_file}" > /dev/null ||
    fail 'Failed to create desktop file'
  
  echo -e 'Desktop file has been created'

  echo -e 'Irssi client has been installed'
}

# Installs the filezilla client.
install_filezilla () {
  echo -e 'Installing the filezilla client...'

  sudo pacman -S --noconfirm filezilla ||
    fail 'Failed to install filezilla'

  echo -e 'Filezilla client has been installed'
}

# Installs the virtual box.
install_virtual_box () {
  echo -e 'Installing the virtual box...'

  local kernels=''
  kernels="$(get_setting 'kernels' | jq -cer 'join(" ")')" || fail

  local pckgs='virtualbox virtualbox-guest-iso'

  if match "${kernels}" 'stable'; then
    pckgs+=' virtualbox-host-modules-arch'
  fi

  if match "${kernels}" 'lts'; then
    pckgs+=' virtualbox-host-dkms'
  fi

  sudo pacman -S --noconfirm ${pckgs} || fail 'Failed to install virtual box packages'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  sudo usermod -aG vboxusers "${user_name}" ||
    fail 'Failed to add user to vboxusers group'

  echo -e 'User added to the vboxusers user group'

  echo -e 'Virtual box has been installed'
}

# Installs the vmware.
install_vmware () {
  echo -e 'Installing the vmware...'

  sudo pacman -S --noconfirm fuse2 gtkmm pcsclite libcanberra &&
    yay -S --noconfirm --needed --removemake vmware-workstation ||
    fail 'Failed to install vmware packages'

  sudo systemctl enable vmware-networks.service ||
    fail 'Failed to enable vmware-networks service'
  
  echo -e 'Service vmware-networks has been enabled'

  sudo systemctl enable vmware-usbarbitrator.service ||
    fail 'Failed to enabled vmware-usbarbitrator service'
  
  echo -e 'Service vmware-usbarbitrator has been enabled'

  echo -e 'Vmware has been installed'
}

echo -e 'Installing the some extra tools...'

if equals "$(id -u)" 0; then
  fail 'Script tools.sh must be run as non root user'
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

sleep 3
