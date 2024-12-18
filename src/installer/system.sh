#!/bin/bash

set -Eeo pipefail

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh
source src/commons/math.sh

SETTINGS_FILE=./settings.json

# Sets up the root and sudoer user of the system.
set_users () {
  log INFO 'Setting up the system users...'

  local root_password=''
  root_password="$(jq -cer '.root_password' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read root_password setting.'

  echo "root:${root_password}" | chpasswd 2>&1 ||
    abort ERROR 'Failed to set password to root user.'

  log INFO 'Password has been given to root user.'

  groupadd stack ||
    abort ERROR 'Failed to create user group stack.'
  
  log INFO 'Stack user group has been created.'

  local groups='wheel,stack,audio,video,optical,storage'

  local vm=''
  vm="$(jq -cer '.vm' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the vm setting.'

  if is_yes "${vm}"; then
    groupadd 'libvirt' 2>&1
    groups="${groups},libvirt"

    log INFO 'Virtual machine libvirt user group has been created.'
  fi

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  useradd -m -G "${groups}" -s /bin/bash "${user_name}" 2>&1 &&
    chown -R ${user_name}:${user_name} "/home/${user_name}" ||
    abort ERROR 'Failed to create the sudoer user.'

  log INFO "Sudoer user ${user_name} has been created."

  local rule='%wheel ALL=(ALL:ALL) ALL'

  sed -i "s/^# \(${rule}\)/\1/" /etc/sudoers ||
    abort ERROR 'Failed to grant sudo permissions to wheel group.'

  if ! grep -q "^${rule}" /etc/sudoers; then
    abort ERROR 'Failed to grant sudo permissions to wheel group.'
  fi

  log INFO 'Sudo permissions have been granted to sudoer user.'

  local user_password=''
  user_password="$(jq -cer '.user_password' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_password setting.'

  echo "${user_name}:${user_password}" | chpasswd 2>&1 ||
    abort ERROR "Failed to set password to user ${user_name}."

  log INFO "Password has been given to user ${user_name}."
}

# Syncs root files to new system.
sync_root_files () {
  log INFO 'Syncing the root file system...'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'
  
  # Rename user home to align with the new system
  if not_equals "${user_name}" 'user'; then
    mv airootfs/home/user "airootfs/home/${user_name}" ||
      abort ERROR "Failed to rename home folder for ${user_name}."
  fi

  rsync -av airootfs/ / \
    --exclude usr/local/bin/stack ||
    abort ERROR 'Failed to sync the root file system.'
  
  chown -R ${user_name}:${user_name} "/home/${user_name}" ||
    abort ERROR 'Failed to restore user permissions.'

  log INFO 'Root file system has been synced.'
}

# Syncs the commons script files.
sync_commons () {
  log INFO 'Syncing the commons files...'

  mkdir -p /opt/stack ||
    abort ERROR 'Failed to create the /opt/stack folder.'

  rsync -av src/commons/ /opt/stack/commons ||
    abort ERROR 'Failed to sync the commons files.'
  
  sed -i 's;source src;source /opt/stack;' /opt/stack/commons/* ||
    abort ERROR 'Failed to fix source paths to /opt/stack.'
  
  log INFO 'Source paths fixed to /opt/stack.'
  log INFO 'Commons files have been synced.'
}

# Syncs the tools script files.
sync_tools () {
  log INFO 'Syncing the tools files...'

  mkdir -p /opt/stack ||
    abort ERROR 'Failed to create the /opt/stack folder.'

  rsync -av src/tools/ /opt/stack/tools ||
    abort ERROR 'Failed to sync the tools files.'
  
  sed -i 's;source src;source /opt/stack;' /opt/stack/tools/**/* ||
    abort ERROR 'Failed to fix source paths to /opt/stack.'
  
  log INFO 'Source paths fixed to /opt/stack.'

  # Create and restore all symlinks for every tool
  mkdir -p /usr/local/stack ||
    abort ERROR 'Failed to create the /usr/local/stack folder.'
  
  local main_files
  main_files=($(find /opt/stack/tools -type f -name 'main.sh')) ||
    abort ERROR 'Failed to get the list of main script file paths.'
  
  local main_file
  for main_file in "${main_files[@]}"; do
    # Extrack the tool handle name
    local tool_name=''
    tool_name="$(echo "${main_file}" | sed 's;/opt/stack/tools/\(.*\)/main.sh;\1;')" ||
      abort ERROR 'Failed to extract tool handle name.'

    ln -sf "${main_file}" "/usr/local/stack/${tool_name}" ||
      abort ERROR "Failed to create symlink for ${main_file} file."
  done

  log INFO 'Tools symlinks have been created.'
  log INFO 'Tools files have been synced.'
}

# Sets up the stack logs directories and permissions.
set_logs_home () {
  mkdir -p /var/log/stack /var/log/stack/tools &&
    chown -R :stack /var/log/stack &&
    chmod -R 775 /var/log/stack ||
    abort ERROR 'Failed to create /var/log/stack directories.'
  
  log INFO 'Log directories /var/log/stack have been created.'
}

# Sets the host name of the system.
set_host_name () {
  log INFO 'Setting the host name...'

  local host_name=''
  host_name="$(jq -cer '.host_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read host_name setting.'

  sed -i "s/#HOST_NAME#/${host_name}/" /etc/hostname ||
    abort ERROR 'Failed to set the host name.'

  log INFO "Host name has been set to ${host_name}."

  sed -i "s/#HOST_NAME#/${host_name}/" /etc/hosts ||
    abort ERROR 'Failed to add host name to hosts.'

  log INFO 'Host name has been added to hosts file.'
}

# Sets up the root and user shell environments.
set_bash () {
  log INFO 'Setting up the bash shell environment.'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local stackrc_file="/home/${user_name}/.stackrc"

  # Set the default terminal and text editor
  sed -i \
    -e 's/#TERMINAL#/alacritty/' \
    -e 's/#EDITOR#/helix/' "${stackrc_file}" ||
    abort ERROR 'Failed to set the terminal defaults.'

  log INFO 'Default terminal set to cool-retro-term.'
  log INFO 'Default editor set to helix.'

  local bashrc_file="/home/${user_name}/.bashrc"

  cp /etc/skel/.bashrc "${bashrc_file}" ||
    abort ERROR 'Failed to create the .bashrc file.'

  sed -i '/^PS1.*/d' "${bashrc_file}" &&
    echo 'source "${HOME}/.stackrc"' >> "${bashrc_file}" ||
    abort ERROR 'Failed to source .stackrc into .bashrc.'

  cp "/home/${user_name}/.stackrc" /root/.stackrc ||
    abort ERROR 'Failed to copy .stackrc for the root user.'

  cp /etc/skel/.bash_profile /root ||
    abort ERROR 'Failed to create root .bash_profile file.'
  
  bashrc_file='/root/.bashrc'

  cp /etc/skel/.bashrc "${bashrc_file}" ||
    abort ERROR 'Failed to create root .bashrc file.'

  sed -i '/^PS1.*/d' "${bashrc_file}" &&
    echo 'source "${HOME}/.stackrc"' >> "${bashrc_file}" ||
    abort ERROR 'Failed to source .stackrc into the root .bashrc.'
  
  log INFO 'Bash shell environment has been setup.'
}

# Sets the system locale along with the locale environment variables.
set_locales () {
  local locales=''
  locales="$(jq -cer '.locales' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read locales setting.'

  log INFO 'Generating system locales...'

  echo "${locales}" | jq -cer '.[]' >> /etc/locale.gen ||
    abort ERROR 'Failed to flush locales to locales.gen.'

  locale-gen 2>&1 ||
    abort ERROR 'Failed to generate system locales.'

  log INFO 'System locales have been generated.'

  # Set as system locale the locale selected first
  local locale=''
  locale="$(echo "${locales}" | jq -cer '.[0]' | cut -d ' ' -f 1)" ||
    abort ERROR 'Failed to read the default locale.'

  printf '%s\n' \
    "LANG=${locale}" \
    "LANGUAGE=${locale}:en:C" \
    "LC_CTYPE=${locale}" \
    "LC_NUMERIC=${locale}" \
    "LC_TIME=${locale}" \
    "LC_COLLATE=${locale}" \
    "LC_MONETARY=${locale}" \
    "LC_MESSAGES=${locale}" \
    "LC_PAPER=${locale}" \
    "LC_NAME=${locale}" \
    "LC_ADDRESS=${locale}" \
    "LC_TELEPHONE=${locale}" \
    "LC_MEASUREMENT=${locale}" \
    "LC_IDENTIFICATION=${locale}" \
    "LC_ALL=" | tee /etc/locale.conf > /dev/null ||
    abort ERROR 'Failed to set locale env variables.'

  # Unset previous set variables
  unset LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE \
        LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS \
        LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL ||
        abort ERROR 'Failed to unset locale variables.'
  
  # Save locale settings to the user config
  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local langs_file="/home/${user_name}/.config/stack/langs.json"

  local query=".locale = \"${locale}\" | .locales += \$lcs"

  local langs_settings=''
  langs_settings="$(jq -e --argjson lcs "${locales}" "${query}" "${langs_file}")" ||
    abort ERROR 'Failed to parse locale settings to json object.'

  echo "${langs_settings}" > "${langs_file}" &&
    chown -R ${user_name}:${user_name} "${langs_file}" ||
    abort ERROR 'Failed to save locales into the langs setting file.'
  
  log INFO 'Locales has been save into the langs settings.'
  log INFO "Locale has been set to ${locale}."
}

# Sets keyboard related settings.
set_keyboard () {
  log INFO 'Applying keyboard settings...'

  local keyboard_map=''
  keyboard_map="$(jq -cer '.keyboard_map' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read keyboard_map setting.'

  sed -i "s/#KEYMAP#/${keyboard_map}/" /etc/vconsole.conf ||
    abort ERROR 'Failed to add keymap to vconsole.'

  log INFO "Virtual console keymap set to ${keyboard_map}."

  loadkeys "${keyboard_map}" 2>&1 ||
    abort ERROR 'Failed to load keyboard map keys.'

  log INFO 'Keyboard map keys has been loaded.'

  local keyboard_model=''
  keyboard_model="$(jq -cer '.keyboard_model' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read keyboard_model setting.'

  local keyboard_options=''
  keyboard_options="$(jq -cer '.keyboard_options' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read keyboard_options setting.'

  local keyboard_layout=''
  keyboard_layout="$(jq -cer '.keyboard_layout' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read keyboard_layout setting.'
  
  local layout_variant=''
  layout_variant="$(jq -cer '.layout_variant' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read layout_variant setting.'

  # Save keyboard settings to the user config
  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'
  
  local langs_file="/home/${user_name}/.config/stack/langs.json"
  
  local query=''
  query+=".keymap = \"${keyboard_map}\" | "
  query+=".model = \"${keyboard_model}\" | "
  query+=".options = \"${keyboard_options}\" | "
  query+=".layouts = [{code: \"${keyboard_layout}\", variant: \"${layout_variant}\"}]"

  local langs_settings=''
  langs_settings="$(jq -e "${query}" "${langs_file}")" &&
    echo "${langs_settings}" > "${langs_file}" &&
    chown -R ${user_name}:${user_name} "${langs_file}" ||
    abort ERROR 'Failed to save keyboard to langs settings.'
  
  log INFO 'Keyboard saved to langs settings.'
  
  local keyboard_conf='/etc/X11/xorg.conf.d/00-keyboard.conf'

  # Make sure default variant is set blank for xorg configuration
  if equals "${layout_variant}" 'default'; then
    layout_variant=''
  fi

  sed -i \
    -e "s/#MODEL#/${keyboard_model}/" \
    -e "s/#OPTIONS#/${keyboard_options}/" \
    -e "s/#LAYOUTS#/${keyboard_layout}/" \
    -e "s/#VARIANTS#/${layout_variant}/" "${keyboard_conf}" ||
    abort ERROR 'Failed to set Xorg keyboard settings.'

  log INFO 'Xorg keyboard has been set.'
  log INFO 'Keyboard settings have been applied.'
}

# Sets the system timezone.
set_timezone () {
  log INFO 'Setting the system timezone...'

  local timezone=''
  timezone="$(jq -cer '.timezone' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read timezone setting.'

  ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime ||
    abort ERROR 'Failed to set the timezone.'

  log INFO "Timezone has been set to ${timezone}."

  local ntp_server='time.google.com'

  sed -i "s/^#NTP=/NTP=${ntp_server}/" /etc/systemd/timesyncd.conf ||
    abort ERROR 'Failed to set the NTP server.'

  log INFO "NTP server has been set to ${ntp_server}."

  hwclock --systohc --utc 2>&1 ||
    abort ERROR 'Failed to sync hardware to system clock.'

  log INFO 'Hardware clock has been synchronized to system clock.'
}

# Sets the os release data.
set_release_data () {
  local version=''
  version="$(date +%Y.%m.%d)" ||
    abort ERROR 'Failed to create version number.'

  sed -i "s/#VERSION#/${version}/" /etc/os-release ||
    abort ERROR 'Failed to set os release version.'
  
  ln -sf /etc/os-release /etc/stack-release ||
    abort ERROR 'Failed to create the stack-release symlink.'

  rm -f /etc/arch-release ||
    abort ERROR 'Unable to remove the arch-release file.'
  
  log INFO 'Release data have been set to stack linux.'
}

# Sets the pacman package databases mirrors.
set_mirrors () {
  log INFO 'Setting up package databases mirrors...'

  local mirrors=''
  mirrors="$(jq -cer '.mirrors|join(",")' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read mirrors setting.'

  reflector --country "${mirrors}" \
    --age 48 --sort age --latest 40 --save /etc/pacman.d/mirrorlist 2>&1 ||
    abort ERROR 'Unable to fetch package databases mirrors.'

  local conf_file='/etc/xdg/reflector/reflector.conf'

  sed -i \
    -e "s/# --country.*/--country ${mirrors}/" \
    -e 's/^--latest.*/--latest 40/' \
    -e '$a--age 48' "${conf_file}" ||
    abort ERROR 'Failed to save mirrors settings to reflector.'

  log INFO "Package databases mirrors set to ${mirrors}."
}

# Synchronizes the package databases to the master.
sync_package_databases () {
  log INFO 'Starting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    log WARN 'Package databases seem to be locked.'

    rm -f "${lock_file}" ||
      abort ERROR "Failed to remove the lock file ${lock_file}."

    log INFO "Lock file ${lock_file} has been removed."
  fi

  if ! grep -qe '^keyserver ' /etc/pacman.d/gnupg/gpg.conf; then
    local keyserver='hkp://keyserver.ubuntu.com'

    echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf ||
      abort ERROR 'Failed to add the GPG keyserver.'

    log INFO "GPG keyserver ${keyserver} has been added."
  fi

  pacman -Syy 2>&1 ||
    abort ERROR 'Failed to synchronize package databases.'

  log INFO 'Package databases synchronized to the master.'
}

# Installs hardware and system drivers.
install_drivers () {
  log INFO 'Installing system drivers...'

  local cpu_pkgs=''

  local cpu_vendor=''
  cpu_vendor="$(jq -cer '.cpu_vendor' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the cpu_vendor setting.'

  if equals "${cpu_vendor}" 'amd'; then
    cpu_pkgs='amd-ucode'
  elif equals "${cpu_vendor}" 'intel'; then
    cpu_pkgs='intel-ucode'
  fi

  local gpu_pkgs=''

  local gpu_vendor=''
  gpu_vendor="$(jq -cer '.gpu_vendor' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the gpu_vendor setting.'

  if equals "${gpu_vendor}" 'nvidia'; then
    local kernel=''
    kernel="$(jq -cer '.kernel' "${SETTINGS_FILE}")" ||
      abort ERROR 'Unable to read kernel setting.'

    if equals "${kernel}" 'stable'; then
      gpu_pkgs='nvidia'
    elif equals "${kernel}" 'lts'; then
      gpu_pkgs='nvidia-lts'
    fi

    gpu_pkgs+=' nvidia-utils nvidia-settings'
  elif equals "${gpu_vendor}" 'amd'; then
    gpu_pkgs='xf86-video-amdgpu'
  elif equals "${gpu_vendor}" 'intel'; then
    gpu_pkgs='libva-intel-driver libvdpau-va-gl vulkan-intel libva-utils'
  else
    gpu_pkgs='xf86-video-qxl'
  fi

  pacman -S --needed --noconfirm ${cpu_pkgs} ${gpu_pkgs} 2>&1 ||
    abort ERROR 'Failed to install system drivers.'

  log INFO 'System drivers have been installed.'
}

# Installs the base packages of the system.
install_base_packages () {
  log INFO 'Installing the base packages...'

  local pkgs=()
  pkgs+=($(grep -E '(stp|all):pac' packages.x86_64 | cut -d ':' -f 3)) ||
    abort ERROR 'Failed to read packages from packages.x86_64 file.'

  # Set yes as default to prompt on replacing conflicted packages
  local yes=4

  pacman -S --needed --noconfirm --ask ${yes} ${pkgs[@]} 2>&1 ||
    abort ERROR 'Failed to install base packages.'

  log INFO 'Base packages have been installed.'
}

# Installs the user repository package manager.
install_aur_package_manager () {
  log INFO 'Installing the AUR package manager...'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local yay_home="/home/${user_name}/yay"

  local previous_dir=${PWD}

  git clone https://aur.archlinux.org/yay.git "${yay_home}" 2>&1 &&
    chown -R ${user_name}:${user_name} "${yay_home}" &&
    cd "${yay_home}" &&
    sudo -u "${user_name}" makepkg -si --noconfirm 2>&1 &&
    cd "${previous_dir}" &&
    rm -rf "${yay_home}" ||
    abort ERROR 'Failed to install the AUR package manager.'

  log INFO 'AUR package manager has been installed.'
}

# Installs all the AUR packages the system depends on.
install_aur_packages () {
  log INFO 'Installing AUR packages...'

  local pkgs=()
  pkgs+=($(grep -E '(stp|all):aur' packages.x86_64 | cut -d ':' -f 3)) ||
    abort ERROR 'Failed to read packages from packages.x86_64 file.'
  
  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  sudo -u "${user_name}" yay -S --needed --noconfirm --removemake --mflags --nocheck ${pkgs[@]} 2>&1 ||
    abort ERROR 'Failed to install AUR packages.'

  log INFO 'AUR packages have been installed.'
}

# Sets up the Xorg display server packages.
setup_display_server () {
  log INFO 'Setting up the display server...'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local bash_profile_file="/home/${user_name}/.bash_profile"

  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "${bash_profile_file}" ||
    abort ERROR 'Failed to add startx hook to .bash_profile.'

  sed -ri '/^ExecStart=.*/i Environment=XDG_SESSION_TYPE=x11' \
    /usr/lib/systemd/system/getty@.service ||
    abort ERROR 'Failed to set getty to start X11 session after login.'

  log INFO 'Getty has been set to start X11 session after login.'
  log INFO 'Display server has been setup.'
}

# Setup the screen locker.
setup_screen_locker () {
  log INFO 'Setting up the screen locker...'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local xsecurelock_home="/home/${user_name}/xsecurelock"

  local previous_dir=${PWD}

  git clone https://github.com/tzeikob/xsecurelock.git "${xsecurelock_home}" 2>&1 &&
    cd "${xsecurelock_home}" &&
    sh autogen.sh 2>&1 &&
    ./configure --with-pam-service-name=system-auth 2>&1 &&
    make 2>&1 &&
    make install 2>&1 &&
    cd "${previous_dir}" &&
    rm -rf "${xsecurelock_home}" ||
    abort ERROR 'Failed to install xsecurelock.'
  
  log INFO 'Xsecurelock has been installed.'

  local user_id=''
  user_id="$(id -u "${user_name}" 2>&1)" ||
    abort ERROR 'Failed to get the user id.'

  local service_file='/etc/systemd/system/lock@.service'

  sed -i "s/#USER_ID#/${user_id}/g" "${service_file}" &&
    systemctl enable lock@${user_name}.service 2>&1 ||
    abort ERROR 'Failed to enable locker service.'

  log INFO 'Locker service has been enabled.'
  log INFO 'Screen locker has been setup.'
}

# Installs and configures the boot loader.
setup_boot_loader () {
  log INFO 'Setting up the boot loader...'

  local uefi_mode=''
  uefi_mode="$(jq -cer '.uefi_mode' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the uefi_mode setting.'

  if is_yes "${uefi_mode}"; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 2>&1 ||
      abort ERROR 'Failed to install grub boot loader on x86_64-efi.'
    
    log INFO 'Grub boot loader has been installed on x86_64-efi.'
  else
    local disk=''
    disk="$(jq -cer '.disk' "${SETTINGS_FILE}")" ||
      abort ERROR 'Unable to read disk setting.'

    grub-install --target=i386-pc "${disk}" 2>&1 ||
      abort ERROR 'Failed to install grub boot on i386-pc.'
    
    log INFO 'Grub boot loader has been installed on i386-pc.'
  fi

  log INFO 'Configuring the boot loader...'

  sed -ri \
    -e 's/(GRUB_CMDLINE_LINUX_DEFAULT=".*)"/\1 consoleblank=300"/' \
    -e 's/# *(GRUB_SAVEDEFAULT.*)/\1/' \
    -e '/GRUB_SAVEDEFAULT/i GRUB_DEFAULT=saved' \
    -e 's/# *(GRUB_DISABLE_SUBMENU.*)/\1/' /etc/default/grub ||
    abort ERROR 'Failed to set boot loader properties.'

  grub-mkconfig -o /boot/grub/grub.cfg 2>&1 ||
    abort ERROR 'Failed to create the boot loader config file.'

  log INFO 'Boot loader config file created successfully.'

  local vm_vendor=''
  vm_vendor="$(jq -cer '.vm_vendor//""' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the vm_vendor setting.'

  if is_yes "${uefi_mode}" && equals "${vm_vendor}" 'oracle'; then
    mkdir -p /boot/EFI/BOOT &&
      cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI ||
      abort ERROR 'Failed to copy the grubx64 efi file to BOOTX64.'
  fi

  log INFO 'Boot loader has been set up successfully.'
}

# Sets up the login screen.
setup_login_screen () {
  log INFO 'Setting up the login screen...'

  mv /etc/issue /etc/issue.bak ||
    abort ERROR 'Failed to backup the issue file.'

  log INFO 'The issue file has been backed up to /etc/issue.bak.'

  local host_name=''
  host_name="$(jq -cer '.host_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read host_name setting.'

  echo " ${host_name} " | figlet -f pagga 2>&1 > /etc/issue ||
    abort ERROR 'Failed to create the new issue file.'
  
  echo -e '\n' >> /etc/issue ||
    abort ERROR 'Failed to create the new issue file.'
  
  log INFO 'The new issue file has been created.'

  sed -ri \
    "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" \
    /lib/systemd/system/getty@.service ||
    abort ERROR 'Failed to set no hostname mode to getty service.'

  sed -ri \
    "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" \
    /lib/systemd/system/serial-getty@.service ||
    abort ERROR 'Failed to set no hostname mode to serial getty service.'

  log INFO 'Login screen has been setup.'
}

# Sets up the file manager.
setup_file_manager () {
  log INFO 'Setting up the file manager...'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local config_home="/home/${user_name}/.config/nnn"

  local previous_dir=${PWD}

  log INFO 'Installing file manager plugins...'

  local pluggins_url='https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs'

  curl "${pluggins_url}" -sSLo "${config_home}/getplugs" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    cd "/home/${user_name}" &&
    HOME="/home/${user_name}" sh "${config_home}/getplugs" 2>&1 &&
    cd "${previous_dir}" ||
    abort ERROR 'Failed to install extra plugins.'

  log INFO 'Extra plugins have been installed.'

  mkdir -p "/home/${user_name}"/{downloads,documents,data,sources,mounts} &&
    mkdir -p "/home/${user_name}"/{images,audios,videos} ||
    abort ERROR 'Failed to create home directories.'
  
  log INFO 'Home directories have been created.'
  log INFO 'File manager has been setup.'
}

# Sets up the desktop theme.
setup_theme () {
  log INFO 'Setting the desktop theme...'

  local theme_url='https://github.com/dracula/gtk/archive/master.zip'

  local themes_home='/usr/share/themes'

  curl "${theme_url}" -sSLo "${themes_home}/Dracula.zip" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    unzip -q "${themes_home}/Dracula.zip" -d "${themes_home}" 2>&1 &&
    mv "${themes_home}/gtk-master" "${themes_home}/Dracula" &&
    rm -f "${themes_home}/Dracula.zip" ||
    abort ERROR 'Failed to install theme files.'

  log INFO 'Theme files have been set.'

  local icons_url='https://github.com/dracula/gtk/files/5214870/Dracula.zip'

  local icons_home='/usr/share/icons'

  curl "${icons_url}" -sSLo "${icons_home}/Dracula.zip" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    unzip -q "${icons_home}/Dracula.zip" -d "${icons_home}" 2>&1 &&
    rm -f "${icons_home}/Dracula.zip" ||
    abort ERROR 'Failed to install icon files.'

  log INFO 'Icon files have been set.'

  local cursors_url='https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1'

  wget "${cursors_url}" -qO "${icons_home}/breeze-snow.tgz" \
    --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 3 2>&1 &&
    tar -xzf "${icons_home}/breeze-snow.tgz" -C "${icons_home}" 2>&1 &&
    sed -ri 's/Inherits=.*/Inherits=Breeze-Snow/' "${icons_home}/default/index.theme" &&
    rm -f "${icons_home}/breeze-snow.tgz" ||
    abort ERROR 'Failed to install cursors.'

  log INFO 'Cursors have been set.'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  sed -i \
    -e 's/#THEME#/Dracula/' \
    -e 's/#ICONS#/Dracula/' \
    -e 's/#CURSORS#/Breeze-Snow/' "/home/${user_name}/.config/gtk-3.0/settings.ini" ||
    abort ERROR 'Failed to set theme in GTK settings.'
  
  # Reset the cool-retro-term settings and profile
  bash /home/${user_name}/.config/cool-retro-term/reset "/home/${user_name}" ||
    abort ERROR 'Failed to reset the cool retro term theme.'
  
  log INFO 'Cool retro term theme has been reset.'

  log INFO 'Desktop theme has been setup.'
}

# Sets up the system fonts.
setup_fonts () {
  local fonts_home='/usr/share/fonts/extra-fonts'

  mkdir -p "${fonts_home}" ||
    abort ERROR 'Failed to create fonts home directory.'

  log INFO 'Setting up extra fonts...'

  local fonts=(
    "FiraCode https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"
    "FantasqueSansMono https://github.com/belluzj/fantasque-sans/releases/download/v1.8.0/FantasqueSansMono-Normal.zip"
    "Hack https://github.com/source-foundry/Hack/releases/download/v3.003/Hack-v3.003-ttf.zip"
    "Hasklig https://github.com/i-tu/Hasklig/releases/download/v1.2/Hasklig-1.2.zip"
    "JetBrainsMono https://github.com/JetBrains/JetBrainsMono/releases/download/v2.242/JetBrainsMono-2.242.zip"
    "Mononoki https://github.com/madmalik/mononoki/releases/download/1.3/mononoki.zip"
    "VictorMono https://rubjo.github.io/victor-mono/VictorMonoAll.zip"
    "PixelMix https://dl.dafont.com/dl/?f=pixelmix"
  )

  local font=''

  for font in "${fonts[@]}"; do
    local name=''
    name="$(echo "${font}" | cut -d ' ' -f 1)" ||
      abort ERROR 'Failed to read font name.'

    local url=''
    url="$(echo "${font}" | cut -d ' ' -f 2)" ||
      abort ERROR 'Failed to read font URL.'

    curl "${url}" -sSLo "${fonts_home}/${name}.zip" \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
      unzip -q "${fonts_home}/${name}.zip" -d "${fonts_home}/${name}" 2>&1 &&
      chmod -R 755 "${fonts_home}/${name}" &&
      rm -f "${fonts_home}/${name}.zip" ||
      abort ERROR "Failed to install font ${name}."

    log INFO "Font ${name} has been installed."
  done

  log INFO 'Installing google fonts...'

  local previous_dir=${PWD}

  git clone --filter=blob:none --sparse https://github.com/google/fonts.git /tmp/google-fonts 2>&1 &&
    cd /tmp/google-fonts &&
    git sparse-checkout add apache/cousine apache/robotomono ofl/sharetechmono ofl/spacemono 2>&1 &&
    cp -r apache/cousine apache/robotomono ofl/sharetechmono ofl/spacemono "${fonts_home}" &&
    cd "${previous_dir}" &&
    rm -rf /tmp/google-fonts ||
    abort ERROR 'Failed to install google fonts.'
  
  log INFO 'Google fonts have been installed.'

  log INFO 'Updating the fonts cache...'

  fc-cache -f 2>&1 ||
    abort ERROR 'Failed to update the fonts cache.'

  log INFO 'Fonts cache has been updated.'
  log INFO 'Extra glyphs have been installed.'
}

# Boost system performance on various tasks.
boost_performance () {
  log INFO 'Boosting system performance...'

  local cores=''
  cores="$(
    grep -c '^processor' /proc/cpuinfo 2>&1
  )" || abort ERROR 'Failed to read cpu data.'

  if is_not_integer "${cores}" '[1,]'; then
    abort ERROR 'Unable to resolve CPU cores.'
  fi

  local conf_file='/etc/makepkg.conf'

  sed -i \
  -e "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${cores}\"/g" \
  -e "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z --threads=${cores} -)/g" \
  -e "s/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=${cores} -)/g" "${conf_file}" ||
    abort ERROR 'Failed to set make options.'

  log INFO "Make flags set to ${cores} CPU cores."
  log INFO 'Compression threads have been set.'

  log INFO 'Increasing the limit of inotify watches...'

  local limit=524288
  echo "fs.inotify.max_user_watches=${limit}" >> /etc/sysctl.conf ||
    abort ERROR 'Failed to set the max limit of inotify watches.'

  sysctl --system 2>&1 ||
    abort ERROR 'Failed to update the max limit to inotify watches.'

  log INFO "Inotify watches limit has been set to ${limit}."
  log INFO 'Boosting has been completed.'
}

# Applies various system security settings.
configure_security () {
  log INFO 'Hardening system security...'

  local deny=3
  local fail_interval=180
  local unlock_time=120

  sed -ri \
    -e 's;# dir =.*;dir = /var/lib/faillock;' \
    -e "s;# deny =.*;deny = ${deny};" \
    -e "s;# fail_interval =.*;fail_interval = ${fail_interval};" \
    -e "s;# unlock_time =.*;unlock_time = ${unlock_time};" /etc/security/faillock.conf ||
    abort ERROR 'Failed to apply faillock settings.'
  
  log INFO 'Faillock file path set to /var/lib/faillock.'
  log INFO "Deny has been set to ${deny}."
  log INFO "Fail interval time set to ${fail_interval} secs."
  log INFO "Unlock time set to ${unlock_time} secs."

  sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config ||
    abort ERROR 'Failed to disable permit root login.'

  log INFO 'SSH login permission disabled for the root user.'
  log INFO 'Setting up a simple stateful firewall...'

  nft flush ruleset 2>&1 &&
    nft add table inet my_table 2>&1 &&
    nft add chain inet my_table my_input '{ type filter hook input priority 0 ; policy drop ; }' 2>&1 &&
    nft add chain inet my_table my_forward '{ type filter hook forward priority 0 ; policy drop ; }' 2>&1 &&
    nft add chain inet my_table my_output '{ type filter hook output priority 0 ; policy accept ; }' 2>&1 &&
    nft add chain inet my_table my_tcp_chain 2>&1 &&
    nft add chain inet my_table my_udp_chain 2>&1 &&
    nft add rule inet my_table my_input ct state related,established accept 2>&1 &&
    nft add rule inet my_table my_input iif lo accept 2>&1 &&
    nft add rule inet my_table my_input ct state invalid drop 2>&1 &&
    nft add rule inet my_table my_input meta l4proto ipv6-icmp accept 2>&1 &&
    nft add rule inet my_table my_input meta l4proto icmp accept 2>&1 &&
    nft add rule inet my_table my_input ip protocol igmp accept 2>&1 &&
    nft add rule inet my_table my_input meta l4proto udp ct state new jump my_udp_chain 2>&1 &&
    nft add rule inet my_table my_input 'meta l4proto tcp tcp flags & (fin|syn|rst|ack) == syn ct state new jump my_tcp_chain' 2>&1 &&
    nft add rule inet my_table my_input meta l4proto udp reject 2>&1 &&
    nft add rule inet my_table my_input meta l4proto tcp reject with tcp reset 2>&1 &&
    nft add rule inet my_table my_input counter reject with icmpx port-unreachable 2>&1 ||
    abort ERROR 'Failed to add NFT table rules.'

  mv /etc/nftables.conf /etc/nftables.conf.bak &&
    nft -s list ruleset > /etc/nftables.conf 2>&1 ||
    abort ERROR 'Failed to flush NFT tables rules.'

  log INFO 'Firewall ruleset has been flushed to /etc/nftables.conf.'

  # Save screen locker settings to the user config
  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" ||
    abort ERROR "Failed to create folder ${config_home}."

  local security_settings='{"screen_locker": {"interval": 12}}'

  local security_file="${config_home}/security.json"

  echo "${security_settings}" > "${security_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    abort ERROR 'Failed to set screen locker interval.'
  
  log INFO 'Screen locker inteval set to 12 mins.'
  log INFO 'Security configuration has been completed.'
}

# Restores the user home permissions.
restore_user_permissions () {
  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'
  
  chown -R ${user_name}:${user_name} "/home/${user_name}" ||
    abort ERROR 'Failed to restore user permissions.'
  
  log INFO 'User home permissions have been restored.'
}

# Enables system services.
enable_services () {
  log INFO 'Enabling system services...'

  systemctl enable systemd-timesyncd.service 2>&1 ||
    abort ERROR 'Failed to enable timesyncd service.'

  log INFO 'Service timesyncd has been enabled.'

  systemctl enable NetworkManager.service 2>&1 ||
    abort ERROR 'Failed to enable network manager service.'

  log INFO 'Service network manager has been enabled.'

  systemctl enable bluetooth.service 2>&1 ||
    abort ERROR 'Failed to enable bluetooth service.'

  log INFO 'Service bluetooth has been enabled.'

  systemctl enable acpid.service 2>&1 ||
    abort ERROR 'Failed to enable acpid service.'

  log INFO 'Service acpid has been enabled.'

  systemctl enable cups.service 2>&1 ||
    abort ERROR 'Failed to enable cups service.'

  log INFO 'Service cups has been enabled.'

  systemctl enable sshd.service 2>&1 ||
    abort ERROR 'Failed to enable sshd service.'
  
  log INFO 'Service sshd has been enabled.'

  systemctl enable nftables.service 2>&1 ||
    abort ERROR 'Failed to enable nftables service.'
  
  log INFO 'Service nftables has been enabled.'

  systemctl enable reflector.timer 2>&1 ||
    abort ERROR 'Failed to enable reflector.timer service.'

  log INFO 'Service reflector.timer has been enabled.'

  systemctl enable paccache.timer 2>&1 ||
    abort ERROR 'Failed to enable paccache.timer service.'

  log INFO 'Service paccache.timer has been enabled.'

  local trim_disk=''
  trim_disk="$(jq -cer '.trim_disk' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the trim_disk setting.'

  if is_yes "${trim_disk}"; then
    systemctl enable fstrim.timer 2>&1 ||
      abort ERROR 'Failed to enable fstrim.timer service.'
    
    log INFO 'Service fstrim.timer has been enabled.'
  fi

  local vm=''
  vm="$(jq -cer '.vm' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the vm setting.'
  
  local vm_vendor=''
  vm_vendor="$(jq -cer '.vm_vendor//""' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the vm_vendor setting.'

  if is_yes "${vm}" && equals "${vm_vendor}" 'oracle'; then
    systemctl enable vboxservice.service 2>&1 ||
      abort ERROR 'Failed to enable virtual box service.'

    log INFO 'Service virtual box has been enabled.'
  fi
  
  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'
  
  sed -i "s;#HOME#;/home/${user_name};g" \
    "/home/${user_name}/.config/systemd/user/fix-layout.service" ||
    abort ERROR 'Failed to set the home in fix layout service.'

  log INFO 'System services have been enabled.'
}

# Creates the stack hash file.
create_hash_file () {
  local branch=''
  branch="$(git branch --show-current)" ||
    abort ERROR 'Failed to read the current branch.'
  
  local commit=''
  commit="$(git log --pretty=format:'%H' -n 1)" ||
    abort ERROR 'Failed to read the last commit id.'
  
  mkdir -p /opt/stack ||
    abort ERROR 'Failed to create the /opt/stack folder.'
  
  echo "{\"branch\": \"${branch}\", \"commit\": \"${commit}\"}" |
    jq . > /opt/stack/.hash ||
    abort ERROR 'Failed to create the stack hash file.'
  
  log INFO "Stack hash file set to ${branch}:${commit}."
}

# Prints dummy log lines to fake tqdm progress bar, when a
# task gives less lines than it is expected to print and so
# it resolves with fake lines to emulate completion.
# Arguments:
#  total: the log lines the task is expected to print
# Outputs:
#  Fake dummy log lines.
resolve () {
  local total="${1}"

  local log_file='/var/log/stack/installer/system.log'

  local lines=0
  lines=$(cat "${log_file}" | wc -l)

  local fake_lines=0
  fake_lines=$(calc "${total} - ${lines}")

  seq ${fake_lines} | xargs -I -- echo '~'
}

log INFO 'Script system.sh started.'
log INFO 'Installing the system...'

if not_equals "$(id -u)" 0; then
  abort ERROR 'Script system.sh must be run as root user.'
fi

set_users &&
  sync_root_files &&
  sync_commons &&
  sync_tools &&
  set_logs_home &&
  set_host_name &&
  set_bash &&
  set_locales &&
  set_keyboard &&
  set_timezone &&
  set_release_data &&
  set_mirrors &&
  sync_package_databases &&
  install_drivers &&
  install_base_packages &&
  install_aur_package_manager &&
  install_aur_packages &&
  setup_display_server &&
  setup_screen_locker &&
  setup_boot_loader &&
  setup_login_screen &&
  setup_file_manager &&
  setup_theme &&
  setup_fonts &&
  boost_performance &&
  configure_security &&
  restore_user_permissions &&
  enable_services &&
  create_hash_file ||
  abort

log INFO 'Script system.sh has finished.'

resolve 4100 && sleep 2
