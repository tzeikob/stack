#!/bin/bash

set -Eeo pipefail

source src/commons/process.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh

SETTINGS=./settings.json

# Installs the desktop compositor.
install_compositor () {
  log INFO 'Installing the desktop compositor...'

  sudo pacman -S --needed --noconfirm picom 2>&1 ||
    abort ERROR 'Failed to install picom.'

  log INFO 'Desktop compositor picom has been installed.'
}

# Installs the window manager.
install_window_manager () {
  log INFO 'Installing the window manager...'

  sudo pacman -S --needed --noconfirm bspwm 2>&1 ||
    abort ERROR 'Failed to install bspwm.'

  log INFO 'Window manager bspwm has been installed.'
}

# Installs the desktop status bars.
install_status_bars () {
  log INFO 'Installing the desktop status bars...'

  sudo pacman -S --needed --noconfirm polybar 2>&1 ||
    abort ERROR 'Failed to install polybar.'

  log INFO 'Status bars have been installed.'
}

# Installs the desktop launchers.
install_launchers () {
  log INFO 'Installing the desktop launchers...'

  sudo pacman -S --needed --noconfirm rofi 2>&1 ||
    abort ERROR 'Failed to install rofi.'

  log INFO 'Desktop launchers have been installed.'
}

# Installs the keyboard key bindinds and shortcuts.
install_keyboard_bindings () {
  log INFO 'Setting up the keyboard key bindings...'

  sudo pacman -S --needed --noconfirm sxhkd 2>&1 ||
    abort ERROR 'Failed to install sxhkd.'

  log INFO 'Keyboard key bindings have been set.'
}

# Installs the login screen.
install_login_screen () {
  log INFO 'Installing the login screen...'

  sudo pacman -S --needed --noconfirm figlet 2>&1 &&
    yay -S --needed --noconfirm --removemake figlet-fonts figlet-fonts-extra 2>&1 ||
    abort ERROR 'Failed to install figlet packages.'
  
  log INFO 'Figlet packages have been installed.'

  sudo mv /etc/issue /etc/issue.bak ||
    abort ERROR 'Failed to backup the issue file.'

  log INFO 'The issue file has been backed up to /etc/issue.bak.'

  local host_name=''
  host_name="$(jq -cer '.host_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read host_name setting.'

  echo " ${host_name} " | figlet -f pagga 2>&1 | sudo tee /etc/issue > /dev/null ||
    abort ERROR 'Failed to create the new issue file.'
  
  echo -e '\n' | sudo tee -a /etc/issue > /dev/null ||
    abort ERROR 'Failed to create the new issue file.'
  
  log INFO 'The new issue file has been created.'

  sudo sed -ri \
    "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" \
    /lib/systemd/system/getty@.service ||
    abort ERROR 'Failed to set no hostname mode to getty service.'

  sudo sed -ri \
    "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" \
    /lib/systemd/system/serial-getty@.service ||
    abort ERROR 'Failed to set no hostname mode to serial getty service.'

  log INFO 'Login screen has been installed.'
}

# Installs the screen locker.
install_screen_locker () {
  log INFO 'Installing the screen locker...'

  sudo pacman -S --needed --noconfirm xautolock python-cairo python-pam 2>&1 &&
    yay -S --needed --noconfirm --removemake python-screeninfo 2>&1 ||
    abort ERROR 'Failed to install the locker dependencies.'

  log INFO 'Locker dependencies have been installed.'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local xsecurelock_home="/home/${user_name}/xsecurelock"

  git clone https://github.com/tzeikob/xsecurelock.git "${xsecurelock_home}" 2>&1 &&
    cd "${xsecurelock_home}" &&
    sh autogen.sh 2>&1 &&
    ./configure --with-pam-service-name=system-auth 2>&1 &&
    make 2>&1 &&
    sudo make install 2>&1 &&
    cd ~ &&
    rm -rf "${xsecurelock_home}" ||
    abort ERROR 'Failed to install xsecurelock.'
  
  log INFO 'Xsecurelock has been installed.'

  local user_id=''
  user_id="$(
    id -u "${user_name}" 2>&1
  )" || abort ERROR 'Failed to get the user id.'

  local service_file="/etc/systemd/system/lock@.service"

  sudo sed -i "s/#USER_ID#/${user_id}/g" "${service_file}" &&
    sudo systemctl enable lock@${user_name}.service 2>&1 ||
    abort ERROR 'Failed to enable locker service.'

  log INFO 'Locker service has been enabled.'
  log INFO 'Screen locker has been installed.'
}

# Installs the notifications server.
install_notification_server () {
  log INFO 'Installing notifications server...'

  sudo pacman -S --needed --noconfirm dunst 2>&1 ||
    abort ERROR 'Failed to install dunst.'

  log INFO 'Notifications server has been installed.'
}

# Installs the file manager.
install_file_manager () {
  log INFO 'Installing the file manager...'

  sudo pacman -S --needed --noconfirm nnn fzf 2>&1 ||
    abort ERROR 'Failed to install nnn.'

  log INFO 'Nnn has been installed.'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local config_home="/home/${user_name}/.config/nnn"

  log INFO 'Installing file manager plugins...'

  # Todo: get current working directory error
  local pluggins_url='https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs'

  curl "${pluggins_url}" -sSLo "${config_home}/getplugs" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    cd "/home/${user_name}" &&
    HOME="/home/${user_name}" sh "${config_home}/getplugs" 2>&1 ||
    abort ERROR 'Failed to install extra plugins.'

  log INFO 'Extra plugins have been installed.'

  mkdir -p "/home/${user_name}"/{downloads,documents,data,sources,mounts} &&
    mkdir -p "/home/${user_name}"/{images,audios,videos} ||
    abort ERROR 'Failed to create home directories.'
  
  log INFO 'Home directories have been created.'
  log INFO 'File manager has been installed.'
}

# Installs the trash manager.
install_trash_manager () {
  log INFO 'Installing the trash manager...'

  sudo pacman -S --needed --noconfirm trash-cli 2>&1 ||
    abort ERROR 'Failed to install trash-cli.'

  log INFO 'Trash manager has been installed.'
}

# Installs the virtual terminals.
install_terminals () {
  log INFO 'Installing virtual terminals...'

  sudo pacman -S --needed --noconfirm alacritty cool-retro-term 2>&1 ||
    abort ERROR 'Failed to install terminal packages.'

  log INFO 'Virtual terminals have been installed.'
}

# Installs the text editor.
install_text_editor () {
  log INFO 'Installing the text editor...'

  sudo pacman -S --needed --noconfirm helix 2>&1 ||
    abort ERROR 'Failed to install helix.'

  log INFO 'Text editor has been installed.'
}

# Installing monitor tools.
install_monitor_tools () {
  log INFO 'Installing monitor tools...'

  sudo pacman -S --needed --noconfirm htop glances 2>&1 ||
    abort ERROR 'Failed to install monitor tools.'

  log INFO 'Monitor tools have been installed.'
}

# Installs the print screen and recording casters.
install_screen_casters () {
  log INFO 'Installing screen casting tools...'

  sudo pacman -S --needed --noconfirm scrot 2>&1 &&
    yay -S --needed --noconfirm --removemake --mflags --nocheck slop screencast 2>&1 ||
    abort ERROR 'Failed to install screen casting tools.'

  log INFO 'Screen casting tools have been installed.'
}

# Installs the calculator.
install_calculator () {
  log INFO 'Installing the calculator...'

  sudo pacman -S --needed --noconfirm libqalculate 2>&1 ||
    abort ERROR 'Failed to install qalculate.'

  log INFO 'Calculator has been installed.'
}

# Installs the media viewer.
install_media_viewer () {
  log INFO 'Installing the media viewer...'

  sudo pacman -S --needed --noconfirm sxiv 2>&1 ||
    abort ERROR 'Failed to install sxiv.'

  log INFO 'Media viewer has been installed.'
}

# Installs the music player.
install_music_player () {
  log INFO 'Installing the music player...'
  
  sudo pacman -S --needed --noconfirm mpd ncmpcpp 2>&1 ||
    abort ERROR 'Failed to install the music player.'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local config_home="/home/${user_name}/.config"

  mkdir -p \
    "${config_home}/mpd/playlists" \
    "${config_home}/mpd/database" ||
    abort ERROR 'Failed to create mpd directories.'

  sudo systemctl --user enable mpd.service 2>&1 ||
    abort ERROR 'Failed to enable mpd service.'

  log INFO 'Mpd service has been enabled.'
  log INFO 'Music player has been installed.'
}

# Installs the video media player.
install_video_player () {
  log INFO 'Installing video media player...'

  sudo pacman -S --needed --noconfirm mpv 2>&1 ||
    abort ERROR 'Failed to install mpv.'

  log INFO 'Video media player has been installed.'
}

# Installs the audio and video media codecs.
install_media_codecs () {
  log INFO 'Installing audio and video media codecs...'

  sudo pacman -S --needed --noconfirm \
    faad2 ffmpeg4.4 libmodplug libmpcdec speex taglib wavpack 2>&1 ||
    abort ERROR 'Failed to install audio and video codecs.'

  log INFO 'Media codecs have been installed.'
}

# Installs the desktop and ui theme.
install_theme () {
  log INFO 'Installing the desktop theme...'

  local theme_url='https://github.com/dracula/gtk/archive/master.zip'

  local themes_home='/usr/share/themes'

  sudo curl "${theme_url}" -sSLo "${themes_home}/Dracula.zip" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    sudo unzip -q "${themes_home}/Dracula.zip" -d "${themes_home}" 2>&1 &&
    sudo mv "${themes_home}/gtk-master" "${themes_home}/Dracula" &&
    sudo rm -f "${themes_home}/Dracula.zip" ||
    abort ERROR 'Failed to install theme files.'

  log INFO 'Theme files have been installed.'

  local icons_url='https://github.com/dracula/gtk/files/5214870/Dracula.zip'

  local icons_home='/usr/share/icons'

  sudo curl "${icons_url}" -sSLo "${icons_home}/Dracula.zip" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    sudo unzip -q "${icons_home}/Dracula.zip" -d "${icons_home}" 2>&1 &&
    sudo rm -f "${icons_home}/Dracula.zip" ||
    abort ERROR 'Failed to install icon files.'

  log INFO 'Icon files have been installed.'

  local cursors_url='https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1'

  sudo wget "${cursors_url}" -qO "${icons_home}/breeze-snow.tgz" \
    --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 3 2>&1 &&
    sudo tar -xzf "${icons_home}/breeze-snow.tgz" -C "${icons_home}" 2>&1 &&
    sudo sed -ri 's/Inherits=.*/Inherits=Breeze-Snow/' "${icons_home}/default/index.theme" &&
    sudo rm -f "${icons_home}/breeze-snow.tgz" ||
    abort ERROR 'Failed to install cursors.'

  log INFO 'Cursors have been installed.'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  sed -i \
    -e 's/#THEME#/Dracula/' \
    -e 's/#ICONS#/Dracula/' \
    -e 's/#CURSORS#/Breeze-Snow/' "/home/${user_name}/.config/gtk-3.0/settings.ini" ||
    abort ERROR 'Failed to set theme in GTK settings.'

  log INFO 'Desktop theme has been setup.'
}

# Installs extras system fonts.
install_fonts () {
  local fonts_home='/usr/share/fonts/extra-fonts'

  sudo mkdir -p "${fonts_home}" ||
    abort ERROR 'Failed to create fonts home directory.'

  log INFO 'Installing extra fonts...'

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

    sudo curl "${url}" -sSLo "${fonts_home}/${name}.zip" \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
      sudo unzip -q "${fonts_home}/${name}.zip" -d "${fonts_home}/${name}" 2>&1 &&
      sudo chmod -R 755 "${fonts_home}/${name}" &&
      sudo rm -f "${fonts_home}/${name}.zip" ||
      abort ERROR "Failed to install font ${name}."

    log INFO "Font ${name} has been installed."
  done

  log INFO 'Installing google fonts...'

  git clone --filter=blob:none --sparse https://github.com/google/fonts.git google-fonts 2>&1 &&
    cd google-fonts &&
    git sparse-checkout add apache/cousine apache/robotomono ofl/sharetechmono ofl/spacemono 2>&1 &&
    sudo cp -r apache/cousine apache/robotomono ofl/sharetechmono ofl/spacemono "${fonts_home}" &&
    cd .. && rm -rf google-fonts ||
    abort ERROR 'Failed to install google fonts.'
  
  log 'Google fonts have been installed.'

  log INFO 'Updating the fonts cache...'

  fc-cache -f 2>&1 ||
    abort ERROR 'Failed to update the fonts cache.'

  log INFO 'Fonts cache has been updated.'
  log INFO 'Installing some extra glyphs...'

  sudo pacman -S --needed --noconfirm ttf-font-awesome noto-fonts-emoji 2>&1 ||
    abort ERROR 'Failed to install extra glyphs.'

  log INFO 'Extra glyphs have been installed.'
}

# Installs various extra packages.
install_extra_packages () {
  log INFO 'Installing some extra packages...'

  yay -S --needed --noconfirm --removemake \
    smenu digimend-kernel-drivers-dkms-git xkblayout-state-git 2>&1 ||
    abort ERROR 'Failed to install extra packages.'
  
  log INFO 'Extra packages have been installed.'
}

# Sets up the root and user shell environments.
setup_shell_environment () {
  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local stackrc_file="/home/${user_name}/.stackrc"

  # Set the defauilt terminal and text editor
  sed -i \
    -e 's/#TERMINAL#/alacritty/' \
    -e 's/#EDITOR#/helix/' "${stackrc_file}" ||
    abort ERROR 'Failed to set the terminal defaults.'

  log INFO 'Default terminal set to cool-retro-term.'
  log INFO 'Default editor set to helix.'
  
  local bashrc_file="/home/${user_name}/.bashrc"

  sed -i \
    -e '/PS1.*/d' \
    -e '$a\'$'\n''source "${HOME}/.stackrc"' "${bashrc_file}" ||
    abort ERROR 'Failed to add stackrc hook into bashrc.'

  sudo cp "/home/${user_name}/.stackrc" /root/.stackrc

  bashrc_file='/root/.bashrc'

  sudo sed -i \
    -e '/PS1.*/d' \
    -e '$a\'$'\n''source "${HOME}/.stackrc"' "${bashrc_file}" ||
    abort ERROR 'Failed to add stackrc hook into bashrc.'
}

log INFO 'Script desktop.sh started.'
log INFO 'Installing the desktop...'

if equals "$(id -u)" 0; then
  abort ERROR 'Script desktop.sh must be run as non root user.'
fi

install_compositor &&
  install_window_manager &&
  install_status_bars &&
  install_launchers &&
  install_keyboard_bindings &&
  install_login_screen &&
  install_screen_locker &&
  install_notification_server &&
  install_file_manager &&
  install_trash_manager &&
  install_terminals &&
  install_text_editor &&
  install_monitor_tools &&
  install_screen_casters &&
  install_calculator &&
  install_media_viewer &&
  install_music_player &&
  install_video_player &&
  install_media_codecs &&
  install_theme &&
  install_fonts &&
  install_extra_packages &&
  setup_shell_environment

log INFO 'Script desktop.sh has finished.'

resolve desktop 2750 && sleep 2
