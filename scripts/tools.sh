#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the postman client.
install_postman () {
  log 'Installing the postman client...'

  OUTPUT="$(
    yay -S --noconfirm --removemake postman-bin 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Postman client has been installed\n'
}

# Installs the mongodb compass client.
install_compass () {
  log 'Installing the mongodb compass client...'

  OUTPUT="$(
    yay -S --noconfirm --removemake mongodb-compass 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Mongodb compass client has been installed\n'
}

# Installs the free version of the studio3t client.
install_studio3t () {
  log 'Installing the studio3t client...'

  OUTPUT="$(
    yay -S --noconfirm --removemake studio-3t 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Studio3t client has been installed\n'
}

# Installs the free version of the dbeaver client.
install_dbeaver () {
  log 'Installing the dbeaver client...'

  # Select the jre provider instead of jdk
  OUTPUT="$(
    printf '%s\n' 2 y | sudo pacman -S dbeaver 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Dbeaver client has been installed\n'
}

# Installs the discord.
install_discord () {
  log 'Installing the discord...'

  OUTPUT="$(
    sudo pacman -S --noconfirm discord 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Discord has been installed\n'
}

# Installs the slack.
install_slack () {
  log 'Installing the slack...'

  OUTPUT="$(
    yay -S --noconfirm --removemake slack-desktop 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Slack has been installed\n'
}

# Installs the skype.
install_skype () {
  log 'Installing the skype...'

  OUTPUT="$(
    yay -S --noconfirm --removemake skypeforlinux-stable-bin 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Skype has been installed\n'
}

# Installs the irssi client.
install_irssi () {
  log 'Installing the irssi client...'

  OUTPUT="$(
    sudo pacman -S --noconfirm irssi 2>&1
  )" || fail

  log -t file "${OUTPUT}"

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
    'Keywords=Chat;IRC;Console' | sudo tee "${desktop_file}" > /dev/null || fail

  log 'Irssi client has been installed\n'
}

# Installs the filezilla client.
install_filezilla () {
  log 'Installing the filezilla client...'

  OUTPUT="$(
    sudo pacman -S --noconfirm filezilla 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Filezilla client has been installed\n'
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

  OUTPUT="$(
    sudo pacman -S --noconfirm ${pckgs} 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  sudo usermod -aG vboxusers "${user_name}" || fail

  log "User ${user_name} added to the vboxusers user group"

  log 'Virtual box has been installed\n'
}

# Installs the vmware.
install_vmware () {
  log 'Installing the vmware...'

  OUTPUT="$(
    sudo pacman -S --noconfirm fuse2 gtkmm pcsclite libcanberra 2>&1 &&
      yay -S --noconfirm --needed --removemake vmware-workstation 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Enabling vmware services...'

  OUTPUT="$(
    sudo systemctl enable vmware-networks.service 2>&1 &&
      sudo systemctl enable vmware-usbarbitrator.service 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Services have been enabled'

  log 'Vmware has been installed\n'
}

log '\nStarting the tools installation process...'

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
