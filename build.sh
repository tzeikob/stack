#!/bin/bash

set -o pipefail

DIST_DIR=.dist
WORK_DIR="${DIST_DIR}/work"
AUR_DIR="${DIST_DIR}/aur"
PROFILE_DIR="${DIST_DIR}/profile"
ROOT_FS="${PROFILE_DIR}/airootfs"

# Prints the given log message prefixed with the given log level.
# Options:
#  n:       print an empty line before, -nn 2 lines and so on
# Arguments:
#  level:   one of INFO, WARN, ERROR
#  message: a message to show
# Outputs:
#  Prints the message in <level> <message> form.
log () {
  local OPTIND opt

  while getopts ':n' opt; do
    case "${opt}" in
     'n') printf '\n';;
    esac
  done

  # Collect arguments
  shift $((OPTIND - 1))

  local level="${1}"
  local message="${2}"

  printf '%-5s %b\n' "${level}" "${message}"
}

# Aborts the current process logging the given error message.
# Arguments:
#  level:   one of INFO, WARN, ERROR
#  message: an error message to print
# Outputs:
#  An error messsage.
abort () {
  local level="${1}"
  local message="${2}"

  log "${level}" "${message}"
  log "${level}" 'Process has been exited.'

  exit 1
}

# Adds the package with the given name into the list of packages.
# Arguments:
#  name: the name of a package
add_package () {
  local name="${1}"

  local pkgs_file="${PROFILE_DIR}/packages.x86_64"

  if [[ ! -f "${pkgs_file}" ]]; then
    abort ERROR "Unable to locate file ${pkgs_file}."
  fi

  if ! grep -Eq "^${name}$" "${pkgs_file}"; then
    echo "${name}" >> "${pkgs_file}"
  else
    log WARN "Package ${name} already added."
  fi
}

# Removes the package with the given name from the list of packages.
# Arguments:
#  name: the name of a package
remove_package () {
  local name="${1}"

  local pkgs_file="${PROFILE_DIR}/packages.x86_64"

  if [[ ! -f "${pkgs_file}" ]]; then
    abort ERROR "Unable to locate file ${pkgs_file}."
  fi

  if ! grep -Eq "^${name}$" "${pkgs_file}"; then
    abort ERROR "Unable to remove the package ${name}."
  fi

  sed -Ei "/^${name}$/d" "${pkgs_file}" ||
    abort ERROR "Unable to remove the package ${name}."

  log INFO "Package ${name} has removed."
}

# Adds the given file prermissions to the given path.
# Arguments:
#  path:  the path to grant the permissions
#  perms: the file permissions, e.g. 755
add_file_permissions () {
  local path="${1}"
  local perms="${2}"

  local permissions_file="${PROFILE_DIR}/profiledef.sh"

  if [[ ! -f "${permissions_file}" ]]; then
    abort ERROR "Unable to locate file ${permissions_file}."
  fi

  sed -i "/file_permissions=(/a [\"${path}\"]=\"${perms}\"" "${permissions_file}" ||
    abort ERROR "Unable to add file permission ${perms} to ${path}."
  
  log INFO "Permission ${perms} added to ${path}."
}

# Initializes build and distribution files.
init () {
  if [[ -d "${DIST_DIR}" ]]; then
    rm -rf "${DIST_DIR}" || abort ERROR 'Unable to remove the .dist folder.'

    log WARN 'Existing .dist folder has been removed.'
  fi

  mkdir -p "${DIST_DIR}" || abort ERROR 'Unable to create the .dist folder.'

  log INFO 'A clean .dist folder has been created.'
}

# Checks if any build dependency is missing and abort immediately.
check_deps () {
  local deps=(archiso)

  local dep=''
  for dep in "${deps[@]}"; do
    if ! pacman -Qi "${dep}" > /dev/null 2>&1; then
      abort ERROR "Package dependency ${dep} is not installed."
    fi
  done
}

# Copies the archiso custom profile.
copy_profile_files () {
  log INFO 'Copying the releng archiso profile...'

  local releng_path='/usr/share/archiso/configs/releng'

  if [[ ! -d "${releng_path}" ]]; then
    abort ERROR 'Unable to locate releng archiso profile.'
  fi

  rsync -av "${releng_path}/" "${PROFILE_DIR}" ||
    abort ERROR 'Unable to copy the releng archiso profile.'

  log INFO "The releng profile copied to ${PROFILE_DIR}."
}

# Copies the stack root file system to the profile.
copy_stack_files () {
  log INFO 'Copying the stack file system...'

  rsync -av airootfs/ "${ROOT_FS}" ||
    abort ERROR 'Failed to copy the stack root file system.'
  
  rsync -av "${ROOT_FS}/home/user/" "${ROOT_FS}/root" &&
    rm -rf "${ROOT_FS}/home/user" ||
    abort ERROR 'Failed to sync stack home to root home.'
  
  log INFO 'Stack file system has been copied.'
}

# Sets the distribution names and release meta files.
rename_distro () {
  local name='stackiso'

  sed -i "s/#NAME#/${name}/" "${ROOT_FS}/etc/hostname" ||
    abort ERROR 'Failed to set the host name.'
  
  log INFO "Host name set to ${name}."

  local version=''
  version="$(date +%Y.%m.%d)" || abort ERROR 'Failed to create version number.'

  sed -i "s/#DATE#/${version}/" "${ROOT_FS}/etc/stack-release" ||
    aboirt ERROR 'Failed to set build version.'

  local profile_def="${PROFILE_DIR}/profiledef.sh"

  sed -i \
    -e 's|^\(iso_name=\).*|\1\"stacklinux\"|' \
    -e 's|^\(iso_label="\)ARCH_\(.*\)|\1STACK_\2|' \
    -e 's|^\(iso_publisher=\).*|\1\"Stack Linux <https://github.com/tzeikob/stack.git>\"|' \
    -e 's|^\(iso_application=\).*|\1\"Stack Linux Live Media\"|' \
    -e 's|^\(install_dir=\).*|\1\"stack\"|' "${profile_def}" ||
    abort ERROR 'Failed to update release info in the profile definition file.'

  log INFO 'Release info updated in profile definition file.'
}

# Fixes bios and uefi boot loaders.
fix_boot_loaders () {
  local efiboot="${PROFILE_DIR}/efiboot/loader/entries"

  sed -i 's/Arch/Stack/' "${efiboot}/01-archiso-x86_64-linux.conf" ||
    abort ERROR 'Failed to fix texts in EFI boot menus.'
  
  rm -rf "${efiboot}/02-archiso-x86_64-speech-linux.conf" ||
    abort ERROR 'Failed to remove speech entry from EFI boot menus.'
  
  log INFO 'EFI boot menus have been fixed.'

  local syslinux="${PROFILE_DIR}/syslinux"

  rm -f \
    "${syslinux}/archiso_pxe.cfg" \
    "${syslinux}/archiso_pxe-linux.cfg" ||
    abort ERROR 'Failed to remove PXE syslinux config files.'
  
  sed -i \
    -e 's/APPEND -pxe- pxe -sys- sys -iso- sys/APPEND -sys- sys -iso- sys/' \
    -e '/LABEL pxe/,+3d' "${syslinux}/syslinux.cfg" ||
    abort ERROR 'Failed to remove PXE bios modes from syslinux.'

  log INFO 'PXE bios modes have been removed from syslinux.'

  sed -i \
    -e 's/Arch/Stack/' \
    -e '/# Accessibility boot option/,$d' \
    -e '/TEXT HELP/,/ENDTEXT/d' "${syslinux}/archiso_sys-linux.cfg" ||
    abort ERROR 'Failed to fix texts in syslinux menu.'

  sed -i \
    -e '/LABEL existing/,+9d' \
    -e '/TEXT HELP/,/ENDTEXT/d' "${syslinux}/archiso_tail.cfg" ||
    abort ERROR 'Failed to fix texts in syslinux menu.'
  
  rm -rf "${syslinux}/splash.png" ||
    abort ERROR 'Failed to remove the splash screen file.'

  printf '%s\n' \
    'SERIAL 0 115200' \
    'UI vesamenu.c32' \
    'MENU TITLE Stack Linux Live Media' \
    'MENU BACKGROUND #ff000000' \
    'MENU WIDTH 78' \
    'MENU MARGIN 4' \
    'MENU ROWS 6' \
    'MENU VSHIFT 6' \
    'MENU TABMSGROW 14' \
    'MENU CMDLINEROW 14' \
    'MENU HELPMSGROW 16' \
    'MENU HELPMSGENDROW 29' \
    'MENU COLOR border       0     #ffffffff #00000000 none' \
    'MENU COLOR title        37;40 #ffffffff #00000000 none' \
    'MENU COLOR sel          37;40 #ff000000 #ffffffff none' \
    'MENU COLOR unsel        37;40 #ffffffff #00000000 none' \
    'MENU COLOR help         37;40 #ffffffff #00000000 none' \
    'MENU COLOR timeout_msg  37;40 #ffffffff #00000000 none' \
    'MENU COLOR timeout      37;40 #ffffffff #00000000 none' \
    'MENU COLOR msg07        37;40 #ffffffff #00000000 none' \
    'MENU COLOR tabmsg       37;40 #ffffffff #00000000 none' \
    'MENU CLEAR' \
    'MENU IMMEDIATE' > "${syslinux}/archiso_head.cfg" ||
    abort ERROR 'Failed to fix styles and colors in syslinux menus.'

  log INFO 'Syslinux boot loader menus have been modified.'

  local grub="${PROFILE_DIR}/grub"

  sed -i \
    -e "/--id 'archlinux-accessibility'/,+5d" \
    -e 's/archlinux/stacklinux/' \
    -e 's/Arch Linux/Stack Linux/' "${grub}/grub.cfg" ||
    abort ERROR 'Failed to fix texts in grub menus.'

  sed -i \
    -e "/--id 'archlinux-accessibility'/,+5d" \
    -e 's/archlinux/stacklinux/' \
    -e 's/Arch Linux/Stack Linux/' "${grub}/loopback.cfg" ||
    abort ERROR 'Failed to fix texts in loopback grub menus.'

  log INFO 'Grub boot loader menus have been modified.'

  sed -i '/if serial --unit=0 --speed=115200; then/,+3d' "${grub}/grub.cfg" ||
    abort ERROR 'Failed to disable the serial console in grub.'

  log INFO 'Grub boot loader serial console disabled.'
}

# Define package dependencies into the list of packages.
define_packages () {
  log INFO 'Adding system and desktop packages...'

  local pkgs=()

  # Add the base and system packages
  pkgs+=(
    reflector rsync sudo
    base-devel pacman-contrib pkgstats grub mtools dosfstools ntfs-3g exfatprogs gdisk fuseiso veracrypt
    python-pip parted curl wget udisks2 udiskie gvfs gvfs-smb bash-completion
    man-db man-pages texinfo cups cups-pdf cups-filters usbutils bluez bluez-utils unzip terminus-font
    vim nano git tree arch-audit atool zip xz unace p7zip gzip lzop feh hsetroot
    bzip2 unrar dialog inetutils dnsutils openssh nfs-utils ipset xsel
    neofetch age imagemagick gpick fuse2 rclone smartmontools glib2 jq jc sequoia-sq xf86-input-wacom
    cairo bc xdotool python-tqdm libqalculate nftables iptables-nft virtualbox-guest-utils
  )
  
  # Add the display server and graphics packages
  pkgs+=(
    xorg xorg-xinit xorg-xrandr xorg-xdpyinfo xf86-video-qxl
  )

  # Add various hardware and driver packages
  pkgs+=(
    acpi acpi_call acpid tlp xcalib
    networkmanager networkmanager-openvpn wireless_tools netctl wpa_supplicant
    nmap dhclient smbclient libnma alsa-utils xf86-input-synaptics
  )

  # Add the desktop prerequisite packages
  pkgs+=(
    picom bspwm sxhkd polybar rofi dunst
    trash-cli cool-retro-term helix firefox torbrowser-launcher
    irssi ttf-font-awesome noto-fonts-emoji
  )

  local pkg=''
  for pkg in "${pkgs[@]}"; do
    add_package "${pkg}"
  done

  # Remove conflicting nox server virtualbox utils
  remove_package virtualbox-guest-utils-nox

  log INFO 'Packages defined in the package list.'
}

# Builds and adds the AUR packages into the packages list
# via a local custom repo.
build_aur_packages () {
  log INFO 'Building the AUR package files...'

  local previous_dir=${PWD}

  local repo_home="${PROFILE_DIR}/local/repo"

  mkdir -p "${repo_home}" || abort ERROR 'Failed to create the local repo folder.'

  local names=(
    yay smenu xkblayout-state-git
  )

  local name=''
  for name in "${names[@]}"; do
    # Build the next AUR package
    git clone "https://aur.archlinux.org/${name}.git" "${AUR_DIR}/${name}" ||
      abort ERROR "Failed to clone the AUR ${name} package repo."
  
    cd "${AUR_DIR}/${name}"
    makepkg || abort ERROR "Failed to build the AUR ${name} package."
    cd ${previous_dir}

    # Create the custom local repo database
    cp ${AUR_DIR}/${name}/${name}-*-x86_64.pkg.tar.zst "${repo_home}" &&
      repo-add "${repo_home}/custom.db.tar.gz" ${repo_home}/${name}-*-x86_64.pkg.tar.zst ||
      abort ERROR "Failed to add the ${name} package into the custom repository."

    add_package "${name}" || abort ERROR "Failed to add the ${name} AUR package."

    log INFO "Package ${name} has been built."
  done

  rm -rf "${AUR_DIR}" || abort ERROR 'Failed to remove the AUR temporary folder.'

  local pacman_conf="${PROFILE_DIR}/pacman.conf"

  printf '%s\n' \
    '' \
    '[custom]' \
    'SigLevel = Optional TrustAll' \
    "Server = file://$(realpath "${repo_home}")" >> "${pacman_conf}" ||
    abort ERROR 'Failed to define the custom local repo.'

  log INFO 'Custom local repo added to pacman.'
  log INFO 'AUR packages added in the package list.'
}

# Removes system tools unnecessary to live media.
remove_unnecessary_tools () {
  local tools=(audio cloud security system)
  
  local tool=''
  for tool in "${tools[@]}"; do
    rm -rf "${ROOT_FS}/opt/stack/tools/${tool}" ||
      abort ERROR "Failed to remove the ${tool} system tool."
    
    rm -f "${ROOT_FS}/usr/local/bin/${tool}" ||
      abort ERROR "Failed to remove the ${tool} system tool symlink."
    
    log INFO "System tool ${tool} has been removed."
  done

  # Disable init scratchpad command for the live media
  local desktop_main="${ROOT_FS}/opt/stack/tools/desktop/main.sh"

  sed -i "/.*scratchpad.*/d" "${desktop_main}" ||
    abort ERROR 'Failed to remove scratchpad from desktop tool.'

  log INFO 'Scratchpad has been removed from desktop tool.'
}

# Copies the files of the installer.
copy_installer () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    abort ERROR 'Unable to locate the airootfs folder.'
  fi

  local installer_home="${ROOT_FS}/opt/stack/installer"

  mkdir -p "${installer_home}" ||
    abort ERROR 'Failed to create the /opt/stack/installer folder.'

  cp -r assets "${installer_home}" &&
    cp -r configs "${installer_home}" &&
    cp -r services "${installer_home}" &&
    cp -r src/tools "${installer_home}" &&
    cp -r src/installer/* "${installer_home}" ||
    abort ERROR 'Failed to copy the installer files.'

    add_file_permissions '/opt/stack/installer/apps.sh' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/askme.sh' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/bootstrap.sh' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/cleaner.sh' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/desktop.sh' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/detection.sh' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/diskpart.sh' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/run.sh' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/stack.sh' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/system.sh' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/tools/' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/configs/bspwm/' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/configs/dunst/hook' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/configs/nnn/env' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/configs/polybar/scripts/' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/configs/rofi/launch' '0:0:755' &&
      add_file_permissions '/opt/stack/installer/configs/xsecurelock/hook' '0:0:755' ||
      abort ERROR 'Failed to add file permissions to /opt/stack/installer.'

  # Create a global alias to launch the installer
  local bin_home="${ROOT_FS}/usr/local/bin"

  mkdir -p "${bin_home}" || abort ERROR 'Failed to create the /usr/local/bin folder.'

  ln -sf /opt/stack/installer/run.sh "${bin_home}/install_os" ||
    abort ERROR 'Failed to create the symlink to the installer launcher.'

  # Save the current branch and commit id in a hash file
  local branch=''
  branch="$(git branch --show-current)" ||
    abort ERROR 'Unable to retrieve the current branch name.'

  local commit_id=''
  commit_id="$(git log -1 --pretty=format:"%H")" ||
    abort ERROR 'Unable to retrieve the last commit id.'

  echo "{\"branch\": \"${branch}\", \"commit_id\": \"${commit_id}\"}" > "${installer_home}/.hash"

  log INFO 'Installer files have been copied.'
}

# Sets to skip login prompt and auto login the root user.
setup_auto_login () {
  local auto_login="${ROOT_FS}/etc/systemd/system/getty@tty1.service.d/autologin.conf"

  local exec_start="ExecStart=-/sbin/agetty -o '-p -f -- \\\\\\\u' --noissue --noclear --skip-login --autologin root - \$TERM"

  sed -i "s;^ExecStart=-/sbin/agetty.*;${exec_start};" "${auto_login}" ||
    abort ERROR 'Failed to set skip on login prompt.'

  log INFO 'Login prompt set to skip and autologin.'

  # Remove the default welcome message
  rm -rf "${ROOT_FS}/etc/motd" || abort ERROR 'Failed to remove the /etc/motd file.'

  log INFO 'Default /etc/motd file removed.'
}

# Sets up the display server configuration and hooks.
setup_display_server () {
  local xinitrc_file="${ROOT_FS}/root/.xinitrc"

  # Keep functionality related only to live media
  sed -i \
    -e '/system -qs check updates &/d' \
    -e '/displays -qs restore layout/d' \
    -e '/displays -qs restore colors &/d' \
    -e '/security -qs init locker &/d' \
    -e '/cloud -qs mount remotes &/d' "${xinitrc_file}" ||
    abort ERROR 'Failed to remove unsupported calls from .xinitrc.'

  log INFO 'Unsupported calls removed from .xinitrc.'

  local zlogin_file="${ROOT_FS}/root/.zlogin"

  printf '%s\n' \
    '' \
    "echo -e 'Starting desktop environment...'" \
    'startx' >> "${zlogin_file}" ||
     abort ERROR 'Failed to add startx hook to .zlogin.'

  log INFO 'Xorg server set to be started at login.'
}

# Sets up the shell environment.
setup_shell_environment () {
  local zshrc_file="${ROOT_FS}/root/.zshrc"

  # Set the defauilt terminal and text editor
  echo -e 'export TERMINAL=cool-retro-term' >> "${zshrc_file}"

  log INFO 'Default terminal set to cool-retro-term.'

  echo -e 'export EDITOR=helix' >> "${zshrc_file}"

  log INFO 'Default editor set to helix.'

  # Set up trash-cli aliases
  echo -e "\nalias sudo='sudo '" >> "${zshrc_file}"
  echo "alias tt='trash-put -i'" >> "${zshrc_file}"
  echo "alias rm='rm -i'" >> "${zshrc_file}"

  log INFO 'Command aliases added to /root/.zshrc.'

  echo 'source ~/.prompt' >> "${zshrc_file}"

  printf '%s\n' \
    '' \
    'if [[ "${SHOW_WELCOME_MSG}" == "true" ]]; then' \
    '  cat /etc/welcome' \
    'fi' >> "${zshrc_file}" ||
    abort ERROR 'Failed to add the welcome message hook call.'

  log INFO 'Welcome message set to be shown after login.'
}

# Sets up the corresponding desktop configurations.
setup_desktop () {
  log INFO 'Setting up desktop configurations...'

  local config_home="${ROOT_FS}/root/.config"

  local bspwm_home="${config_home}/bspwm"

  rm -f "${bspwm_home}/scratchpad" ||
    abort ERROR 'Failed to remove scratchpad bspwm script.'

  sed -i \
    -e '/desktop -qs init scratchpad &/d' \
    -e '/bspc rule -a scratch sticky=off state=floating hidden=on/d' "${bspwm_home}/bspwmrc" ||
    abort ERROR 'Failed to remove the scratchpad lines from the .bspwmrc file.'

  # Add a hook to open the welcome terminal once at login
  printf '%s\n' \
    '[ "$@" -eq 0 ] && {' \
    '  SHOW_WELCOME_MSG=true cool-retro-term &' \
    '}' >> "${bspwm_home}/bspwmrc" ||
    abort ERROR 'Failed to add the welcome hook to .bspwmrc.'

  log INFO 'Bspwm welcome hook has been set.'

  local polybar_home="${config_home}/polybar"

  # Remove polybar modules not needed on live media
  sed -i \
    -e "s/\(modules-right = \)cpu.*/\1 alsa-audio date time/" \
    -e "s/\(modules-right = \)notifications.*/\1 flash-drives keyboard/" \
    -e "s/\(modules-left = \)wlan.*/\1 wlan eth/" "${polybar_home}/config.ini" ||
    abort ERROR 'Failed to remove not supported polybar bars.'

  # Remove unnecessary polybar scripts from live media
  local scripts=(bluetooth cpu memory notifications power remotes updates)

  local script=''
  for script in "${scripts[@]}"; do
    rm -f "${polybar_home}/scripts/${script}" ||
      abort ERROR "Failed to remove polybar script ${script}."
    
    log INFO "Polybar script ${script} has removed."
  done

  local sxhkdrc_file="${config_home}/sxhkd/sxhkdrc"

  # Remove unnecessary key bindings not needed on live media
  sed -i \
    -e '/# Lock the screen./,+3d' \
    -e '/# Take a screen shot./,+3d' \
    -e '/# Start recording your screen./,+3d' \
    -e '/# Show and hide the scratchpad termimal./,+3d' "${sxhkdrc_file}" ||
    abort ERROR 'Failed to remove not supported key bindings.'

  log INFO 'Sxhkd configuration has been set.'

  local rofi_launch="${config_home}/rofi/launch"

  sed -i \
    -e "/options+='Lock\\\n'/d" \
    -e "/options+='Blank\\\n'/d" \
    -e "/options+='Logout'/d" \
    -e "s/\(  local exact_lines='listview {lines:\) 6\(;}'\)/\1 3\2/" \
    -e "/'Lock') security -qs lock screen;;/d" \
    -e "/'Blank') power -qs blank;;/d" \
    -e "/'Logout') security -qs logout user;;/d" "${rofi_launch}" ||
    abort ERROR 'Failed to remove unnecessary rofi launchers.'

  log INFO 'Rofi configuration has been set.'

  # Remove unnecessary configurations from live media
  local names=(allacritty mpd ncmpcpp nnn xsecurelock)

  local name=''
  for name in "${names[@]}"; do
    rm -rf "${ROOT_FS}/root/.config/${name}" ||
      abort ERROR "Failed to remove configuration ${name}."
    
    log INFO "Configuration files of ${name} have been removed."
  done

  rm -f "${ROOT_FS}/etc/systemd/system/lock@.service" ||
    abort ERROR 'Failed to remove lock service.'
  
  log INFO 'Lock service has been removed.'
}

# Sets up the theme of the desktop environment.
setup_theme () {
  log INFO 'Setting up the desktop theme...'

  local themes_home="${ROOT_FS}/usr/share/themes"

  mkdir -p "${themes_home}" ||
    abort ERROR 'Failed to create the themes folder.'

  local theme_url='https://github.com/dracula/gtk/archive/master.zip'

  curl "${theme_url}" -sSLo "${themes_home}/Dracula.zip" &&
    unzip -q "${themes_home}/Dracula.zip" -d "${themes_home}" &&
    mv "${themes_home}/gtk-master" "${themes_home}/Dracula" &&
    rm -f "${themes_home}/Dracula.zip" ||
    abort ERROR 'Failed to install the desktop theme.'
  
  sed -i 's/#THEME#/Dracula/' "${ROOT_FS}/root/.config/gtk-3.0/settings.ini" ||
    abort ERROR 'Failed to set theme in GTK settings.'

  log INFO 'Desktop theme dracula has been installed.'

  log INFO 'Setting up the desktop icons...'

  local icons_home="${ROOT_FS}/usr/share/icons"

  mkdir -p "${icons_home}" ||
    abort ERROR 'Failed to create the icons folder.'
  
  local icons_url='https://github.com/dracula/gtk/files/5214870/Dracula.zip'

  curl "${icons_url}" -sSLo "${icons_home}/Dracula.zip" &&
    unzip -q "${icons_home}/Dracula.zip" -d "${icons_home}" &&
    rm -f "${icons_home}/Dracula.zip" ||
    abort ERROR 'Failed to install the desktop icons.'
  
  sed -i 's/#ICONS#/Dracula/' "${ROOT_FS}/root/.config/gtk-3.0/settings.ini" ||
    abort ERROR 'Failed to set icons in GTK settings.'

  log INFO 'Desktop icons dracula have been installed.'

  log INFO 'Setting up the desktop cursors...'

  local cursors_home="${ROOT_FS}/usr/share/icons"

  mkdir -p "${cursors_home}" ||
    abort ERROR 'Failed to create the cursors folder.'

  local cursors_url='https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1'

  wget "${cursors_url}" -qO "${cursors_home}/breeze-snow.tgz" &&
    tar -xzf "${cursors_home}/breeze-snow.tgz" -C "${cursors_home}" &&
    rm -f "${cursors_home}/breeze-snow.tgz" ||
    abort ERROR 'Failed to install the desktop cursors.'

  mkdir -p "${cursors_home}/default" ||
    abort ERROR 'Failed to create the cursors default folder.'

  print '%s\n' \
    '[Icon Theme]' \
    'Inherits=Breeze-Snow' >> "${cursors_home}/default/index.theme" ||
    abort ERROR 'Failed to set the default index theme.'

  sed -i 's/#CURSORS#/Breeze-Snow/' "${ROOT_FS}/root/.config/gtk-3.0/settings.ini" ||
    abort ERROR 'Failed to set cursors in GTK settings.'

  log INFO 'Desktop cursors breeze-snow have been installed.'
}

# Sets up some extra system fonts.
setup_fonts () {
  log INFO 'Setting up extra system fonts...'

  local fonts_home="${ROOT_FS}/usr/share/fonts/extra-fonts"

  mkdir -p "${fonts_home}" ||
    abort ERROR 'Failed to create the fonts folder.'

  local fonts=(
    "FiraCode https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"
    "JetBrainsMono https://github.com/JetBrains/JetBrainsMono/releases/download/v2.242/JetBrainsMono-2.242.zip"
    "Mononoki https://github.com/madmalik/mononoki/releases/download/1.3/mononoki.zip"
    "VictorMono https://rubjo.github.io/victor-mono/VictorMonoAll.zip"
    "PixelMix https://dl.dafont.com/dl/?f=pixelmix"
  )

  local font=''

  for font in "${fonts[@]}"; do
    local name=''
    name="$(echo "${font}" | cut -d ' ' -f 1)" ||
      abort ERROR 'Failed to extract the font name.'

    local url=''
    url="$(echo "${font}" | cut -d ' ' -f 2)" ||
      abort ERROR 'Failed to extract the font url.'

    curl "${url}" -sSLo "${fonts_home}/${name}.zip" &&
      unzip -q "${fonts_home}/${name}.zip" -d "${fonts_home}/${name}" &&
      chmod -R 755 "${fonts_home}/${name}" &&
      rm -f "${fonts_home}/${name}.zip" ||
      abort ERROR "Failed to install the font ${name}."

    log INFO "Font ${name} has been installed."
  done

  log INFO 'Fonts have been setup.'
}

# Enables various system services.
enable_services () {
  log INFO 'Enabling system services...'

  local etc_systemd="${ROOT_FS}/etc/systemd/system"

  mkdir -p "${etc_systemd}" ||
    abort ERROR 'Failed to create the /etc/systemd/system folder.'

  local lib_systemd='/usr/lib/systemd/system'

  ln -sv "${lib_systemd}/NetworkManager-dispatcher.service" \
    "${etc_systemd}/dbus-org.freedesktop.nm-dispatcher.service" ||
    abort ERROR 'Failed to enable network manager dispatcher service.'

  mkdir -p "${etc_systemd}/multi-user.target.wants"

  ln -sv "${lib_systemd}/NetworkManager.service" \
    "${etc_systemd}/multi-user.target.wants/NetworkManager.service" ||
    abort ERROR 'Failed to enable network manager service.'

  mkdir -p "${etc_systemd}/network-online.target.wants"

  ln -sv "${lib_systemd}/NetworkManager-wait-online.service" \
    "${etc_systemd}/network-online.target.wants/NetworkManager-wait-online.service" ||
    abort ERROR 'Failed to enable the network manager wait services.'

  log INFO 'Network manager services enabled.'

  ln -sv "${lib_systemd}/bluetooth.service" "${etc_systemd}/dbus-org.bluez.service" ||
    abort ERROR 'Failed to enable the bluez service.'
  
  mkdir -p "${etc_systemd}/bluetooth.target.wants"

  ln -sv "${lib_systemd}/bluetooth.service" \
    "${etc_systemd}/bluetooth.target.wants/bluetooth.service" ||
    abort ERROR 'Failed to enable the bluetooth services.'

  log INFO 'Bluetooth services enabled.'

  ln -sv "${lib_systemd}/acpid.service" \
      "${etc_systemd}/multi-user.target.wants/acpid.service" ||
    abort ERROR 'Failed to enable th acpid servce.'

  log INFO 'Acpid service enabled.'

  mkdir -p "${etc_systemd}/printer.target.wants"

  ln -sv "${lib_systemd}/cups.service" \
    "${etc_systemd}/printer.target.wants/cups.service" ||
    abort ERROR 'Failed to enable the cups service.'
  
  ln -sv "${lib_systemd}/cups.service" \
    "${etc_systemd}/multi-user.target.wants/cups.service" ||
    abort ERROR 'Failed to enable the cups service.'

  mkdir -p "${etc_systemd}/sockets.target.wants"

  ln -sv "${lib_systemd}/cups.socket" \
    "${etc_systemd}/sockets.target.wants/cups.socket" ||
    abort ERROR 'Failed to enable the cups socket.'
  
  ln -sv "${lib_systemd}/cups.path" \
      "${etc_systemd}/multi-user.target.wants/cups.path" ||
    abort ERROR 'Failed to enable the cups path.'

  log INFO 'Cups services enabled.'

  ln -sv "${lib_systemd}/nftables.service" \
    "${etc_systemd}/multi-user.target.wants/nftables.service" ||
    abort ERROR 'Failed to enable the nftables service.'

  log INFO 'Nftables service enabled.'

  sed -i 's;#HOME#;/root;' \
    "${ROOT_FS}/root/.config/systemd/user/fix-layout.service" ||
    abort ERROR 'Failed to set the home in fix layout service.'
}

# Sets file system permissions.
set_file_permissions () {
  local permissions_file="${PROFILE_DIR}/profiledef.sh"

  if [[ ! -f "${permissions_file}" ]]; then
    abort ERROR "Unable to locate file ${permissions_file}."
  fi

  local perms=(
    '/etc/pacman.d/scripts/ 0:0:755'
    '/usr/local/bin/tqdm 0:0:755'
    '/opt/stack/commons/ 0:0:755'
    '/opt/stack/tools/ 0:0:755'
    '/etc/welcome 0:0:644'
    '/root/.config/stack/ 0:0:664'
    '/etc/systemd/logind.conf.d/ 0:0:644'
    '/etc/systemd/sleep.conf.d/ 0:0:644'
    '/etc/tlp.d/ 0:0:755'
    '/root/.config/bspwm/ 0:0:755'
    '/root/.config/polybar/scripts/ 0:0:755'
    '/root/.config/rofi/launch 0:0:755'
    '/root/.config/dunst/hook 0:0:755'
    '/etc/sudoers.d/ 0:0:750'
  )

  local perm=''
  for perm in "${perms[@]}"; do
    local path="$(echo "${perm}" | cut -d ' ' -f 1)" ||
      abort ERROR 'Failed to extract permission path.'
    
    local mode="$(echo "${perm}" | cut -d ' ' -f 2)" ||
      abort ERROR 'Failed to extract permission mode.'

    sed -i "/file_permissions=(/a [\"${path}\"]=\"${mode}\"" "${permissions_file}" ||
      abort ERROR "Unable to add file permission ${mode} to ${path}."
  done
  
  log INFO "Permission ${mode} added to ${path}."
}

# Creates the iso file of the live media.
make_iso_file () {
  log INFO 'Building the archiso file...'

  if [[ ! -d "${PROFILE_DIR}" ]]; then
    abort ERROR 'Unable to locate the releng profile folder.'
  fi

  sudo mkarchiso -v -r -w "${WORK_DIR}" -o "${DIST_DIR}" "${PROFILE_DIR}" ||
    abort ERROR 'Failed to build the archiso file.'

  log INFO "Archiso file has been exported at ${DIST_DIR}."
  log INFO 'Build process completed successfully.'
}

log INFO 'Started running test units...'

bash ./test.sh

log INFO 'Starting the build process...'

init &&
  check_deps &&
  copy_profile_files &&
  copy_stack_files &&
  rename_distro &&
  fix_boot_loaders &&
  define_packages &&
  build_aur_packages &&
  remove_unnecessary_tools &&
  copy_installer &&
  setup_auto_login &&
  setup_display_server &&
  setup_shell_environment &&
  setup_desktop &&
  setup_theme &&
  setup_fonts &&
  enable_services &&
  set_file_permissions &&
  make_iso_file
