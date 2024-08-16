#!/bin/bash

set -Eeo pipefail

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh

# Updates the root file system.
update_root_files () {
  log INFO 'Updating the root file system...'

  # Rename airootfs user home to align with the current system
  if not_equals "${USER}" 'user'; then
    mv airootfs/home/user "airootfs/home/${USER}" ||
      abort ERROR "Failed to rename user home for ${USER}."
  fi

  sudo rsync -av airootfs/ / \
    --exclude etc/X11/xorg.conf.d/00-keyboard.conf \
    --exclude etc/hostname \
    --exclude etc/hosts \
    --exclude etc/vconsole.conf \
    --exclude "home/${USER}/.config/gtk-3.0" \
    --exclude "home/${USER}/.config/stack" ||
    abort ERROR 'Failed to update the root file system.'
  
  log INFO 'Root file system has been updated.'
}

# Updates the commons script files.
update_commons () {
  log INFO 'Updating the commons files...'

  sudo mkdir -p /opt/stack ||
    abort ERROR 'Failed to create the /opt/stack folder.'

  sudo rsync -av --delete src/commons/ /opt/stack/commons ||
    abort ERROR 'Failed to update the commons files.'
  
  sudo sed -i 's;source src;source /opt/stack;' /opt/stack/commons/* ||
    abort ERROR 'Failed to fix source paths to /opt/stack.'
  
  log INFO 'Source paths fixed to /opt/stack.'
  log INFO 'Commons files have been updated.'
}

# Updates the tools script files.
update_tools () {
  log INFO 'Updating the tools files...'

  sudo mkdir -p /opt/stack ||
    abort ERROR 'Failed to create the /opt/stack folder.'

  sudo rsync -av --delete src/tools/ /opt/stack/tools ||
    abort ERROR 'Failed to update the tools files.'
  
  sudo sed -i 's;source src;source /opt/stack;' /opt/stack/tools/**/* ||
    abort ERROR 'Failed to fix source paths to /opt/stack.'
  
  log INFO 'Source paths fixed to /opt/stack.'

  # Create and restore all symlinks for every tool
  sudo mkdir -p /usr/local/stack ||
    abort ERROR 'Failed to create the /usr/local/stack folder.'
  
  local main_files
  main_files=($(find /opt/stack/tools -type f -name 'main.sh')) ||
    abort ERROR 'Failed to get the list of main script file paths.'
  
  local main_file
  for main_file in "${main_files[@]}"; do
    # Extrack the tool handle name
    local tool_name
    tool_name="$(
      echo "${main_file}" | sed 's;/opt/stack/tools/\(.*\)/main.sh;\1;'
    )"

    sudo ln -sf "${main_file}" "/usr/local/stack/${tool_name}" ||
      abort ERROR "Failed to create symlink for ${main_file} file."
  done

  log INFO 'Tools symlinks have been restored.'
  log INFO 'Tools files have been updated.'
}

# Updates the os release data.
update_release_data () {
  log INFO 'Updating the release data...'

  local version=''
  version="$(date +%Y.%m.%d)" ||
    abort ERROR 'Failed to create release version.'
  
  sudo sed -i "s/#VERSION#/${version}/" /usr/lib/os-release ||
    abort ERROR 'Failed to set release version.'
  
  log INFO "New release version set to ${version}."
  log INFO 'Release data have been updated.'
}

# Updates the locker.
update_locker () {
  log INFO 'Updating the locker...'

  sudo systemctl disable lock@${USER}.service 2>&1 ||
    log WARN 'Unable to disable lock service.'
  
  local user_id=''
  user_id="$(
    id -u "${USER}" 2>&1
  )" || abort ERROR 'Failed to get the user id.'

  sudo sed -i "s/#USER_ID#/${user_id}/g" /etc/systemd/system/lock@.service &&
    abort ERROR 'Failed to set the user id in lock service.'

  sudo systemctl enable lock@${USER}.service 2>&1 ||
    log WARN 'Unable to enable lock service.'
  
  log INFO 'Lock service has been enabled.'
  log INFO 'Locker has been updated.'
}

# Updates the default terminal and editor.
update_default_terminal_and_editor () {
  log INFO 'Updating the default terminal and editor...'
  
  sed -i \
    -e 's/#TERMINAL#/alacritty/' \
    -e 's/#EDITOR#/helix/' "/home/${USER}/.stackrc" ||
    abort ERROR 'Failed to set the terminal defaults.'
  
  log INFO 'Stackrc file has been updated.'
}

# Updates user and system services.
update_services () {
  log INFO 'Updating user and system services...'
  
  sed -i "s;#HOME#;/home/${USER};g" \
    "/home/${USER}/.config/systemd/user/fix-layout.service" ||
    abort ERROR 'Failed to set the home in fix layout service.'

  log INFO 'Services have been updated.'
}

# Restores the user permissions under the home directory.
restore_user_permissions () {
  chown -R ${USER}:${USER} "/home/${USER}" ||
    abort ERROR 'Failed to restore user permissions.'
  
  log INFO "Permissions under /home/${user} restored."
}

# Updates the stack hash file.
update_hash_file () {
  local branch=''
  branch="$(git branch --show-current)" ||
    abort ERROR 'Failed to read the current branch.'
  
  local commit=''
  commit="$(git log --pretty=format:'%H' -n 1)" ||
    abort ERROR 'Failed to read the last commit id.'
  
  echo "{\"branch\": \"${branch}\", \"commit\": \"${commit}\"}" | jq . |
    sudo tee /opt/stack/.hash &> /dev/null ||
    abort ERROR 'Failed to update the stack hash file.'
  
  log INFO "Stack hash file updated to ${branch}:${commit}."
}

if is_not_equal "${PWD}" '/tmp/stack'; then
  abort ERROR "Unable to run this script out of /tmp/stack."
fi

log INFO 'Starting the upgrade process...'

update_root_files &&
  update_commons &&
  update_tools &&
  update_release_data &&
  update_locker &&
  update_default_terminal_and_editor &&
  update_services &&
  restore_user_permissions &&
  update_hash_file

log INFO 'Upgrade process has been completed.'
log INFO 'Please reboot your system!'
