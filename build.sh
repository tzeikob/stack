#!/bin/bash

set -Eeo pipefail

DIST_DIR=.dist
WORK_DIR="${DIST_DIR}/work"
AUR_DIR="${DIST_DIR}/aur"
PROFILE_DIR="${DIST_DIR}/profile"
ROOT_FS="${PROFILE_DIR}/airootfs"

# Prints an error message and exits the process immediately.
fail () {
  echo -e 'Exiting the build process...'
  exit 1
}

# Adds the package with the given name into the list of packages
# Arguments:
#  name: the name of a package
add_package () {
  local name="${1}"

  local pkgs_file="${PROFILE_DIR}/packages.x86_64"

  if [[ ! -f "${pkgs_file}" ]]; then
    echo -e 'Unable to locate file packages.x86_64'
    return 1
  fi

  if grep -Eq "^${name}$" "${pkgs_file}"; then
    echo -e "Skipping ${name}"
    return 0
  fi

  echo "${name}" >> "${pkgs_file}"
}

# Removes the package with the given name from the list of packages
# Arguments:
#  name: the name of a package
remove_package () {
  local name="${1}"

  local pkgs_file="${PROFILE_DIR}/packages.x86_64"

  if [[ ! -f "${pkgs_file}" ]]; then
    echo -e 'Unable to locate file packages.x86_64'
    return 1
  fi

  if ! grep -Eq "^${name}$" "${pkgs_file}"; then
    echo -e "Unable to remove package ${name}"
    return 1
  fi

  sed -Ei "/^${name}$/d" "${pkgs_file}" || return 1
}

# Initializes build and distribution files.
init () {
  if [[ -d "${DIST_DIR}" ]]; then
    rm -rf "${DIST_DIR}" || return 1

    echo -e 'Existing .dist folder has been removed'
  fi

  mkdir -p "${DIST_DIR}" || return 1

  echo -e 'A clean .dist folder has been created'
}

# Copies the archiso custom profile.
copy_profile () {
  echo -e 'Copying the custom archiso profile...'

  local releng_path="/usr/share/archiso/configs/releng"

  if [[ ! -d "${releng_path}" ]]; then
    echo -e 'Unable to locate releng archiso profile'
    return 1
  fi

  cp -r "${releng_path}" "${PROFILE_DIR}" || return 1

  echo -e "The releng profile copied to ${PROFILE_DIR}"
}

# Adds the pakacge dependencies into the list of packages.
add_packages () {
  echo -e 'Adding system and desktop packages...'

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
    add_package "${pkg}" || return 1
  done

  # Remove conflicting no x server virtualbox utils
  remove_package virtualbox-guest-utils-nox || return 1

  echo -e 'All packages added into the package list'
}

# Builds and adds the AUR packages into the packages list
# via a local custom repo.
add_aur_packages () {
  echo -e 'Building the AUR package files...'

  local previous_dir=${PWD}

  if [[ ! -d "${PROFILE_DIR}" ]]; then
    echo -e 'Unable to locate the releng profile folder'
    return 1
  fi

  local repo_home="${PROFILE_DIR}/local/repo"

  mkdir -p "${repo_home}" || return 1

  local names=(
    yay smenu xkblayout-state-git
  )

  local name=''
  for name in "${names[@]}"; do
    # Build the next AUR package
    git clone "https://aur.archlinux.org/${name}.git" "${AUR_DIR}/${name}" || return 1
  
    cd "${AUR_DIR}/${name}"
    makepkg || return 1
    cd ${previous_dir}

    # Create the custom local repo database
    cp ${AUR_DIR}/${name}/${name}-*-x86_64.pkg.tar.zst "${repo_home}" || return 1
    repo-add "${repo_home}/custom.db.tar.gz" ${repo_home}/${name}-*-x86_64.pkg.tar.zst || return 1

    add_package "${name}" || return 1
  done

  rm -rf "${AUR_DIR}" || return 1

  echo -e 'The AUR package files have been built'

  local pacman_conf="${PROFILE_DIR}/pacman.conf"

  if [[ ! -f "${pacman_conf}" ]]; then
    echo -e 'Unable to locate file pacman.conf'
    return 1
  fi

  printf '%s\n' \
    '' \
    '[custom]' \
    'SigLevel = Optional TrustAll' \
    "Server = file://$(realpath "${repo_home}")" >> "${pacman_conf}" || return 1

  echo -e 'The custom local repo added to pacman'
  echo -e 'All AUR packages added into the package list'
}

# Copies the files of the installer.
copy_installer () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local installer_home="${ROOT_FS}/opt/stack"

  mkdir -p "${installer_home}" || return 1

  cp -r configs "${installer_home}" &&
    cp -r resources "${installer_home}" &&
    cp -r rules "${installer_home}" &&
    cp -r scripts "${installer_home}" &&
    cp -r services "${installer_home}" &&
    cp -r tools "${installer_home}" &&
    cp install.sh "${installer_home}" || return 1

  # Create a global alias to launch the installer
  local bin_home="${ROOT_FS}/usr/local/bin"

  mkdir -p "${bin_home}" || return 1

  ln -sf /opt/stack/install.sh "${bin_home}/install_os" || return 1

  echo -e 'Installer files have been copied'
}

# Copies the files of the settings tools.
copy_settings_tools () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local tools_home="${ROOT_FS}/opt/tools"

  mkdir -p "${tools_home}" || return 1

  # Copy settings tools needed to the live media only
  cp -r tools/displays "${tools_home}" &&
    cp -r tools/desktop "${tools_home}" &&
    cp -r tools/clock "${tools_home}" &&
    cp -r tools/networks "${tools_home}" &&
    cp -r tools/disks "${tools_home}" &&
    cp -r tools/bluetooth "${tools_home}" &&
    cp -r tools/langs "${tools_home}" &&
    cp -r tools/notifications "${tools_home}" &&
    cp -r tools/power "${tools_home}" &&
    cp -r tools/printers "${tools_home}" &&
    cp -r tools/trash "${tools_home}" &&
    cp tools/utils "${tools_home}" || return 1

  # Remove LC_CTYPE on smenu calls as live media doesn't need it
  sed -i 's/\(.*\)LC_CTYPE=.* \(smenu .*\)/\1\2/' "${tools_home}/utils" || return 1

  # Disable init scratchpad command for the live media
  local desktop_main="${tools_home}/desktop/main"

  sed -i "/.*scratchpad.*/d" "${desktop_main}" || return 1

  # Create global aliases for each setting tool main entry
  local bin_home="${ROOT_FS}/usr/local/bin"

  mkdir -p "${bin_home}" || return 1

  ln -sf /opt/tools/displays/main "${bin_home}/displays" &&
    ln -sf /opt/tools/desktop/main "${bin_home}/desktop" &&
    ln -sf /opt/tools/clock/main "${bin_home}/clock" &&
    ln -sf /opt/tools/networks/main "${bin_home}/networks" &&
    ln -sf /opt/tools/disks/main "${bin_home}/disks" &&
    ln -sf /opt/tools/bluetooth/main "${bin_home}/bluetooth" &&
    ln -sf /opt/tools/langs/main "${bin_home}/langs" &&
    ln -sf /opt/tools/notifications/main "${bin_home}/notifications" &&
    ln -sf /opt/tools/power/main "${bin_home}/power" &&
    ln -sf /opt/tools/printers/main "${bin_home}/printers" &&
    ln -sf /opt/tools/trash/main "${bin_home}/trash" || return 1

  echo -e 'Settings tools have been copied'
}

# Sets to skip login prompt and auto login the root user.
setup_auto_login () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local auto_login="${ROOT_FS}/etc/systemd/system/getty@tty1.service.d/autologin.conf"

  local exec_start="ExecStart=-/sbin/agetty -o '-p -f -- \\\\\\\u' --noissue --noclear --skip-login --autologin root - \$TERM"

  sed -i "s;^ExecStart=-/sbin/agetty.*;${exec_start};" "${auto_login}" || return 1

  echo -e 'Login prompt set to skip and autologin'

  # Remove the default welcome message
  rm -rf "${ROOT_FS}/etc/motd" || return 1

  # Create the welcome message to be shown after login
  local welcome=''
  welcome+='░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░\n'
  welcome+='░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░\n'
  welcome+='░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░\n\n'
  welcome+='Welcome to live media of \u001b[36mStack OS\u001b[0m, more information\n'
  welcome+='can be found on https://github.com/tzeikob/stack.git.\n\n'
  welcome+='Connect to a wireless network using the networks tool via\n'
  welcome+='the command \u001b[36mnetworks add wifi <device> <ssid> <secret>\u001b[0m.\n'
  welcome+='Ethernet, WALN and WWAN networks should work automatically.\n\n'
  welcome+='To install a new system run \u001b[36minstall_os\u001b[0m to launch\n'
  welcome+='the installation process of the Stack OS.\n'

  echo -e "${welcome}" > "${ROOT_FS}/etc/welcome"

  echo -e 'Welcome message has been set to /etc/welcome'
}

# Sets up the display server configuration and hooks.
setup_display_server () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local xinitrc_file="${ROOT_FS}/root/.xinitrc"

  cp configs/xorg/xinitrc "${xinitrc_file}" || return 1

  # Keep functionality relatated to live media only
  sed -i '/system -qs check updates &/d' "${xinitrc_file}" &&
    sed -i '/displays -qs restore layout/d' "${xinitrc_file}" &&
    sed -i '/displays -qs restore colors &/d' "${xinitrc_file}" &&
    sed -i '/security -qs init locker &/d' "${xinitrc_file}" &&
    sed -i '/cloud -qs mount remotes &/d' "${xinitrc_file}" || return 1

  echo -e 'The .xinitrc file copied to /root/.xinitrc'

  mkdir -p "${ROOT_FS}/etc/X11" || return 1

  cp configs/xorg/xorg.conf "${ROOT_FS}/etc/X11" || return 1

  echo -e 'The xorg.conf file copied to /etc/X11/xorg.conf'

  local zlogin_file="${ROOT_FS}/root/.zlogin"

  if [[ ! -f "${zlogin_file}" ]]; then
    echo -e 'Unable to locate file /root/.zlogin'
    return 1
  fi

  printf '%s\n' \
    '' \
    "echo -e 'Starting desktop environment...'" \
    'startx' >> "${zlogin_file}" || return 1

  echo -e 'Xorg server set to be started after login'
}

# Sets up the keyboard settings.
setup_keyboard () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  echo 'KEYMAP=us' > "${ROOT_FS}/etc/vconsole.conf" || return 1

  echo -e 'Keyboard map keys has been set to us'

  mkdir -p "${ROOT_FS}/etc/X11/xorg.conf.d" || return 1

  printf '%s\n' \
   'Section "InputClass"' \
   '  Identifier "system-keyboard"' \
   '  MatchIsKeyboard "on"' \
   '  Option "XkbLayout" "us"' \
   '  Option "XkbModel" "pc105"' \
   '  Option "XkbOptions" "grp:alt_shift_toggle"' \
   'EndSection' > "${ROOT_FS}/etc/X11/xorg.conf.d/00-keyboard.conf" || return 1

  echo -e 'Xorg keyboard settings have been set'

  # Save keyboard settings to the user langs json file
  local config_home="${ROOT_FS}/root/.config/stack"

  mkdir -p "${config_home}" || return 1

  printf '%s\n' \
    '{' \
    '  "keymap": "us",' \
    '  "model": "pc105",' \
    '  "options": "grp:alt_shift_toggle",' \
    '  "layouts": [{"code": "us", "variant": "default"}]' \
    '}' > "${config_home}/langs.json" || return 1
  
  echo -e 'Keyboard langs settings have been set'
}

# Sets up various system power settings.
setup_power () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  rm -rf "${ROOT_FS}/etc/systemd/logind.conf.d" &&
    mkdir -p "${ROOT_FS}/etc/systemd/logind.conf.d" || return 1
  
  local logind_conf="${ROOT_FS}/etc/systemd/logind.conf.d/00-main.conf"

  printf '%s\n' \
    '[Login]' \
    'HandleHibernateKey=ignore' \
    'HandleHibernateKeyLongPress=ignore' \
    'HibernateKeyIgnoreInhibited=no' \
    'HandlePowerKey=suspend' \
    'HandleRebootKey=reboot' \
    'HandleSuspendKey=suspend' \
    'HandleLidSwitch=suspend' \
    'HandleLidSwitchDocked=ignore' > "${logind_conf}" || return 1

  echo -e 'Logind action handlers have been set'

  rm -rf "${ROOT_FS}/etc/systemd/sleep.conf.d" &&
    mkdir -p "${ROOT_FS}/etc/systemd/sleep.conf.d" || return 1
  
  local sleep_conf="${ROOT_FS}/etc/systemd/sleep.conf.d/00-main.conf"

  printf '%s\n' \
    '[Sleep]' \
    'AllowSuspend=yes' \
    'AllowHibernation=no' \
    'AllowSuspendThenHibernate=no' \
    'AllowHybridSleep=no' > "${sleep_conf}" || return 1

  echo -e 'Sleep action handlers have been set'

  mkdir -p "${ROOT_FS}/etc/tlp.d" || return 1

  local tlp_conf="${ROOT_FS}/etc/tlp.d/00-main.conf"

  printf '%s' \
    'SOUND_POWER_SAVE_ON_AC=0' \
    'SOUND_POWER_SAVE_ON_BAT=0' > "${tlp_conf}" || return 1

  echo -e 'Battery action handlers have been set'

  local config_home="${ROOT_FS}/root/.config/stack"

  mkdir -p "${config_home}" || return 1

  printf '%s\n' \
  '{' \
  '  "screensaver": {"interval": 15}' \
  '}' > "${config_home}/power.json" || return 1

  echo -e 'Screensaver interval setting has been set'
}

# Sets up the sheel environment files.
setup_shell_environment () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local zshrc_file="${ROOT_FS}/root/.zshrc"

  # Set the defauilt terminal and text editor
  echo -e 'export TERMINAL=cool-retro-term' >> "${zshrc_file}"

  echo -e 'Default terminal set to cool-retro-term'

  echo -e 'export EDITOR=helix' >> "${zshrc_file}"

  echo -e 'Default editor set to helix'

  # Set up trash-cli aliases
  echo -e "\nalias sudo='sudo '" >> "${zshrc_file}"
  echo "alias tt='trash-put -i'" >> "${zshrc_file}"
  echo "alias rm='rm -i'" >> "${zshrc_file}"

  echo -e 'Command aliases added to /root/.zshrc'

  printf '%s\n' \
    '' \
    'if [[ "${SHOW_WELCOME_MSG}" == "true" ]]; then' \
    '  cat /etc/welcome' \
    'fi' >> "${zshrc_file}" || return 1

  echo -e 'Welcome message set to be shown after login'
}

# Sets up the corresponding configurations for
# each desktop module.
setup_desktop () {
  echo -e 'Setting up the desktop configurations...'

  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local config_home="${ROOT_FS}/root/.config"

  # Copy the picom configuration files
  local picom_home="${config_home}/picom"

  mkdir -p "${picom_home}" || return 1
  
  cp configs/picom/picom.conf "${picom_home}" || return 1

  echo -e 'Picom configuration has been set'

  # Copy windows manager configuration files
  local bspwm_home="${config_home}/bspwm"

  mkdir -p "${bspwm_home}" || return 1

  cp configs/bspwm/bspwmrc "${bspwm_home}" &&
    cp configs/bspwm/resize "${bspwm_home}" &&
    cp configs/bspwm/rules "${bspwm_home}" &&
    cp configs/bspwm/swap "${bspwm_home}" || return 1

  # Remove init scratchpad initializer from the bspwmrc
  sed -i '/desktop -qs init scratchpad &/d' "${bspwm_home}/bspwmrc" || return 1
  sed -i '/bspc rule -a scratch sticky=off state=floating hidden=on/d' "${bspwm_home}/bspwmrc" || return 1

  # Add a hook to open the welcome terminal once at login
  printf '%s\n' \
    '[ "$@" -eq 0 ] && {' \
    '  SHOW_WELCOME_MSG=true cool-retro-term &' \
    '}' >> "${bspwm_home}/bspwmrc" || return 1

  echo -e 'Bspwm configuration has been set'

  # Copy polybar configuration files
  local polybar_home="${config_home}/polybar"

  mkdir -p "${polybar_home}" || return 1

  cp configs/polybar/config.ini "${polybar_home}" &&
    cp configs/polybar/modules.ini "${polybar_home}" &&
    cp configs/polybar/theme.ini "${polybar_home}" || return 1

  local config_ini="${polybar_home}/config.ini"

  # Remove modules not needed by the live media
  sed -i "s/\(modules-right = \)cpu.*/\1 alsa-audio date time/" "${config_ini}" || return 1
  sed -i "s/\(modules-right = \)notifications.*/\1 flash-drives keyboard/" "${config_ini}" || return 1
  sed -i "s/\(modules-left = \)wlan.*/\1 wlan eth/" "${config_ini}" || return 1

  mkdir -p "${polybar_home}/scripts" || return 1

  # Keep only scripts needed by the live media
  cp -r configs/polybar/scripts/flash-drives "${polybar_home}/scripts" || return 1
  cp -r configs/polybar/scripts/time "${polybar_home}/scripts" || return 1

  echo -e 'Polybar configuration has been set'

  # Copy sxhkd configuration files
  local sxhkd_home="${config_home}/sxhkd"

  mkdir -p "${sxhkd_home}" || return 1

  cp configs/sxhkd/sxhkdrc "${sxhkd_home}" || return 1

  local sxhkdrc_file="${sxhkd_home}/sxhkdrc"

  # Remove key bindings not needed by the live media
  sed -i '/# Lock the screen./,+3d' "${sxhkdrc_file}" &&
    sed -i '/# Take a screen shot./,+3d' "${sxhkdrc_file}" &&
    sed -i '/# Start recording your screen./,+3d' "${sxhkdrc_file}" &&
    sed -i '/# Show and hide the scratchpad termimal./,+3d' "${sxhkdrc_file}" || return 1

  echo -e 'Sxhkd configuration has been set'

  # Copy rofi configuration files
  local rofi_home="${config_home}/rofi"

  mkdir -p "${rofi_home}" || return 1

  cp configs/rofi/config.rasi "${rofi_home}" || return 1
  cp configs/rofi/launch "${rofi_home}" || return 1

  local launch_file="${rofi_home}/launch"

  sed -i "/options+='Lock\\\n'/d" "${launch_file}" &&
    sed -i "/options+='Blank\\\n'/d" "${launch_file}" &&
    sed -i "/options+='Logout'/d" "${launch_file}" &&
    sed -i "s/\(  local exact_lines='listview {lines:\) 6\(;}'\)/\1 3\2/" "${launch_file}" &&
    sed -i "/'Lock') security -qs lock screen;;/d" "${launch_file}" &&
    sed -i "/'Blank') power -qs blank;;/d" "${launch_file}" &&
    sed -i "/'Logout') security -qs logout user;;/d" "${launch_file}" || return 1

  echo -e 'Rofi configuration has been set'

  # Copy dunst configuration files
  local dunst_home="${config_home}/dunst"

  mkdir -p "${dunst_home}" || return 1

  cp configs/dunst/dunstrc "${dunst_home}" || return 1
  cp configs/dunst/hook "${dunst_home}" || return 1

  echo -e 'Dunst configuration has been set'
}

# Sets up the theme of the desktop environment.
setup_theme () {
  echo -e 'Setting up the desktop theme...'

  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local themes_home="${ROOT_FS}/usr/share/themes"

  mkdir -p "${themes_home}" || return 1

  local theme_url='https://github.com/dracula/gtk/archive/master.zip'

  curl "${theme_url}" -sSLo "${themes_home}/Dracula.zip" &&
    unzip -q "${themes_home}/Dracula.zip" -d "${themes_home}" &&
    mv "${themes_home}/gtk-master" "${themes_home}/Dracula" &&
    rm -f "${themes_home}/Dracula.zip" || return 1

  echo -e 'Desktop theme has been installed'

  echo -e 'Setting up the desktop icons...'

  local icons_home="${ROOT_FS}/usr/share/icons"

  mkdir -p "${icons_home}" || return 1
  
  local icons_url='https://github.com/dracula/gtk/files/5214870/Dracula.zip'

  curl "${icons_url}" -sSLo "${icons_home}/Dracula.zip" &&
    unzip -q "${icons_home}/Dracula.zip" -d "${icons_home}" &&
    rm -f "${icons_home}/Dracula.zip" || return 1

  echo -e 'Desktop icons have been installed'

  echo -e 'Setting up the desktop cursors...'

  local cursors_home="${ROOT_FS}/usr/share/icons"

  mkdir -p "${cursors_home}" || return 1

  local cursors_url='https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1'

  wget "${cursors_url}" -qO "${cursors_home}/breeze-snow.tgz" &&
    tar -xzf "${cursors_home}/breeze-snow.tgz" -C "${cursors_home}" &&
    rm -f "${cursors_home}/breeze-snow.tgz" || return 1

  mkdir -p "${cursors_home}/default" || return 1

  echo '[Icon Theme]' >> "${cursors_home}/default/index.theme"
  echo 'Inherits=Breeze-Snow' >> "${cursors_home}/default/index.theme"

  echo -e 'Desktop cursors have been installed'

  local gtk_home="${ROOT_FS}/root/.config/gtk-3.0"
  
  mkdir -p "${gtk_home}" || return 1
  cp configs/gtk/settings.ini "${gtk_home}" || return 1

  echo -e 'Gtk settings file has been set'

  echo -e 'Setting the desktop wallpaper...'

  local wallpapers_home="${ROOT_FS}/root/.local/share/wallpapers"

  mkdir -p "${wallpapers_home}" || return 1
  cp resources/wallpapers/* "${wallpapers_home}" || return 1

  local settings_home="${ROOT_FS}/root/.config/stack"

  mkdir -p "${settings_home}" || return 1

  local settings='{"wallpaper": {"name": "default.jpeg", "mode": "fill"}}'

  echo "${settings}" > "${settings_home}/desktop.json"

  echo -e 'Desktop wallpaper has been set'
}

# Sets up some extra system fonts.
setup_fonts () {
  echo -e 'Setting up extra system fonts...'

  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local fonts_home="${ROOT_FS}/usr/share/fonts/extra-fonts"

  mkdir -p "${fonts_home}" || return 1

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
    name="$(echo "${font}" | cut -d ' ' -f 1)" || return 1

    local url=''
    url="$(echo "${font}" | cut -d ' ' -f 2)" || return 1

    curl "${url}" -sSLo "${fonts_home}/${name}.zip" &&
      unzip -q "${fonts_home}/${name}.zip" -d "${fonts_home}/${name}" &&
      chmod -R 755 "${fonts_home}/${name}" &&
      rm -f "${fonts_home}/${name}.zip" || return 1

    echo -e "Font ${name} installed"
  done

  echo -e 'Fonts have been setup'
}

# Sets up various system sound resources.
setup_sounds () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local sounds_home="${ROOT_FS}/usr/share/sounds/stack"
  
  mkdir -p "${sounds_home}" || return 1

  cp resources/sounds/normal.wav "${sounds_home}" || return 1
  cp resources/sounds/critical.wav "${sounds_home}" || return 1

  echo -e 'Extra system sounds have been set'
}

# Enables various system services.
enable_services () {
  echo -e 'Enabling system services...'

  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  mkdir -p "${ROOT_FS}/etc/systemd/system" || return 1

  ln -s /usr/lib/systemd/system/NetworkManager-dispatcher.service \
    "${ROOT_FS}/etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service" || return 1

  mkdir -p "${ROOT_FS}/etc/systemd/system/multi-user.target.wants" || return 1

  ln -s /usr/lib/systemd/system/NetworkManager.service \
    "${ROOT_FS}/etc/systemd/system/multi-user.target.wants/NetworkManager.service" || return 1

  mkdir -p "${ROOT_FS}/etc/systemd/system/network-online.target.wants" || return 1

  ln -s /usr/lib/systemd/system/NetworkManager-wait-online.service \
    "${ROOT_FS}/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service" || return 1

  echo -e 'Network manager services enabled'

  ln -s /usr/lib/systemd/system/bluetooth.service \
    "${ROOT_FS}/etc/systemd/system/dbus-org.bluez.service" || return 1

  mkdir -p "${ROOT_FS}/etc/systemd/system/bluetooth.target.wants" || return 1

  ln -s /usr/lib/systemd/system/bluetooth.service \
    "${ROOT_FS}/etc/systemd/system/bluetooth.target.wants/bluetooth.service" || return 1

  echo -e 'Bluetooth services enabled'

  ln -s /usr/lib/systemd/system/acpid.service \
    "${ROOT_FS}/etc/systemd/system/multi-user.target.wants/acpid.service" || return 1

  echo -e 'Acpid service enabled'

  mkdir -p "${ROOT_FS}/etc/systemd/system/printer.target.wants" || return 1

  ln -s /usr/lib/systemd/system/cups.service \
    "${ROOT_FS}/etc/systemd/system/printer.target.wants/cups.service" || return 1

  ln -s /usr/lib/systemd/system/cups.service \
    "${ROOT_FS}/etc/systemd/system/multi-user.target.wants/cups.service" || return 1

  mkdir -p "${ROOT_FS}/etc/systemd/system/sockets.target.wants" || return 1

  ln -s /usr/lib/systemd/system/cups.socket \
    "${ROOT_FS}/etc/systemd/system/sockets.target.wants/cups.socket" || return 1

  ln -s /usr/lib/systemd/system/cups.path \
    "${ROOT_FS}/etc/systemd/system/multi-user.target.wants/cups.path" || return 1

  echo -e 'Cups services enabled'

  ln -s /usr/lib/systemd/system/nftables.service \
    "${ROOT_FS}/etc/systemd/system/multi-user.target.wants/nftables.service" || return 1

  echo -e 'Nftables service enabled'

  mkdir -p "${ROOT_FS}/root/.config/systemd/user" || return 1

  cp services/init-pointer.service \
    "${ROOT_FS}/root/.config/systemd/user/init-pointer.service" || return 1

  echo -e 'Pointer init service enabled'

  cp services/init-tablets.service \
    "${ROOT_FS}/root/.config/systemd/user/init-tablets.service" || return 1

  echo -e 'Tablets init service enabled'

  cp services/fix-layout.service \
    "${ROOT_FS}/root/.config/systemd/user/fix-layout.service" || return 1
  
  sed -i 's;^\(Environment=HOME\).*;\1=/root;' \
    "${ROOT_FS}/root/.config/systemd/user/fix-layout.service" || return 1
  
  sed -i 's;^\(Environment=XAUTHORITY\).*;\1=/root/.Xauthority;' \
    "${ROOT_FS}/root/.config/systemd/user/fix-layout.service" || return 1
  
  echo -e 'Fix layout service enabled'
}

# Adds input and output devices rules.
add_device_rules () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local rules_home="${ROOT_FS}/etc/udev/rules.d"

  mkdir -p "${rules_home}" || return 1

  cp rules/90-init-pointer.rules "${rules_home}" &&
    cp rules/91-init-tablets.rules "${rules_home}" &&
    cp rules/92-fix-layout.rules "${rules_home}" || return 1
  
  echo -e 'Device rules have been set'
}

# Adds various extra sudoers rules.
add_sudoers_rules () {
  if [[ ! -d "${ROOT_FS}" ]]; then
    echo -e 'Unable to locate the airootfs folder'
    return 1
  fi

  local proxy_rules='Defaults env_keep += "'
  proxy_rules+='http_proxy HTTP_PROXY '
  proxy_rules+='https_proxy HTTPS_PROXY '
  proxy_rules+='ftp_proxy FTP_PROXY '
  proxy_rules+='rsync_proxy RSYNC_PROXY '
  proxy_rules+='all_proxy ALL_PROXY '
  proxy_rules+='no_proxy NO_PROXY"'

  mkdir -p "${ROOT_FS}/etc/sudoers.d" || return 1

  echo "${proxy_rules}" > "${ROOT_FS}/etc/sudoers.d/proxy_rules"

  echo -e 'Proxy rules have been added to sudoers'
}

# Defines the root files permissions.
set_file_permissions () {
  local permissions_file="${PROFILE_DIR}/profiledef.sh"

  if [[ ! -f "${permissions_file}" ]]; then
    echo -e 'Unable to locate file profiledef.sh'
    return 1
  fi

  local defs=(
    '0:0:750,/etc/sudoers.d/'
    '0:0:755,/etc/tlp.d/'
    '0:0:644,/etc/systemd/sleep.conf.d/'
    '0:0:644,/etc/systemd/logind.conf.d/'
    '0:0:644,/etc/welcome'
    '0:0:755,/opt/stack/configs/bspwm/'
    '0:0:755,/opt/stack/configs/dunst/hook'
    '0:0:755,/opt/stack/configs/nnn/env'
    '0:0:755,/opt/stack/configs/polybar/scripts/'
    '0:0:755,/opt/stack/configs/rofi/launch'
    '0:0:755,/opt/stack/configs/xsecurelock/hook'
    '0:0:755,/opt/stack/tools/'
    '0:0:755,/opt/stack/scripts/'
    '0:0:755,/opt/stack/install.sh'
    '0:0:755,/root/.config/bspwm/'
    '0:0:755,/root/.config/polybar/scripts/'
    '0:0:755,/root/.config/rofi/launch'
    '0:0:755,/root/.config/dunst/hook'
    '0:0:664,/root/.config/stack/'
    '0:0:755,/opt/tools/'
  )

  local def=''
  for def in "${defs[@]}"; do
    local perms=''
    perms="$(echo "${def}" | cut -d ',' -f 1)" || return 1

    local path=''
    path="$(echo "${def}" | cut -d ',' -f 2)" || return 1

    sed -i "/file_permissions=(/a [\"${path}\"]=\"${perms}\"" "${permissions_file}" || return 1
  done

  echo -e 'File permissions have been defined'
}

# Creates the iso file of the live media.
make_iso_file () {
  echo -e 'Building the archiso file...'

  if [[ ! -d "${PROFILE_DIR}" ]]; then
    echo -e 'Unable to locate the releng profile folder'
    return 1
  fi

  sudo mkarchiso -v -r -w "${WORK_DIR}" -o "${DIST_DIR}" "${PROFILE_DIR}" || return 1

  echo -e "Archiso file has been exported at ${DIST_DIR}"
  echo -e 'Build process completed successfully'
}

echo -e 'Starting the build process...'

init &&
  copy_profile &&
  add_packages &&
  add_aur_packages &&
  copy_installer &&
  copy_settings_tools &&
  setup_auto_login &&
  setup_display_server &&
  setup_keyboard &&
  setup_power &&
  setup_shell_environment &&
  setup_desktop &&
  setup_theme &&
  setup_fonts &&
  setup_sounds &&
  enable_services &&
  add_device_rules &&
  add_sudoers_rules &&
  set_file_permissions &&
  make_iso_file || fail

