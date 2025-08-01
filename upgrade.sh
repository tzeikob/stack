#!/bin/bash

set -Eeo pipefail

if [[ "$(dirname "$(realpath -s "${0}")")" != "${PWD}" ]]; then
  echo 'Unable to run script out of its parent directory.'
  exit 1
fi

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh

# Syncs the package databases.
sync_package_databases () {
  log INFO 'Syncing the package databases...'

  sudo pacman -Syy 2>&1 ||
    abort ERROR 'Failed to synchronize package databases.'
  
  log INFO 'Package databases have been synced.'
}

# Installs or upgrades packages from the official repositories.
install_packages () {
  log INFO 'Installing official packages...'

  local pkgs=()
  pkgs+=($(grep -E '(stp|all):pac' packages.x86_64 | cut -d ':' -f 3)) ||
    abort ERROR 'Failed to read packages from packages.x86_64 file.'
  
  # Set yes as default to prompt on replacing conflicted packages
  local yes=4

  sudo pacman -S --needed --noconfirm --ask ${yes} ${pkgs[@]} 2>&1 ||
    abort ERROR 'Failed to install official packages.'

  log INFO 'Official packages have been installed.'
}

# Installs or upgrades packages from the AUR repositories.
install_aur_packages () {
  log INFO 'Installing AUR packages...'

  local pkgs=()
  pkgs+=($(grep -E '(stp|all):aur' packages.x86_64 | cut -d ':' -f 3)) ||
    abort ERROR 'Failed to read packages from packages.x86_64 file.'
  
  # Set yes as default to prompt on replacing conflicted packages
  local yes=4

  yay -S --needed --noconfirm --removemake --ask ${yes} ${pkgs[@]} 2>&1 ||
    abort ERROR 'Failed to install AUR packages.'
  
  log INFO 'AUR packages have been installed.'
}

# Installs or upgrades packages from third party source repositories.
install_source_packages () {
  local install_smenu
  install_smenu () {
    log INFO 'Installing smenu package...'

    local previous_dir=${PWD}

    git clone https://github.com/p-gen/smenu.git /tmp/smenu 2>&1 ||
      abort ERROR 'Failed to clone smenu git repository.'
    
    cd /tmp/smenu

    ./build.sh 2>&1 ||
      abort ERROR 'Failed to build smenu package.'
    
    sudo make install 2>&1 ||
      abort ERROR 'Failed to install smenu package.'
    
    cd ${previous_dir} && rm -rf /tmp/smenu
    
    log INFO 'Package smenu has been installed.'
  }

  log "Installing source packages..."
  
  install_smenu

  log "Source packages have been installed."
}

# Fixes global configuration variables.
fix_config_values () {
  local branch=''
  branch="$(git branch --show-current)" ||
    abort ERROR 'Failed to read the current branch.'

  local commit_date=''
  commit_date="$(git log -1 --format='%at' | jq -cer 'strftime("%Y-%m-%d")')" ||
    abort ERROR 'Failed to read the commit date'

  local commit=''
  commit="$(git log --pretty=format:'%H' -n 1)" ||
    abort ERROR 'Failed to read the last commit id.'

  local version="${commit_date} ${branch} ${commit:0:5}"
  
  sed -i "s;#VERSION#;${version};" airootfs/etc/os-release ||
    abort ERROR 'Failed to set release version.'
  
  log INFO "New release version set to ${version}."
  
  sed -i 's/#TERMINAL#/alacritty/' airootfs/home/user/.stackrc ||
    abort ERROR 'Failed to set default terminal.'
  
  log INFO 'Default terminal set to alacritty.'

  sed -i 's/#EDITOR#/helix/' airootfs/home/user/.stackrc ||
    abort ERROR 'Failed to set default editor.'
  
  log INFO 'Default editor set to helix.'
  
  local user_id=''
  user_id="$(id -u "${USER}" 2>&1)" ||
    abort ERROR 'Failed to get the user id.'

  sed -i "s/#USER_ID#/${user_id}/g" airootfs/etc/systemd/system/lock@.service ||
    abort ERROR 'Failed to set the user id in lock service.'

  log INFO "Lock user id set to ${user_id} for user ${USER}."

  sed -i "s;#HOME#;/home/${USER};g" \
    airootfs/home/user/.config/systemd/user/fix-layout.service ||
    abort ERROR 'Failed to set the home in fix layout service.'
  
  log INFO "Fix layout service home set to /home/${USER}."
}

# Fixes up the stack logs directories and permissions.
fix_logs_home () {
  sudo mkdir -p \
    /var/log/stack \
    /var/log/stack/tools \
    /var/log/stack/bars &&
    sudo chmod -R 775 /var/log/stack/tools &&
    sudo chmod -R 775 /var/log/stack/bars &&
    sudo chown -R :stack /var/log/stack ||
    abort ERROR 'Failed to set /var/log/stack directories.'
  
  log INFO 'Log directories /var/log/stack have been set.'
}

# Updates the root file system.
update_root_files () {
  log INFO 'Updating the root file system...'

  # Rename airootfs user home to align with the current system
  if not_equals "${USER}" 'user'; then
    mv airootfs/home/user "airootfs/home/${USER}" ||
      abort ERROR "Failed to rename user home for ${USER}."
  fi

  # Restore root privileged file system
  sudo chown -R root:root airootfs/etc airootfs/usr src/commons src/tools

  sudo rsync -av airootfs/ / \
    --exclude usr/local/bin/stack \
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
  local symlink_home='/usr/local/stack'

  sudo rm -rf "${symlink_home}" &&
    sudo mkdir "${symlink_home}" ||
    abort ERROR "Failed to create the ${symlink_home} folder."
  
  local main_files
  main_files=($(find /opt/stack/tools -type f -name 'main.sh')) ||
    abort ERROR 'Failed to get the list of main script file paths.'
  
  local main_file=''
  
  for main_file in "${main_files[@]}"; do
    # Extrack the tool handle name
    local tool_name=''
    tool_name="$(echo "${main_file}" | sed 's;/opt/stack/tools/\(.*\)/main.sh;\1;')" ||
      abort ERROR 'Failed to extract tool handle name.'

    sudo ln -sf "${main_file}" "${symlink_home}/${tool_name}" ||
      abort ERROR "Failed to create symlink for ${main_file} file."
  done

  log INFO 'Tools symlinks have been restored.'
  log INFO 'Tools files have been updated.'
}

# Fixes the root bash configuration and environment.
fix_root_bash () {
  log INFO 'Fixing root bash shell environment...'
  
  sudo cp "/home/${USER}/.prompt" /root ||
    abort ERROR 'Failed to copy root .prompt file.'
  
  log INFO 'Bash shell environment has been fixed.'
}

# Fixes user and system services.
fix_services () {
  log INFO 'Fixing user and system services...'

  sudo systemctl disable lock@${USER}.service 2>&1 ||
    log WARN 'Unable to disable lock service.'
    
  sudo systemctl enable lock@${USER}.service 2>&1 ||
    log WARN 'Unable to enable lock service.'
  
  log INFO 'Lock service has been fixed.'
  log INFO 'Services have been fixed.'
}

# Restores the user permissions under the home directory.
restore_user_permissions () {
  chown -R ${USER}:${USER} "/home/${USER}" ||
    abort ERROR 'Failed to restore user permissions.'
  
  log INFO "Permissions under /home/${user} restored."

  sudo chown -R root:root /tmp/.X11-unix ||
    abort ERROR 'Failed to restore xorg temp files permissions.'
  
  log INFO 'Xorg temp files permissions have been restored.'
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
  
  log INFO "Stack hash file updated to ${branch} [${commit:0:5}]."
}

log INFO 'Starting the upgrade process...'

sync_package_databases &&
  install_packages &&
  install_aur_packages &&
  install_source_packages &&
  fix_config_values &&
  fix_logs_home &&
  update_root_files &&
  update_commons &&
  update_tools &&
  fix_root_bash &&
  fix_services &&
  restore_user_permissions &&
  update_hash_file

log INFO 'Upgrade process has been completed.'
log INFO 'Please reboot your system!'
