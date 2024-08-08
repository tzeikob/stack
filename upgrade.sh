#!/bin/bash

set -Eeo pipefail

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh

# Updates the commons script files.
update_commons () {
  log INFO 'Updating the commons files...'

  sudo rsync -av src/commons/ /opt/stack/commons ||
    abort ERROR 'Failed to update the commons files.'
  
  sudo sed -i 's;source src;source /opt/stack;' /opt/stack/commons/* ||
    abort ERROR 'Failed to fix source paths to /opt/stack.'
  
  log INFO 'Source paths fixed to /opt/stack.'
  
  log INFO 'Commons files have been updated.'
}

# Updates the tools script files.
update_tools () {
  log INFO 'Updating the tools files...'

  sudo rsync -av src/tools/ /opt/stack/tools &&
    sudo rsync -av --exclude tqdm airootfs/usr/local/bin/ /usr/local/bin ||
    abort ERROR 'Failed to update the tools files.'
  
  sudo sed -i 's;source src;source /opt/stack;' /opt/stack/tools/**/* ||
    abort ERROR 'Failed to fix source paths to /opt/stack.'
  
  log INFO 'Source paths fixed to /opt/stack.'

  log INFO 'Tools files have been updated.'
}

# Updates the os release data.
update_release_data () {
  log INFO 'Updating the release data...'

  local version=''
  version="$(date +%Y.%m.%d)" ||
    abort ERROR 'Failed to create release version.'

  sudo cp airootfs/usr/lib/os-release /usr/lib/os-release ||
    abort ERROR 'Failed to update the release file.'
  
  log INFO 'Release file has been updated.'
  
  sudo sed -i "s/#VERSION#/${version}/" /usr/lib/os-release ||
    abort ERROR 'Failed to set release version.'
  
  log INFO "New release version set to ${version}."
  
  sudo cp airootfs/etc/stack-release /etc/stack-release ||
    abort ERROR 'Failed to update the stack-release symlink.'
  
  log INFO 'Stack release symlink has been updated.'

  sudo rm -f /etc/arch-release ||
    abort ERROR 'Unable to remove the arch-release file.'
  
  log INFO 'Release data have been updated.'
}

# Updates the pacman hooks and scripts.
update_pacman_hooks () {
  log INFO 'Updating pacman hooks and scripts...'

  sudo rsync -av airootfs/etc/pacman.d/hooks/ /etc/pacman.d/hooks ||
    abort ERROR 'Failed to update pacman hooks.'
  
  log INFO 'Pacman hooks have been updated.'
  
  sudo rsync -av airootfs/etc/pacman.d/scripts/ /etc/pacman.d/scripts ||
    abort ERROR 'Failed to update pacman scripts.'
  
  log INFO 'Pacman scripts have been updated.'
}

# Updates proxy sudoers rules.
update_proxy_rules () {
  log INFO 'Updating sudoers proxy rules...'

  sudo rsync -av \
    airootfs/etc/sudoers.d/proxy_rules /etc/sudoers.d/proxy_rules ||
    abort ERROR 'Failed to update sudoers proxy rules.'
  
  log INFO 'Sudoers proxy rules have been updated.'
}

# Updates power configurations.
update_power_configurations () {
  log INFO 'Updating power configurations...'

  sudo rsync -av \
    airootfs/etc/systemd/logind.conf.d/ /etc/systemd/logind.conf.d ||
    abort ERROR 'Failed to update login power settings.'
  
  log INFO 'Login power settings have been updated.'

  sudo rsync -av \
    airootfs/etc/systemd/sleep.conf.d/ /etc/systemd/sleep.conf.d ||
    abort ERROR 'Failed to update sleep power settings.'
  
  log INFO 'Sleep power settings have been updated.'
  
  sudo rsync -av airootfs/etc/tlp.d/ /etc/tlp.d ||
    abort ERROR 'Failed to update TLP power settings.'
  
  log INFO 'TLP power settings have been updated.'
  
  sudo rsync -av airootfs/etc/x11/xorg.conf /etc/x11/xorg.conf ||
    abort ERROR 'Failed to update the xorg configuration.'
  
  log INFO 'Xorg configuration has been updated.'
}

# Updates devices rules.
update_devices_rules () {
  log INFO 'Updating devices rules...'

  sudo rsync -av airootfs/etc/udev/rules.d/ /etc/udev/rules.d ||
    abort ERROR 'Failed to update devices rules.'
  
  log INFO 'Devices rules have been updated.'
}

# Updates the locker.
update_locker () {
  log INFO 'Updating the locker...'

  sudo systemctl disable lock@${USER}.service 2>&1 ||
    log WARN 'Unable to disable lock service.'

  sudo rsync -av \
    airootfs/etc/systemd/system/lock@.service /etc/systemd/system/lock@.service ||
    abort ERROR 'Failed to update the lock service.'
  
  log INFO 'Lock service has been updated.'
  
  local user_id=''
  user_id="$(
    id -u "${USER}" 2>&1
  )" || abort ERROR 'Failed to get the user id.'

  sudo sed -i "s/#USER_ID#/${user_id}/g" /etc/systemd/system/lock@.service &&
    abort ERROR 'Failed to set the user id in lock service.'
  
  sudo rsync -av \
    airootfs/usr/lib/systemd/system-sleep/locker /usr/lib/systemd/system-sleep/locker ||
    abort ERROR 'Failed to update the lock service hook.'
  
  log INFO 'Lock service hook has been updated.'
  
  sudo systemctl enable lock@${USER}.service 2>&1 ||
    log WARN 'Unable to enable lock service.'
  
  log INFO 'Lock service has been enabled.'
  
  log INFO 'Locker has been updated.'
}

# Updates the tqdm patch file.
update_tqdm_patch () {
  log INFO 'Updating the tqdm patch file...'

  sudo rsync -av airootfs/usr/local/bin/tqdm /usr/local/bin/tqdm ||
    abort ERROR 'Failed to update the tqdm patch file.'

  log INFO 'Tqdm patch file has been updated.'
}

# Updates the desktop files and modules.
update_desktop () {
  log INFO 'Updating the desktop files...'

  rsync -av airootfs/home/user/.xinitrc "/home/${USER}/.xinitrc" ||
    abort ERROR 'Failed to update the .xinitrc file.'
  
  log INFO 'Xinitrc file has been updated.'

  rsync -av airootfs/home/user/.stackrc "/home/${USER}/.stackrc" ||
    abort ERROR 'Failed to update the .stackrc file.'
  
  sed -i \
    -e 's/#TERMINAL#/alacritty/' \
    -e 's/#EDITOR#/helix/' "/home/${USER}/.stackrc" ||
    abort ERROR 'Failed to set the terminal defaults.'
  
  log INFO 'Stackrc file has been updated.'

  rsync -av --exclude stack --exclude gtk-3.0 --exclude systemd \
    airootfs/home/user/.config/ "/home/${USER}/.config" ||
    abort ERROR 'Failed to update the user config folder.'
  
  log INFO 'User config folder has been updated.'

  rsync -av \
    airootfs/home/user/.local/share/wallpapers/ "/home/${USER}/.local/share/wallpapers" ||
    abort ERROR 'Failed to update the wallpapers.'
  
  log INFO 'Wallpapers have been updated.'

  sudo rsync -av airootfs/usr/share/sounds/system/ /usr/share/sounds/system ||
    abort ERROR 'Failed to update the system sounds.'
  
  log INFO 'System sounds have been updated.'

  log INFO 'Desktop files have been updated.'
}

# Updates user and system services.
update_services () {
  log INFO 'Updating user and system services...'

  rsync -av \
    airootfs/home/user/.config/systemd/user/ "/home/${USER}/.config/systemd/user" ||
    abort ERROR 'Failed to update user services.'
  
  log INFO 'User services have been updated.'
  
  sed -i "s;#HOME#;/home/${USER};g" \
    "/home/${USER}/.config/systemd/user/fix-layout.service" ||
    abort ERROR 'Failed to set the home in fix layout service.'

  log INFO 'Services have been updated.'
}

# Restores the user permissions under the home directory.
restore_user_permissions () {
  chown -R ${USER}:${USER} "/home/${USER}" ||
    abort ERROR 'Failed to restore user permissions.'
  
  log INFO 'User permissions have been restored.'
}

if is_not_equal "${PWD}" '/tmp/stack'; then
  abort ERROR "Unable to run this script out of /tmp/stack."
fi

log INFO 'Starting the upgrade process...'

update_commons &&
  update_tools &&
  update_release_data &&
  update_pacman_hooks &&
  update_proxy_rules &&
  update_power_configurations &&
  update_devices_rules &&
  update_locker &&
  update_tqdm_patch &&
  update_desktop &&
  update_services &&
  restore_user_permissions

log INFO 'Upgrade process has been completed.'
log INFO 'Please reboot your system!'
