#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the postman client.
install_postman () {
  log 'Installing the postman client...'

  yay -S --needed --noconfirm --removemake postman-bin 2>&1
  
  if has_failed; then
    log WARN 'Failed to install postman client'
    return 0
  fi

  log 'Postman client has been installed'
}

# Installs the mongodb compass client.
install_compass () {
  log 'Installing the mongodb compass client...'

  yay -S --needed --noconfirm --removemake mongodb-compass 2>&1
  
  if has_failed; then
    log WARN 'Failed to install mongodb compass client'
    return 0
  fi

  log 'Mongodb compass client has been installed'
}

# Installs the free version of the studio3t client.
install_studio3t () {
  log 'Installing the studio3t client...'

  yay -S --needed --noconfirm --removemake studio-3t 2>&1

  if has_failed; then
    log WARN 'Failed to install studio-3t client'
    return 0
  fi

  log 'Studio3t client has been installed'
}

# Installs the free version of the dbeaver client.
install_dbeaver () {
  log 'Installing the dbeaver client...'

  # Select the jre provider instead of jdk
  printf '%s\n' 2 y | sudo pacman -S --needed dbeaver 2>&1

  if has_failed; then
    log WARN 'Failed to install dbeaver client'
    return 0
  fi

  log 'Dbeaver client has been installed'
}

# Installs the discord.
install_discord () {
  log 'Installing the discord...'

  sudo pacman -S --needed --noconfirm discord 2>&1
  
  if has_failed; then
    log WARN 'Failed to install discord'
    return 0
  fi

  log 'Discord has been installed'
}

# Installs the slack.
install_slack () {
  log 'Installing the slack...'

  yay -S --needed --noconfirm --removemake slack-desktop 2>&1
  
  if has_failed; then
    log WARN 'Failed to install slack'
    return 0
  fi

  log 'Slack has been installed'
}

# Installs the skype.
install_skype () {
  log 'Installing the skype...'

  yay -S --needed --noconfirm --removemake skypeforlinux-stable-bin 2>&1

  if has_failed; then
    log WARN 'Failed to install skype'
    return 0
  fi

  log 'Skype has been installed'
}

# Installs the irssi client.
install_irssi () {
  log 'Installing the irssi client...'

  sudo pacman -S --needed --noconfirm irssi 2>&1

  if has_failed; then
    log WARN 'Failed to install irssi client'
    return 0
  fi

  local desktop_home='/usr/local/share/applications'
  local desktop_file="${desktop_home}/irssi.desktop"

  sudo mkdir -p "${desktop_home}"

  printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    'Name=Irssi' \
    'comment=Console IRC Client' \
    'Exec=irssi' \
    'Terminal=true' \
    'Icon=irssi' \
    'Catogories=Chat;IRC;Console' \
    'Keywords=Chat;IRC;Console' | sudo tee "${desktop_file}" > /dev/null &&
    log 'Desktop file irssi.desktop has been created' ||
    log WARN 'Failed to create desktop file irssi.desktop'
  
  log 'Irssi client has been installed'
}

# Installs the filezilla client.
install_filezilla () {
  log 'Installing the filezilla client...'

  sudo pacman -S --needed --noconfirm filezilla 2>&1

  if has_failed; then
    log WARN 'Failed to install filezilla'
    return 0
  fi

  log 'Filezilla client has been installed'
}

# Installs the virtual box.
install_virtual_box () {
  log 'Installing the virtual box...'

  local kernels=''
  kernels="$(get_setting 'kernels' | jq -cer 'join(" ")')" || fail

  local pckgs='virtualbox virtualbox-guest-iso'

  if match "${kernels}" 'stable'; then
    pckgs+=' virtualbox-host-modules-arch'
  fi

  if match "${kernels}" 'lts'; then
    pckgs+=' virtualbox-host-dkms'
  fi

  sudo pacman -S --needed --noconfirm ${pckgs} 2>&1

  if has_failed; then
    log WARN 'Failed to install virtual box'
    return 0
  fi

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  sudo usermod -aG vboxusers "${user_name}" 2>&1 &&
    log 'User added to the vboxusers user group' ||
    log WARN 'Failed to add user to vboxusers group'

  log 'Virtual box has been installed'
}

# Installs the vmware.
install_vmware () {
  log 'Installing the vmware...'

  sudo pacman -S --needed --noconfirm fuse2 gtkmm pcsclite libcanberra 2>&1 &&
    yay -S --needed --noconfirm --needed --removemake vmware-workstation 2>&1
  
  if has_failed; then
    log WARN 'Failed to install vmware'
    return 0
  fi

  sudo systemctl enable vmware-networks.service 2>&1 &&
    log 'Service vmware-networks has been enabled' ||
    log WARN 'Failed to enable vmware-networks service'

  sudo systemctl enable vmware-usbarbitrator.service 2>&1 &&
    log 'Service vmware-usbarbitrator has been enabled' ||
    log WARN 'Failed to enabled vmware-usbarbitrator service'
  
  log 'Vmware has been installed'
}

log 'Installing some extra tools...'

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
