#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the google chrome web browser.
install_chrome () {
  log INFO 'Installing the chrome web browser...'

  yay -S --needed --noconfirm --removemake google-chrome 2>&1
  
  if has_failed; then
    log WARN 'Failed to install the chrome web browser'
    return 0
  fi

  log INFO 'Chrome web browser has been installed'
}

# Installs the firefox web browser.
install_firefox () {
  log INFO 'Installing the firefox web browser...'

  sudo pacman -S --needed --noconfirm firefox 2>&1
  
  if has_failed; then
    log WARN 'Failed to install the firefox web browser'
    return 0
  fi

  log INFO 'Firefox web browser has been installed'
}

# Installs the tor web browser.
install_tor () {
  log INFO 'Installing the tor web browser...'

  sudo pacman -S --needed --noconfirm torbrowser-launcher 2>&1
  
  if has_failed; then
    log WARN 'Failed to install the tor web browser'
    return 0
  fi

  log INFO 'Tor web browser has been installed'
}

# Installs the postman client.
install_postman () {
  log INFO 'Installing the postman client...'

  yay -S --needed --noconfirm --removemake postman-bin 2>&1
  
  if has_failed; then
    log WARN 'Failed to install postman client'
    return 0
  fi

  log INFO 'Postman client has been installed'
}

# Installs the mongodb compass client.
install_compass () {
  log INFO 'Installing the mongodb compass client...'

  yay -S --needed --noconfirm --removemake mongodb-compass 2>&1
  
  if has_failed; then
    log WARN 'Failed to install mongodb compass client'
    return 0
  fi

  log INFO 'Mongodb compass client has been installed'
}

# Installs the free version of the studio3t client.
install_studio3t () {
  log INFO 'Installing the studio3t client...'

  yay -S --needed --noconfirm --removemake studio-3t 2>&1

  if has_failed; then
    log WARN 'Failed to install studio-3t client'
    return 0
  fi

  log INFO 'Studio3t client has been installed'
}

# Installs the free version of the dbeaver client.
install_dbeaver () {
  log INFO 'Installing the dbeaver client...'

  # Select the jre provider instead of jdk
  printf '%s\n' 2 y | sudo pacman -S --needed dbeaver 2>&1

  if has_failed; then
    log WARN 'Failed to install dbeaver client'
    return 0
  fi

  log INFO 'Dbeaver client has been installed'
}

# Installs the discord.
install_discord () {
  log INFO 'Installing the discord...'

  sudo pacman -S --needed --noconfirm discord 2>&1
  
  if has_failed; then
    log WARN 'Failed to install discord'
    return 0
  fi

  log INFO 'Discord has been installed'
}

# Installs the slack.
install_slack () {
  log INFO 'Installing the slack...'

  yay -S --needed --noconfirm --removemake slack-electron 2>&1
  
  if has_failed; then
    log WARN 'Failed to install slack'
    return 0
  fi

  log INFO 'Slack has been installed'
}

# Installs the skype.
install_skype () {
  log INFO 'Installing the skype...'

  yay -S --needed --noconfirm --removemake skypeforlinux-bin 2>&1

  if has_failed; then
    log WARN 'Failed to install skype'
    return 0
  fi

  log INFO 'Skype has been installed'
}

# Installs the irssi client.
install_irssi () {
  log INFO 'Installing the irssi client...'

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
    log INFO 'Desktop file irssi.desktop has been created' ||
    log WARN 'Failed to create desktop file irssi.desktop'
  
  log INFO 'Irssi client has been installed'
}

# Installs the filezilla client.
install_filezilla () {
  log INFO 'Installing the filezilla client...'

  sudo pacman -S --needed --noconfirm filezilla 2>&1

  if has_failed; then
    log WARN 'Failed to install filezilla'
    return 0
  fi

  log INFO 'Filezilla client has been installed'
}

# Installs the virtual box.
install_virtual_box () {
  log INFO 'Installing the virtual box...'

  local kernel=''
  kernel="$(get_setting 'kernel')" || abort ERROR 'Unable to read kernel setting'

  local pckgs='virtualbox virtualbox-guest-iso'

  if equals "${kernel}" 'stable'; then
    pckgs+=' virtualbox-host-modules-arch'
  elif equals "${kernel}" 'lts'; then
    pckgs+=' virtualbox-host-dkms'
  fi

  sudo pacman -S --needed --noconfirm ${pckgs} 2>&1

  if has_failed; then
    log WARN 'Failed to install virtual box'
    return 0
  fi

  local user_name=''
  user_name="$(get_setting 'user_name')" || abort ERROR 'Unable to read user_name setting'

  sudo usermod -aG vboxusers "${user_name}" 2>&1 &&
    log INFO 'User added to the vboxusers user group' ||
    log WARN 'Failed to add user to vboxusers group'

  log INFO 'Virtual box has been installed'
}

# Installs the vmware.
install_vmware () {
  log INFO 'Installing the vmware...'

  sudo pacman -S --needed --noconfirm fuse2 gtkmm pcsclite libcanberra 2>&1 &&
    yay -S --needed --noconfirm --removemake vmware-workstation 2>&1
  
  if has_failed; then
    log WARN 'Failed to install vmware'
    return 0
  fi

  sudo systemctl enable vmware-networks.service 2>&1 &&
    log INFO 'Service vmware-networks has been enabled' ||
    log WARN 'Failed to enable vmware-networks service'

  sudo systemctl enable vmware-usbarbitrator.service 2>&1 &&
    log INFO 'Service vmware-usbarbitrator has been enabled' ||
    log WARN 'Failed to enabled vmware-usbarbitrator service'
  
  log INFO 'Vmware has been installed'
}

# Installs the libre office.
install_libre_office () {
  log INFO 'Installing the libre office...'

  sudo pacman -S --needed --noconfirm libreoffice-fresh 2>&1

  if has_failed; then
    log WARN 'Failed to install libre office'
    return 0
  fi

  log INFO 'Libre office has been installed'
}

# Installs the foliate epub reader.
install_foliate () {
  log INFO 'Installing foliate epub reader...'

  sudo pacman -S --needed --noconfirm foliate poppler 2>&1
  
  if has_failed; then
    log WARN 'Failed to install foliate epub reader'
    return 0
  fi

  local user_name=''
  user_name="$(get_setting 'user_name')" || abort ERROR 'Unable to read user_name setting'

  local config_home="/home/${user_name}/.config"

  printf '%s\n' \
    'application/epub+zip=com.github.johnfactotum.Foliate.desktop' >> "${config_home}/mimeapps.list" &&
    log INFO 'Epub mime type has been added' ||
    log WARN 'Failed to add epub mime types'
  
  log INFO 'Foliate epub reader has been installed'
}

# Installs the transmission torrent client.
install_transmission () {
  log INFO 'Installing the transmission torrent client...'

  sudo pacman -S --needed --noconfirm transmission-cli transmission-gtk 2>&1

  if has_failed; then
    log WARN 'Failed to install transmission torrent client'
    return 0
  fi

  log INFO 'Transmission torrent client has been installed'
}

# Resolves the installaction script by addressing
# some extra post execution tasks.
resolve () {
  # Read the current progress as the number of log lines
  local lines=0
  lines=$(cat /var/log/stack/tools.log | wc -l) ||
    abort ERROR 'Unable to read the current log lines'

  local total=1900

  # Fill the log file with fake lines to trick tqdm bar on completion
  if [[ ${lines} -lt ${total} ]]; then
    local lines_to_append=0
    lines_to_append=$((total - lines))

    while [[ ${lines_to_append} -gt 0 ]]; do
      echo '~'
      sleep 0.15
      lines_to_append=$((lines_to_append - 1))
    done
  fi

  return 0
}

log INFO 'Script tools.sh started'
log INFO 'Installing some extra tools...'

if equals "$(id -u)" 0; then
  abort ERROR 'Script tools.sh must be run as non root user'
fi

install_chrome &&
  install_firefox &&
  install_tor &&
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
  install_vmware &&
  install_libre_office &&
  install_foliate &&
  install_transmission

log INFO 'Script tools.sh has finished'

resolve && sleep 3
