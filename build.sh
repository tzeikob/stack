#!/bin/bash

set -o pipefail

if [[ "$(dirname "$(realpath -s "${0}")")" != "${PWD}" ]]; then
  echo 'Unable to run script out of its parent directory.'
  exit 1
fi

DIST_DIR=.dist
WORK_DIR="${DIST_DIR}/work"
AUR_DIR="${DIST_DIR}/aur"
PROFILE_DIR="${DIST_DIR}/profile"
ROOT_FS="${PROFILE_DIR}/airootfs"

source src/commons/logger.sh
source src/commons/error.sh
source src/commons/validators.sh

# Initializes build and distribution files.
init () {
  if directory_exists "${DIST_DIR}"; then
    rm -rf "${DIST_DIR}" ||
      abort ERROR 'Unable to remove the .dist folder.'

    log WARN 'Existing .dist folder has been removed.'
  fi

  mkdir -p "${DIST_DIR}" ||
    abort ERROR 'Unable to create the .dist folder.'

  log INFO 'A clean .dist folder has been created.'
}

# Checks if any build dependencies are missing and
# abort immediately.
check_build_deps () {
  local deps=(archiso rsync sqlite3)

  local dep=''

  for dep in "${deps[@]}"; do
    if ! pacman -Qi "${dep}" > /dev/null 2>&1; then
      abort ERROR "Package dependency ${dep} is not installed."
    fi
  done
}

# Copies the archiso custom profile.
copy_iso_profile () {
  log INFO 'Copying the releng archiso profile...'

  local releng_path='/usr/share/archiso/configs/releng'

  if directory_not_exists "${releng_path}"; then
    abort ERROR 'Unable to locate releng archiso profile.'
  fi

  rsync -av "${releng_path}/" "${PROFILE_DIR}" ||
    abort ERROR 'Unable to copy the releng archiso profile.'

  log INFO "The releng profile copied to ${PROFILE_DIR}."
}

# Adds and removes all the official packages the live media
# depends on, by declaring them into the packages.x86_64 file.
declare_packages () {
  log INFO 'Adding official packages in packages.x86_64 file...'

  # Collect all the official packages the live media needs
  local pkgs=()
  pkgs+=($(grep -E '(bld|all):pac' packages.x86_64 | cut -d ':' -f 3)) ||
    abort ERROR 'Failed to read packages from packages.x86_64 file.'

  local pkgs_file="${PROFILE_DIR}/packages.x86_64"

  local pkg=''

  for pkg in "${pkgs[@]}"; do
    if ! grep -Eq "^${pkg}$" "${pkgs_file}"; then
      echo "${pkg}" >> "${pkgs_file}"
    else
      log WARN "Package ${pkg} already added."
    fi
  done

  # Remove conflicting nox server virtualbox utils
  sed -Ei "/^virtualbox-guest-utils-nox$/d" "${pkgs_file}" &&
    log INFO 'Package virtualbox-guest-utils-nox removed.' ||
    abort ERROR 'Unable to remove virtualbox-guest-utils-nox package.'

  log INFO 'Official packages set in packages.x86_64 file.'
}

# Builds and adds all the AUR packages the live media depends
# on, into the packages file via local custom repositories.
build_aur_packages () {
  log INFO 'Building AUR packages...'

  local previous_dir=${PWD}

  local repo_home="${PROFILE_DIR}/local/repo"

  mkdir -p "${repo_home}" ||
    abort ERROR 'Failed to create the local repo folder.'

  # Collect all the AUR packages the live media needs
  local names=(yay)
  names+=($(grep -E '(bld|all):aur' packages.x86_64 | cut -d ':' -f 3)) ||
    abort ERROR 'Failed to read packages from packages.x86_64 file.'

  local name=''

  for name in "${names[@]}"; do
    # Build the next AUR package
    git clone "https://aur.archlinux.org/${name}.git" "${AUR_DIR}/${name}" ||
      abort ERROR "Failed to clone AUR ${name} package repo."
  
    cd "${AUR_DIR}/${name}"
    makepkg || abort ERROR "Failed to build AUR ${name} package."
    cd ${previous_dir}

    # Create the custom local repo database
    cp ${AUR_DIR}/${name}/${name}-*-x86_64.pkg.tar.zst "${repo_home}" &&
      repo-add "${repo_home}/custom.db.tar.gz" ${repo_home}/${name}-*-x86_64.pkg.tar.zst
    
    if has_failed; then
      cp ${AUR_DIR}/${name}/${name}-*-any.pkg.tar.zst "${repo_home}" &&
        repo-add "${repo_home}/custom.db.tar.gz" ${repo_home}/${name}-*-any.pkg.tar.zst ||
        abort ERROR "Failed to add ${name} package into the custom repository."
    fi

    local pkgs_file="${PROFILE_DIR}/packages.x86_64"

    if ! grep -Eq "^${name}$" "${pkgs_file}"; then
      echo "${name}" >> "${pkgs_file}"
    else
      log WARN "Package ${name} already added."
    fi

    log INFO "Package ${name} has been built."
  done

  rm -rf "${AUR_DIR}" ||
    abort ERROR 'Failed to remove AUR temporary folder.'

  local pacman_conf="${PROFILE_DIR}/pacman.conf"

  printf '%s\n' \
    '' \
    '[custom]' \
    'SigLevel = Optional TrustAll' \
    "Server = file://$(realpath "${repo_home}")" >> "${pacman_conf}" &&
    log INFO 'Custom local repo added to pacman.' ||
    abort ERROR 'Failed to define the custom local repo.'

  log INFO 'AUR packages set in packages.x86_64 file.'
}

# Builds third party packages from source.
build_source_packages () {
  local install_smenu
  install_smenu () {
    log INFO 'Building smenu package...'

    local root_fs_local=''
    root_fs_local="$(realpath ${ROOT_FS}/usr/local)"

    local previous_dir=${PWD}

    git clone https://github.com/p-gen/smenu.git /tmp/smenu ||
      abort ERROR 'Failed to clone smenu git repository.'
    
    cd /tmp/smenu

    ./build.sh --prefix="${root_fs_local}" ||
      abort ERROR 'Failed to build smenu package.'
    
    make install && rm -rf "${root_fs_local}/share/man" ||
      abort ERROR 'Failed to install smenu package.'
    
    cd ${previous_dir} && rm -rf /tmp/smenu
    
    log INFO 'Package smenu has been built.'
  }

  log "Building source packages..."
  
  install_smenu

  log "Source packages have been built."
}

# Syncs the root files to new system.
sync_root_files () {
  log INFO 'Syncing the root file system...'

  rsync -av airootfs/ "${ROOT_FS}" ||
    abort ERROR 'Failed to sync the root file system.'
  
  rsync -av "${ROOT_FS}/home/user/" "${ROOT_FS}/root" &&
    rm -rf "${ROOT_FS}/home" ||
    abort ERROR 'Failed to sync files under root home.'
  
  mkdir -p "${ROOT_FS}/root"/{downloads,documents,data,sources,mounts} &&
    mkdir -p "${ROOT_FS}/root"/{images,audios,videos} ||
    abort ERROR 'Failed to create home directories.'
  
  log INFO 'Home directories have been created.'

  mkdir -p \
    "${ROOT_FS}/var/log/stack" \
    "${ROOT_FS}/var/log/stack/tools" \
    "${ROOT_FS}/var/log/stack/bars"

  log INFO 'Logs directory has been created.'
  
  log INFO 'Root file system has been synced.'
}

# Syncs the commons script files.
sync_commons () {
  log INFO 'Syncing the commons files...'

  mkdir -p "${ROOT_FS}/opt/stack" ||
    abort ERROR 'Failed to create the /opt/stack folder.'

  rsync -av src/commons/ "${ROOT_FS}/opt/stack/commons" ||
    abort ERROR 'Failed to sync the commons files.'
  
  sed -i 's;source src;source /opt/stack;' ${ROOT_FS}/opt/stack/commons/* &&
    log INFO 'Source paths fixed to /opt/stack.' ||
    abort ERROR 'Failed to fix source paths to /opt/stack.'
  
  log INFO 'Commons files have been synced.'
}

# Syncs the tools script files.
sync_tools () {
  log INFO 'Syncing the tools files...'

  mkdir -p "${ROOT_FS}/opt/stack" ||
    abort ERROR 'Failed to create the /opt/stack folder.'

  rsync -av src/tools/ "${ROOT_FS}/opt/stack/tools" \
    --exclude audio \
    --exclude bluetooth \
    --exclude cloud \
    --exclude security \
    --exclude system ||
    abort ERROR 'Failed to sync the tools files.'
  
  sed -i 's;source src;source /opt/stack;' ${ROOT_FS}/opt/stack/tools/**/* ||
    abort ERROR 'Failed to fix source paths to /opt/stack.'
  
  log INFO 'Source paths fixed to /opt/stack.'

  # Create and restore all symlinks for every tool
  mkdir -p "${ROOT_FS}/usr/local/stack" ||
    abort ERROR 'Failed to create the /usr/local/stack folder.'
  
  local main_files
  main_files=($(find "${ROOT_FS}/opt/stack/tools" -type f -name 'main.sh' | sed "s;${ROOT_FS};;")) ||
    abort ERROR 'Failed to get the list of main script file paths.'
  
  local main_file=''

  for main_file in "${main_files[@]}"; do
    # Extrack the tool handle name
    local tool_name
    tool_name="$(echo "${main_file}" | sed 's;/opt/stack/tools/\(.*\)/main.sh;\1;')" ||
      abort ERROR 'Failed to extract tool handle name.'

    ln -sf "${main_file}" "${ROOT_FS}/usr/local/stack/${tool_name}" ||
      abort ERROR "Failed to create symlink for ${main_file} file."
  done

  log INFO 'Tools symlinks have been created.'
  log INFO 'Tools files have been synced.'
}

# Sets the distribution names and release meta files.
rename_distro () {
  local name='stackiso'

  sed -i "s/#HOST_NAME#/${name}/" "${ROOT_FS}/etc/hostname" &&
    sed -i "s/#HOST_NAME#/${name}/" "${ROOT_FS}/etc/hosts" ||
    abort ERROR 'Failed to set the host name.'
  
  log INFO "Host name set to ${name}."
  
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

  sed -i "s;#VERSION#;${version};" "${ROOT_FS}/etc/os-release" ||
    abort ERROR 'Failed to set build version.'
  
  ln -sf /etc/os-release "${ROOT_FS}/etc/stack-release" ||
    abort ERROR 'Failed to create the stack-release symlink.'

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

# Sets to skip login prompt and auto login the root user.
setup_auto_login () {
  local auto_login="${ROOT_FS}/etc/systemd/system/getty@tty1.service.d/autologin.conf"

  local exec_start="ExecStart=-/sbin/agetty -o '-p -f -- \\\\\\\u' --noissue --noclear --skip-login --autologin root - \$TERM"

  sed -i "s;^ExecStart=-/sbin/agetty.*;${exec_start};" "${auto_login}" ||
    abort ERROR 'Failed to set skip on login prompt.'

  log INFO 'Login prompt set to skip and autologin.'

  # Create the welcome message
  printf '%s\n' \
    '░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░' \
    '░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░' \
    '░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░' \
    '' \
    'Welcome to live media of \u001b[36mStack Linux\u001b[0m, more info can' \
    'be found on https://github.com/tzeikob/stack.git.' \
    '' \
    'Connect to a wireless network via \u001b[36mnetworks add wifi\u001b[0m.' \
    'Ethernet LAN/WAN networks should work automatically.' \
    '' \
    'To install \u001b[36mStack Linux\u001b[0m run \u001b[36mstack install\u001b[0m.' > "${ROOT_FS}/etc/welcome" ||
    abort ERROR 'Failed to create the welcome message.'

  rm -rf "${ROOT_FS}/etc/motd" ||
    abort ERROR 'Failed to remove the /etc/motd file.'

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
  local stackrc_file="${ROOT_FS}/root/.stackrc"

  # Set the default terminal and text editor
  sed -i 's/#TERMINAL#/cool-retro-term/' "${stackrc_file}" ||
    abort ERROR 'Failed to set the default terminal.'

  log INFO 'Default terminal set to cool-retro-term.'

  sed -i 's/#EDITOR#/helix/' "${stackrc_file}" ||
    abort ERROR 'Failed to set the default editor.'

  log INFO 'Default editor set to helix.'

  # Remove nnn file manager shell hooks
  sed -i "/nnn/d" "${stackrc_file}" ||
    abort ERROR 'Failed to remove nnn shell hooks.'
  
  # Remove shell prompt formatter
  sed -i '/source .*\.prompt/d' "${stackrc_file}" &&
    rm -f "${ROOT_FS}/root/.prompt" ||
    abort ERROR 'Failed to remove shell prompt formatter.'

  printf '%s\n' \
    '' \
    'if [[ "${SHOW_WELCOME_MSG}" == "true" ]]; then' \
    '  echo -e "$(cat /etc/welcome)"' \
    'fi' \
    '' >> "${stackrc_file}" ||
    abort ERROR 'Failed to add the welcome message hook call.'
  
  log INFO 'Welcome message hook has been set.'
  
  local zshrc_file="${ROOT_FS}/root/.zshrc"

  echo -e 'source "${HOME}/.stackrc"\n' >> "${zshrc_file}"
}

# Sets up the corresponding desktop configurations.
setup_desktop () {
  log INFO 'Setting up desktop configurations...'

  local config_home="${ROOT_FS}/root/.config"

  local bspwm_home="${config_home}/bspwm"

  # Add a hook to open the welcome terminal once at login
  printf '%s\n' \
    '' \
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
    -e '/# Start recording your screen./,+3d' "${sxhkdrc_file}" ||
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
  local names=(alacritty mpd ncmpcpp nnn)

  local name=''

  for name in "${names[@]}"; do
    rm -rf "${ROOT_FS}/root/.config/${name}" ||
      abort ERROR "Failed to remove configuration ${name}."
    
    log INFO "Configuration files of ${name} have been removed."
  done

  rm -f \
    "${ROOT_FS}/etc/systemd/system/lock@.service" \
    "${ROOT_FS}/usr/lib/systemd/system-sleep/locker" ||
    abort ERROR 'Failed to remove locker files.'

  rm -f "${ROOT_FS}/root/.config/mimeapps.list" ||
    abort ERROR 'Failed to remove mime apps file.'
  
  rm -f "${ROOT_FS}/root/user-dirs.dirs" ||
    abort ERROR 'Failed to remove user dirs file.'
  
  rm -f "${ROOT_FS}/usr/local/share/applications/ncmpcpp.desktop" ||
    abort ERROR 'Failed to remove ncmpcpp desktop file.'
  
  log INFO 'Locker files have been removed.'
}

# Sets up the keyboard layout settings.
setup_keyboard () {
  log INFO 'Applying keyboard settings...'

  local langs_file="${ROOT_FS}/root/.config/stack/langs.json"

  local keyboard_map=''
  keyboard_map="$(jq -cer '.keymap' "${langs_file}")" ||
    abort ERROR 'Failed to read .keymap setting.'

  sed -i "s/#KEYMAP#/${keyboard_map}/" "${ROOT_FS}/etc/vconsole.conf" ||
    abort ERROR 'Failed to add keymap to vconsole.'
  
  log INFO "Virtual console keymap set to ${keyboard_map}."

  local keyboard_model=''
  keyboard_model="$(jq -cer '.model' "${langs_file}")" ||
    abort ERROR 'Failed to read .model setting.'

  local keyboard_options=''
  keyboard_options="$(jq -cer '.options' "${langs_file}")" ||
    abort ERROR 'Failed to read .options setting.'

  local query='[.layouts[] | .code] | join(",")'
  
  local keyboard_layouts=''
  keyboard_layouts="$(jq -cer "${query}" "${langs_file}")" ||
    abort ERROR 'Failed to read .layout settings.'
  
  local query='[.layouts[] | .variant | if . == "default" then "" else . end] | join(",")'

  local layout_variants=''
  layout_variants="$(jq -cer "${query}" "${langs_file}")" ||
    abort ERROR 'Failed to read .variant settings.'

  local keyboard_conf="${ROOT_FS}/etc/X11/xorg.conf.d/00-keyboard.conf"

  sed -i \
    -e "s/#MODEL#/${keyboard_model}/" \
    -e "s/#OPTIONS#/${keyboard_options}/" \
    -e "s/#LAYOUTS#/${keyboard_layouts}/" \
    -e "s/#VARIANTS#/${layout_variants}/" "${keyboard_conf}" ||
    abort ERROR 'Failed to set Xorg keyboard settings.'

  log INFO 'Keyboard settings have been applied.'
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

  printf '%s\n' \
    '[Icon Theme]' \
    'Inherits=Breeze-Snow' >> "${cursors_home}/default/index.theme" ||
    abort ERROR 'Failed to set the default index theme.'

  log INFO 'Desktop cursors breeze-snow have been installed.'

  sed -i \
    -e 's/#THEME#/Dracula/' \
    -e 's/#ICONS#/Dracula/' \
    -e 's/#CURSORS#/Breeze-Snow/' "${ROOT_FS}/root/.config/gtk-3.0/settings.ini" ||
    abort ERROR 'Failed to set theme in GTK settings.'
  
  # Reset the cool-retro-term settings and profile
  ./${ROOT_FS}/root/.config/cool-retro-term/reset "${ROOT_FS}/root" ||
    abort ERROR 'Failed to reset the cool retro term theme.'
  
  log INFO 'Cool retro term theme has been reset.'

  log INFO 'Desktop theme has been setup.'
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

  sed -i 's;#HOME#;/root;g' \
    "${ROOT_FS}/root/.config/systemd/user/fix-layout.service" ||
    abort ERROR 'Failed to set the home in fix layout service.'
}

# Sets file system permissions.
set_file_permissions () {
  local permissions_file="${PROFILE_DIR}/profiledef.sh"

  if file_not_exists "${permissions_file}"; then
    abort ERROR "Unable to locate file ${permissions_file}."
  fi

  local perms=(
    '/etc/pacman.d/scripts/ 0:0:755'
    '/etc/sudoers.d/ 0:0:750'
    '/etc/profile.d/stack.sh 0:0:644'
    '/etc/systemd/logind.conf.d/ 0:0:644'
    '/etc/systemd/sleep.conf.d/ 0:0:644'
    '/etc/tlp.d/ 0:0:755'
    '/root/.config/bspwm/ 0:0:755'
    '/root/.config/dunst/hook 0:0:755'
    '/root/.config/polybar/scripts/ 0:0:755'
    '/root/.config/rofi/launch 0:0:755'
    '/root/.config/stack/ 0:0:664'
    '/root/.config/cool-retro-term/reset 0:0:755'
    '/opt/stack/commons/ 0:0:755'
    '/opt/stack/tools/ 0:0:755'
    '/usr/local/bin/ 0:0:755'
  )

  local perm=''
  
  for perm in "${perms[@]}"; do
    local path=''
    path="$(echo "${perm}" | cut -d ' ' -f 1)" ||
      abort ERROR 'Failed to extract permission path.'
    
    local mode=''
    mode="$(echo "${perm}" | cut -d ' ' -f 2)" ||
      abort ERROR 'Failed to extract permission mode.'

    sed -i "/file_permissions=(/a [\"${path}\"]=\"${mode}\"" "${permissions_file}" ||
      abort ERROR "Unable to add file permission ${mode} to ${path}."
    
    log INFO "Permission ${mode} added to ${path}."
  done
}

# Saves the current branch and commit hash as the
# live media build version.
save_build_version () {
  local branch=''
  branch="$(git branch --show-current)" ||
    abort ERROR 'Failed to read the current branch.'
  
  local commit=''
  commit="$(git log --pretty=format:'%H' -n 1)" ||
    abort ERROR 'Failed to read the last commit id.'

  local version="{\"branch\": \"${branch}\", \"commit\": \"${commit}\"}"
  
  echo "${version}" | jq . > "${ROOT_FS}/root/.version" ||
    abort ERROR 'Failed to save the version file.'
  
  log INFO "Build version set to ${branch} [${commit:0:5}]."
}

# Creates the iso file of the live media.
make_iso_file () {
  log INFO 'Building the archiso file...'

  if directory_not_exists "${PROFILE_DIR}"; then
    abort ERROR 'Unable to locate the profile folder.'
  fi

  sudo mkarchiso -v -r -w "${WORK_DIR}" -o "${DIST_DIR}" "${PROFILE_DIR}" ||
    abort ERROR 'Failed to build the archiso file.'

  log INFO "Archiso file has been exported at ${DIST_DIR}."
  log INFO 'Build process completed successfully.'
}

log INFO 'Starting the build process...'

init &&
  check_build_deps &&
  copy_iso_profile &&
  declare_packages &&
  build_aur_packages &&
  build_source_packages &&
  sync_root_files &&
  sync_commons &&
  sync_tools &&
  rename_distro &&
  fix_boot_loaders &&
  setup_auto_login &&
  setup_display_server &&
  setup_shell_environment &&
  setup_desktop &&
  setup_keyboard &&
  setup_theme &&
  setup_fonts &&
  enable_services &&
  set_file_permissions &&
  save_build_version &&
  make_iso_file
