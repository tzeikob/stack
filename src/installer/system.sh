#!/bin/bash

set -Eeo pipefail

source src/commons/process.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh

SETTINGS=./settings.json

# Syncs airoot files to new system.
sync_root_files () {
  log INFO 'Syncing the root file system...'

  rsync -av /stack/airootfs/ / ||
    abort ERROR 'Failed to sync the root file system.'
  
  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'
  
  # Rename user home to align with the new system
  if not_equals "${user_name}" 'user'; then
    mv /home/user "/home/${user_name}" ||
      abort ERROR "Failed to rename home folder for ${user_name}."
  fi
  
  log INFO 'Root file system has been synced.'
}

# Syncs the commons script files.
sync_commons () {
  log INFO 'Syncing the commons files...'

  mkdir -p /opt/stack ||
    abort ERROR 'Failed to create the /opt/stack folder.'

  rsync -av /stack/src/commons/ /opt/stack/commons ||
    abort ERROR 'Failed to sync the commons files.'
  
  sudo sed -i 's;source src;source /opt/stack;' /opt/stack/commons/* ||
    abort ERROR 'Failed to fix source paths to /opt/stack.'
  
  log INFO 'Source paths fixed to /opt/stack.'
  log INFO 'Commons files have been synced.'
}

# Syncs the tools script files.
sync_tools () {
  log INFO 'Syncing the tools files...'

  mkdir -p /opt/stack ||
    abort ERROR 'Failed to create the /opt/stack folder.'

  rsync -av /stack/src/tools/ /opt/stack/tools ||
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
    local tool_name
    tool_name="$(
      echo "${main_file}" | sed 's;/opt/stack/tools/\(.*\)/main.sh;\1;'
    )"

    sudo ln -sf "${main_file}" "/usr/local/stack/${tool_name}" ||
      abort ERROR "Failed to create symlink for ${main_file} file."
  done

  log INFO 'Tools symlinks have been created.'
  log INFO 'Tools files have been synced.'
}

# Fixes the os release data.
fix_release_data () {
  local version=''
  version="$(date +%Y.%m.%d)" ||
    abort ERROR 'Failed to create version number.'

  sed -i "s/#VERSION#/${version}/" /usr/lib/os-release ||
    abort ERROR 'Failed to set os release version.'
  
  ln -sf /usr/lib/os-release /etc/stack-release ||
    abort ERROR 'Failed to create the stack-release symlink.'

  rm -f /etc/arch-release ||
    abort ERROR 'Unable to remove the arch-release file.'
}

# Sets host related settings.
set_host () {
  log INFO 'Setting up the host...'

  local host_name=''
  host_name="$(jq -cer '.host_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read host_name setting.'

  sed -i "s/#HOST_NAME#/${host_name}/" /etc/hostname ||
    abort ERROR 'Failed to set the host name.'

  log INFO "Host name has been set to ${host_name}."

  sed -i "s/#HOST_NAME#/${host_name}/" /etc/hosts ||
    abort ERROR 'Failed to add host name to hosts.'

  log INFO 'Host name has been added to the hosts.'
}

# Sets up the root and sudoer users of the system.
set_users () {
  log INFO 'Setting up the system users...'

  local groups='wheel,audio,video,optical,storage'

  local vm=''
  vm="$(jq -cer '.vm' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the vm setting.'

  if is_yes "${vm}"; then
    groupadd 'libvirt' 2>&1
    groups="${groups},libvirt"
  fi

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
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
  user_password="$(jq -cer '.user_password' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_password setting.'

  echo "${user_name}:${user_password}" | chpasswd 2>&1 ||
    abort ERROR "Failed to set password to user ${user_name}."

  log INFO "Password has been given to user ${user_name}."

  local root_password=''
  root_password="$(jq -cer '.root_password' "${SETTINGS}")" ||
    abort ERROR 'Unable to read root_password setting.'

  echo "root:${root_password}" | chpasswd 2>&1 ||
    abort ERROR 'Failed to set password to root user.'

  log INFO 'Password has been given to the root user.'

  cp /etc/skel/.bash_profile /root ||
    abort ERROR 'Failed to create root .bash_profile file.'

  cp /etc/skel/.bashrc /root ||
    abort ERROR 'Failed to create root .bashrc file.'

  log INFO 'System users have been set up.'
}

# Sets the pacman package database mirrors.
set_mirrors () {
  log INFO 'Setting up package databases mirrors...'

  local mirrors=''
  mirrors="$(jq -cer '.mirrors|join(",")' "${SETTINGS}")" ||
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

# Configures pacman package manager.
configure_pacman () {
  log INFO 'Configuring the pacman manager...'

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf ||
    abort ERROR 'Failed to set parallel download.'

  log INFO 'Parallel download has been enabled.'

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf ||
    abort ERROR 'Failed to add the GPG keyserver.'

  log INFO "GPG keyserver has been set to ${keyserver}."
  log INFO 'Pacman manager has been configured.'
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

  pacman -Syy 2>&1 ||
    abort ERROR 'Failed to synchronize package databases.'

  log INFO 'Package databases synchronized to the master.'
}

# Installs the base packages of the system.
install_base_packages () {
  log INFO 'Installing the base packages...'

  local uefi_mode=''
  uefi_mode="$(jq -cer '.uefi_mode' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the uefi_mode setting.'

  local pkgs=()

  if is_yes "${uefi_mode}"; then
    pkgs+=(efibootmgr)
  fi

  pkgs+=($(grep -E '(stp|all):pac' /stack/packages.x86_64 | cut -d ':' -f 3)) ||
    abort ERROR 'Failed to read packages from packages.x86_64 file.'

  pacman -S --needed --noconfirm ${pkgs[@]} 2>&1 ||
    abort ERROR 'Failed to install base packages.'

  log INFO 'Replacing iptables with nft tables...'

  printf '%s\n' y y | pacman -S --needed nftables iptables-nft 2>&1 ||
    abort ERROR 'Failed to install the nft tables.'

  log INFO 'Iptables have been replaced by nft tables.'
  log INFO 'Base packages have been installed.'
}

# Installs the Xorg display server packages.
install_display_server () {
  log INFO 'Installing the display server...'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local bash_profile_file="/home/${user_name}/.bash_profile"

  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "${bash_profile_file}" ||
    abort ERROR 'Failed to add startx hook to .bash_profile.'

  sed -ri '/^ExecStart=.*/i Environment=XDG_SESSION_TYPE=x11' \
    /usr/lib/systemd/system/getty@.service ||
    abort ERROR 'Failed to set getty to start X11 session after login.'

  log INFO 'Getty has been set to start X11 session after login.'
  log INFO 'Display server has been installed.'
}

# Installs hardware and system drivers.
install_drivers () {
  log INFO 'Installing system drivers...'

  local cpu_pkgs=''

  local cpu_vendor=''
  cpu_vendor="$(jq -cer '.cpu_vendor' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the cpu_vendor setting.'

  if equals "${cpu_vendor}" 'amd'; then
    cpu_pkgs='amd-ucode'
  elif equals "${cpu_vendor}" 'intel'; then
    cpu_pkgs='intel-ucode'
  fi

  local gpu_pkgs=''

  local gpu_vendor=''
  gpu_vendor="$(jq -cer '.gpu_vendor' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the gpu_vendor setting.'

  if equals "${gpu_vendor}" 'nvidia'; then
    local kernel=''
    kernel="$(jq -cer '.kernel' "${SETTINGS}")" ||
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

  local other_pkgs=''

  local synaptics=''
  synaptics="$(jq -cer '.synaptics' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the synaptics setting.'

  if is_yes "${synaptics}"; then
    other_pkgs='xf86-input-synaptics'
  fi

  local vm_pkgs=''

  local vm=''
  vm="$(jq -cer '.vm' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the vm setting.'
  
  local vm_vendor=''
  vm_vendor="$(jq -cer '.vm_vendor' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the vm_vendor setting.'

  if is_yes "${vm}" && equals "${vm_vendor}" 'oracle'; then
    vm_pkgs='virtualbox-guest-utils'
  fi

  pacman -S --needed --noconfirm \
    ${cpu_pkgs} ${gpu_pkgs} ${other_pkgs} ${vm_pkgs} 2>&1 ||
    abort ERROR 'Failed to install system drivers.'

  log INFO 'System drivers have been installed.'
}

# Installs the user repository package manager.
install_aur_package_manager () {
  log INFO 'Installing the AUR package manager...'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local yay_home="/home/${user_name}/yay"

  git clone https://aur.archlinux.org/yay.git "${yay_home}" 2>&1 &&
    chown -R ${user_name}:${user_name} "${yay_home}" &&
    cd "${yay_home}" &&
    sudo -u "${user_name}" makepkg -si --noconfirm 2>&1 &&
    cd ~ &&
    rm -rf "${yay_home}" ||
    abort ERROR 'Failed to install the AUR package manager.'

  log INFO 'AUR package manager has been installed.'
}

# Sets the system locale along with the locale environment variables.
set_locales () {
  local locales=''
  locales="$(jq -cer '.locales' "${SETTINGS}")" ||
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
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" ||
    abort ERROR "Failed to create folder ${config_home}."

  local settings=''
  settings="$(echo "${locales}" | jq -e '{locale: .[0], locales: .}')" ||
    abort ERROR 'Failed to parse locale settings to JSON object.'

  local settings_file="${config_home}/langs.json"

  if file_exists "${settings_file}"; then
    settings="$(jq -e --argjson s "${settings}" '. + $s' "${settings_file}")" ||
      abort ERROR 'Failed to merge locales to langs settings.'
  fi

  echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    abort ERROR 'Failed to save locales into the langs setting file.'
  
  log INFO 'Locales has been save into the langs settings.'
  log INFO "Locale has been set to ${locale}."
}

# Sets keyboard related settings.
set_keyboard () {
  log INFO 'Applying keyboard settings...'

  local keyboard_map=''
  keyboard_map="$(jq -cer '.keyboard_map' "${SETTINGS}")" ||
    abort ERROR 'Unable to read keyboard_map setting.'

  sed -i "s/#KEYMAP#/${keyboard_map}/" /etc/vconsole.conf ||
    abort ERROR 'Failed to add keymap to vconsole.'

  log INFO "Virtual console keymap set to ${keyboard_map}."

  loadkeys "${keyboard_map}" 2>&1 ||
    abort ERROR 'Failed to load keyboard map keys.'

  log INFO 'Keyboard map keys has been loaded.'

  local keyboard_layout=''
  keyboard_layout="$(jq -cer '.keyboard_layout' "${SETTINGS}")" ||
    abort ERROR 'Unable to read keyboard_layout setting.'
  
  local keyboard_model=''
  keyboard_model="$(jq -cer '.keyboard_model' "${SETTINGS}")" ||
    abort ERROR 'Unable to read keyboard_model setting.'

  local keyboard_options=''
  keyboard_options="$(jq -cer '.keyboard_options' "${SETTINGS}")" ||
    abort ERROR 'Unable to read keyboard_options setting.'
  
  local keyboard_conf='/etc/X11/xorg.conf.d/00-keyboard.conf'

  sed -i \
    -e "s/#LAYOUT#/${keyboard_layout}/" \
    -e "s/#MODEL#/${keyboard_model}/" \
    -e "s/#OPTIONS#/${keyboard_options}/" "${keyboard_conf}" ||
    abort ERROR 'Failed to set Xorg keyboard settings.'
  
  local layout_variant=''
  layout_variant="$(jq -cer '.layout_variant' "${SETTINGS}")" ||
    abort ERROR 'Unable to read layout_variant setting.'

  if not_equals "${layout_variant}" 'default'; then
    sed -i \
      "/Option \"XkbLayout\"/a \ \ Option \"XkbVariant\" \"${layout_variant}\"" "${keyboard_conf}" ||
      abort ERROR 'Failed to set keyboard layout variant.'
  fi

  log INFO 'Xorg keyboard has been set.'

  # Save keyboard settings to the user config
  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'
  
  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" ||
    abort ERROR "Failed to create folder ${config_home}."

  local settings_file="${config_home}/langs.json"

  local settings=''
  settings="$(jq -cer . "${settings_file}")" ||
    abort ERROR 'Failed to read langs settings.'
  
  local query=''
  query+=".keymap = \"${keyboard_map}\" | "
  query+=".model = \"${keyboard_model}\" | "
  query+=".options = \"${keyboard_options} | "
  query+=".layouts[0].code =  \"${keyboard_layout}\" | "
  query+=".layouts[0].variant =  \"${layout_variant}\""

  settings="$(echo "${settings}" | jq -e "${query}")" &&
    echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    abort ERROR 'Failed to save keyboard to langs settings.'
  
  log INFO 'Keyboard saved to langs settings.'
  log INFO 'Keyboard settings have been applied.'
}

# Sets the system timezone.
set_system_timezone () {
  log INFO 'Setting the system timezone...'

  local timezone=''
  timezone="$(jq -cer '.timezone' "${SETTINGS}")" ||
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

  local badpass_msg='Sorry incorrect password!'
  local timeout=0
  local tries=2
  local prompt='Enter current password: '

  sed -i \
    -e "/maxseq/a Defaults badpass_message=\"${badpass_msg}\"" \
    -e "/maxseq/a Defaults passwd_timeout=${timeout}" \
    -e "/maxseq/a Defaults passwd_tries=${tries}" \
    -e "/maxseq/a Defaults passprompt=\"${prompt}\"" /etc/sudoers ||
    abort ERROR 'Failed to set sudo password settings.'
  
  log INFO 'Bad password message has been set.'
  log INFO "Password timeout interval set to ${timeout}."  
  log INFO "Password failed tries set to ${tries}."
  log INFO 'Password prompt has been set.'

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
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" ||
    abort ERROR "Failed to create folder ${config_home}."

  local settings='{"screen_locker": {"interval": 12}}'

  local settings_file="${config_home}/security.json"

  echo "${settings}" > "${settings_file}" &&
    chown -R ${user_name}:${user_name} "${config_home}" ||
    abort ERROR 'Failed to set screen locker interval.'
  
  log INFO 'Screen locker inteval set to 12 mins.'
  log INFO 'Security configuration has been completed.'
}

# Installs and configures the boot loader.
setup_boot_loader () {
  log INFO 'Setting up the boot loader...'

  local uefi_mode=''
  uefi_mode="$(jq -cer '.uefi_mode' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the uefi_mode setting.'

  if is_yes "${uefi_mode}"; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 2>&1 ||
      abort ERROR 'Failed to install grub boot loader on x86_64-efi.'
    
    log INFO 'Grub boot loader has been installed on x86_64-efi.'
  else
    local disk=''
    disk="$(jq -cer '.disk' "${SETTINGS}")" ||
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
  vm_vendor="$(jq -cer '.vm_vendor' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the vm_vendor setting.'

  if is_yes "${uefi_mode}" && equals "${vm_vendor}" 'oracle'; then
    mkdir -p /boot/EFI/BOOT &&
      cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI ||
      abort ERROR 'Failed to copy the grubx64 efi file to BOOTX64.'
  fi

  log INFO 'Boot loader has been set up successfully.'
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
  trim_disk="$(jq -cer '.trim_disk' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the trim_disk setting.'

  if is_yes "${trim_disk}"; then
    systemctl enable fstrim.timer 2>&1 ||
      abort ERROR 'Failed to enable fstrim.timer service.'
    
    log INFO 'Service fstrim.timer has been enabled.'
  fi

  local vm=''
  vm="$(jq -cer '.vm' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the vm setting.'
  
  local vm_vendor=''
  vm_vendor="$(jq -cer '.vm_vendor' "${SETTINGS}")" ||
    abort ERROR 'Failed to read the vm_vendor setting.'

  if is_yes "${vm}" && equals "${vm_vendor}" 'oracle'; then
    systemctl enable vboxservice.service 2>&1 ||
      abort ERROR 'Failed to enable virtual box service.'

    log INFO 'Service virtual box has been enabled.'
  fi
  
  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'
  
  sed -i "s;#HOME#;/home/${user_name};g" \
    "/home/${user_name}/.config/systemd/user/fix-layout.service" ||
    abort ERROR 'Failed to set the home in fix layout service.'

  log INFO 'System services have been enabled.'
}

# Creates the stack hash file.
create_hash_file () {
  cd /stack

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
  
  cd ~
  
  log INFO "Stack hash file set to ${branch}:${commit}."
}

log INFO 'Script system.sh started.'
log INFO 'Installing the system...'

if not_equals "$(id -u)" 0; then
  abort ERROR 'Script system.sh must be run as root user.'
fi

sync_root_files &&
  sync_commons &&
  sync_tools &&
  fix_release_data &&
  set_host &&
  set_users &&
  set_mirrors &&
  configure_pacman &&
  sync_package_databases &&
  install_base_packages &&
  install_display_server &&
  install_drivers &&
  install_aur_package_manager &&
  set_locales &&
  set_keyboard &&
  set_system_timezone &&
  boost_performance &&
  configure_security &&
  setup_boot_loader &&
  enable_services &&
  create_hash_file

log INFO 'Script system.sh has finished.'

resolve system 2060 && sleep 2
