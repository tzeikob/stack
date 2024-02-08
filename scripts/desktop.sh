#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the desktop compositor.
install_compositor () {
  log 'Installing the desktop compositor...'

  sudo pacman -S --noconfirm picom 2>&1 ||
    fail 'Failed to install picom'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/picom"

  mkdir -p "${config_home}" || fail

  cp /opt/stack/configs/picom/picom.conf "${config_home}" ||
    fail 'Failed to copy compositor config file'

  log 'Desktop compositor picom has been installed'
}

# Installs the window manager.
install_window_manager () {
  log 'Installing the window manager...'

  sudo pacman -S --noconfirm bspwm 2>&1 ||
    fail 'Failed to install bspwm'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/bspwm"

  mkdir -p "${config_home}" || fail

  cp /opt/stack/configs/bspwm/bspwmrc "${config_home}" &&
    chmod 755 "${config_home}/bspwmrc" &&
    cp /opt/stack/configs/bspwm/rules "${config_home}" &&
    chmod 755 "${config_home}/rules" &&
    cp /opt/stack/configs/bspwm/resize "${config_home}" &&
    chmod 755 "${config_home}/resize" &&
    cp /opt/stack/configs/bspwm/swap "${config_home}" &&
    chmod 755 "${config_home}/swap" &&
    cp /opt/stack/configs/bspwm/scratchpad "${config_home}" &&
    chmod 755 "${config_home}/scratchpad" ||
    fail 'Failed to copy the bspwm config files'

  log 'Window manager bspwm has been installed'
}

# Installs the desktop status bars.
install_status_bars () {
  log 'Installing the desktop status bars...'

  sudo pacman -S --noconfirm polybar 2>&1 ||
    fail 'Failed to install polybar'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/polybar"

  mkdir -p "${config_home}" || fail

  cp /opt/stack/configs/polybar/config.ini "${config_home}" &&
    chmod 644 "${config_home}/config.ini" &&
    cp /opt/stack/configs/polybar/modules.ini "${config_home}" &&
    chmod 644 "${config_home}/modules.ini" &&
    cp /opt/stack/configs/polybar/theme.ini "${config_home}" &&
    chmod 644 "${config_home}/theme.ini" &&
    cp -r /opt/stack/configs/polybar/scripts "${config_home}" &&
    chmod +x "${config_home}"/scripts/* ||
    fail 'Failed to copy polybar config files'

  log 'Status bars have been installed'
}

# Installs the utility tools for managing system settings.
install_settings_manager () {
  log 'Installing settings manager tools...'

  yay -S --noconfirm --removemake smenu 2>&1 ||
    fail 'Failed to install smenu'

  local tools_home='/opt/tools'

  sudo mkdir -p "${tools_home}" &&
    sudo cp -r /opt/stack/tools/* "${tools_home}" ||
    fail 'Failed to install setting manager tools'

  local bin_home='/usr/local/bin'

  # Create symlinks to expose executables
  sudo ln -sf "${tools_home}/displays/main" "${bin_home}/displays" &&
    sudo ln -sf "${tools_home}/desktop/main" "${bin_home}/desktop" &&
    sudo ln -sf "${tools_home}/audio/main" "${bin_home}/audio" &&
    sudo ln -sf "${tools_home}/clock/main" "${bin_home}/clock" &&
    sudo ln -sf "${tools_home}/cloud/main" "${bin_home}/cloud" &&
    sudo ln -sf "${tools_home}/networks/main" "${bin_home}/networks" &&
    sudo ln -sf "${tools_home}/disks/main" "${bin_home}/disks" &&
    sudo ln -sf "${tools_home}/bluetooth/main" "${bin_home}/bluetooth" &&
    sudo ln -sf "${tools_home}/langs/main" "${bin_home}/langs" &&
    sudo ln -sf "${tools_home}/notifications/main" "${bin_home}/notifications" &&
    sudo ln -sf "${tools_home}/power/main" "${bin_home}/power" &&
    sudo ln -sf "${tools_home}/printers/main" "${bin_home}/printers" &&
    sudo ln -sf "${tools_home}/security/main" "${bin_home}/security" &&
    sudo ln -sf "${tools_home}/trash/main" "${bin_home}/trash" &&
    sudo ln -sf "${tools_home}/system/main" "${bin_home}/system" ||
    fail 'Failed to create symlinks to /usr/local/bin'

  log 'Settings manager tools have been installed'
}

# Installs the desktop launchers.
install_launchers () {
  log 'Installing the desktop launchers...'

  sudo pacman -S --noconfirm rofi 2>&1 ||
    fail 'Failed to install rofi'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/rofi"

  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/rofi/config.rasi "${config_home}" &&
    chmod 644 "${config_home}/config.rasi" &&
    cp /opt/stack/configs/rofi/launch "${config_home}" &&
    chmod +x "${config_home}/launch" ||
    fail 'Failed to copy rofi config files'

  log 'Desktop launchers have been installed'
}

# Installs the keyboard key bindinds and shortcuts.
install_keyboard_bindings () {
  log 'Setting up the keyboard key bindings...'

  sudo pacman -S --noconfirm sxhkd 2>&1 ||
    fail 'Failed to install sxhkd'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/sxhkd"

  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/sxhkd/sxhkdrc "${config_home}" &&
    chmod 644 "${config_home}/sxhkdrc" ||
    fail 'Failed to copy sxhkdrc configs files'

  log 'Keyboard key bindings have been set'
}

# Installs the login screen.
install_login_screen () {
  log 'Installing the login screen...'

  sudo pacman -S --noconfirm figlet 2>&1 &&
    yay -S --noconfirm --removemake figlet-fonts figlet-fonts-extra 2>&1 ||
    fail 'Failed to install figlet packages'
  
  log 'Figlet packages have been installed'

  sudo mv /etc/issue /etc/issue.bak ||
    fail 'Failed to backup the issue file'

  log 'The issue file has been backed up to /etc/issue.bak'

  local host_name=''
  host_name="$(get_setting 'host_name')" || fail

  figlet -f pagga " ${host_name} " 2>&1 | sudo tee /etc/issue > /dev/null ||
    fail 'Failed to create the new issue file'
  
  log 'The new issue file has been created'

  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" \
    /lib/systemd/system/getty@.service ||
    fail 'Failed to set no hostname mode to getty service'

  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" \
    /lib/systemd/system/serial-getty@.service ||
    fail 'Failed to set no hostname mode to serial getty service'

  log 'Login screen has been installed'
}

# Installs the screen locker.
install_screen_locker () {
  log 'Installing the screen locker...'

  sudo pacman -S --noconfirm xautolock python-cairo python-pam 2>&1 &&
    yay -S --noconfirm --removemake python-screeninfo 2>&1 ||
    fail 'Failed to install the locker dependencies'

  log 'Locker dependencies have been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local xsecurelock_home="/home/${user_name}/xsecurelock"

  git clone https://github.com/tzeikob/xsecurelock.git "${xsecurelock_home}" 2>&1 &&
    cd "${xsecurelock_home}" &&
    sh autogen.sh 2>&1 &&
    ./configure --with-pam-service-name=system-auth 2>&1 &&
    make 2>&1 &&
    sudo make install 2>&1 &&
    cd ~ &&
    rm -rf "${xsecurelock_home}" ||
    fail 'Failed to install xsecurelock'
  
  log 'Xsecurelock has been installed'

  sudo cp /opt/stack/configs/xsecurelock/hook /usr/lib/systemd/system-sleep/locker ||
    fail 'Failed to copy the sleep hook'
  
  log 'Sleep hook has been copied'

  local user_id=''
  user_id="$(
    id -u "${user_name}" 2>&1
  )" || fail 'Failed to get the user id'

  local service_file="/etc/systemd/system/lock@.service"

  sudo cp /opt/stack/configs/xsecurelock/service "${service_file}" &&
    sudo sed -i "s/#USER_ID/${user_id}/g" "${service_file}" &&
    sudo systemctl enable lock@${user_name}.service 2>&1 ||
    fail 'Failed to enable locker service'

  log 'Locker service has been enabled'
  log 'Screen locker has been installed'
}

# Installs the notifications server.
install_notification_server () {
  log 'Installing notifications server...'

  sudo pacman -S --noconfirm dunst 2>&1 ||
    fail 'Failed to install dunst'

  log 'Dunst has been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/dunst"

  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/dunst/dunstrc "${config_home}" &&
    cp /opt/stack/configs/dunst/hook "${config_home}" ||
    fail 'Failed to copy notifications server config files'

  log 'Notifications server has been installed'
}

# Installs the file manager.
install_file_manager () {
  log 'Installing the file manager...'

  sudo pacman -S --noconfirm nnn fzf 2>&1 ||
    fail 'Failed to install nnn'

  log 'Nnn has been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/nnn"

  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/nnn/env "${config_home}" ||
    fail 'Failed to copy the env file'
  
  log 'Env file has been copied'

  log 'Installing file manager plugins...'

  # Todo: get current working directory error
  local pluggins_url='https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs'

  curl "${pluggins_url}" -sSLo "${config_home}/getplugs" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    cd "/home/${user_name}" &&
    HOME="/home/${user_name}" sh "${config_home}/getplugs" 2>&1 ||
    fail 'Failed to install extra plugins'

  log 'Extra plugins have been installed'

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nsource "${HOME}/.config/nnn/env"' >> "${bashrc_file}" &&
    echo 'alias N="sudo -E nnn -dH"' >> "${bashrc_file}" ||
    fail 'Failed to add hooks in .bashrc file'

  log 'File manager hooks added in .bashrc file'

  mkdir -p "/home/${user_name}"/{downloads,documents,data,sources,mounts} &&
    mkdir -p "/home/${user_name}"/{images,audios,videos} &&
    cp /opt/stack/configs/nnn/user.dirs "/home/${user_name}/.config/user-dirs.dirs" ||
    fail 'Failed to create home directories'
  
  log 'Home directories have been created'

  printf '%s\n' \
    '[Default Applications]' \
    'inode/directory=nnn.desktop' > "/home/${user_name}/.config/mimeapps.list" &&
    chmod 644 "/home/${user_name}/.config/mimeapps.list" ||
    fail 'Failed to create the applications mime type file'

  log 'Application mime types file has been created'
  log 'File manager has been installed'
}

# Installs the trash manager.
install_trash_manager () {
  log 'Installing the trash manager...'

  sudo pacman -S --noconfirm trash-cli 2>&1 ||
    fail 'Failed to install trash-cli'

  log 'Trash-cli has been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e "\nalias sudo='sudo '" >> "${bashrc_file}" &&
    echo "alias tt='trash-put -i'" >> "${bashrc_file}" &&
    echo "alias rm='rm -i'" >> "${bashrc_file}" ||
    fail 'Failed to add aliases to .bashrc file'
  
  log 'Aliases have been added to .bashrc file'

  bashrc_file='/root/.bashrc'
  
  echo -e "\nalias sudo='sudo '" | sudo tee -a "${bashrc_file}" > /dev/null &&
    echo "alias tt='trash-put -i'" | sudo tee -a "${bashrc_file}" > /dev/null &&
    echo "alias rm='rm -i'" | sudo tee -a "${bashrc_file}" > /dev/null ||
    fail 'Failed to add aliases to root .bashrc file'
  
  log 'Aliases have been added to root .bashrc file'
  log 'Trash manager has been installed'
}

# Installs the virtual terminals.
install_terminals () {
  log 'Installing virtual terminals...'

  sudo pacman -S --noconfirm alacritty cool-retro-term 2>&1 ||
    fail 'Failed to install terminal packages'

  log 'Alacritty and cool-retro-term have been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/alacritty"

  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/alacritty/alacritty.toml "${config_home}" ||
    fail 'Failed to copy the alacritty config file'
  
  log 'Alacritty config file has been copied'

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport TERMINAL=alacritty' >> "${bashrc_file}" &&
    sed -i '/PS1.*/d' "${bashrc_file}" &&
    cat /opt/stack/configs/alacritty/user.prompt >> "${bashrc_file}" ||
    fail 'Failed to add hooks in the .bashrc file'
  
  log 'Hooks have been added in the .bashrc file'

  sudo sed -i '/PS1.*/d' /root/.bashrc &&
    cat /opt/stack/configs/alacritty/root.prompt | sudo tee -a /root/.bashrc > /dev/null ||
    fail 'Failed to add hooks in the root .bashrc file'

  log 'Hooks have been added in the root .bashrc file'
  log 'Virtual terminals have been installed'
}

# Installs the text editor.
install_text_editor () {
  log 'Installing the text editor...'

  sudo pacman -S --noconfirm helix 2>&1 ||
    fail 'Failed to install helix'

  log 'Helix has been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport EDITOR=helix' >> "${bashrc_file}" ||
    fail 'Failed to set helix as default editor'

  log 'Helix set as default editor'
  log 'Text editor has been installed'
}

# Installs the web browsers.
install_web_browsers () {
  log 'Installing the web browsers...'

  sudo pacman -S --noconfirm firefox torbrowser-launcher 2>&1 &&
    yay -S --noconfirm --removemake google-chrome brave-bin 2>&1 ||
    fail 'Failed to install web browsers'

  log 'Web browsers have been installed'
}

# Installing monitoring tools.
install_monitoring_tools () {
  log 'Installing monitoring tools...'

  sudo pacman -S --noconfirm htop glances 2>&1 ||
    fail 'Failed to install monitoring tools'

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || fail

  local desktop_file="${desktop_home}/glances.desktop"

  printf '%s\n' \
   '[Desktop Entry]' \
   'Type=Application' \
   'Name=Glances' \
   'comment=Console Monitor' \
   'Exec=glances' \
   'Terminal=true' \
   'Icon=glances' \
   'Catogories=Monitor;Resources;System;Console' \
   'Keywords=Monitor;Resources;System' | sudo tee "${desktop_file}" > /dev/null ||
   fail 'Failed to create the desktop file'

  log 'Monitoring tools have been installed'
}

# Installs the print screen and recording casters.
install_screen_casters () {
  log 'Installing screen casting tools...'

  sudo pacman -S --noconfirm scrot 2>&1 &&
    yay -S --noconfirm --removemake --mflags --nocheck slop screencast 2>&1 ||
    fail 'Failed to install screen casting tools'

  log 'Screen casting tools have been installed'
}

# Installs the calculator.
install_calculator () {
  log 'Installing the calculator...'

  yay -S --noconfirm --removemake libqalculate 2>&1 ||
    fail 'Failed to install qalculate'

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || fail

  local desktop_file="${desktop_home}/qalculate.desktop"

  printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    'Name=qalculate' \
    'comment=Console Calculator' \
    'Exec=qalc' \
    'Terminal=true' \
    'Icon=qalculate' \
    'Catogories=Math;Calculator;Console' \
    'Keywords=Calc;Math' | sudo tee "${desktop_file}" > /dev/null ||
    fail 'Failed to create desktop file'

  log 'Calculator has been installed'
}

# Installs the media viewer.
install_media_viewer () {
  log 'Installing the media viewer...'

  sudo pacman -S --noconfirm sxiv 2>&1 ||
    fail 'Failed to install sxiv'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config"

  printf '%s\n' \
    'image/jpeg=sxiv.desktop' \
    'image/jpg=sxiv.desktop' \
    'image/png=sxiv.desktop' \
    'image/tiff=sxiv.desktop' >> "${config_home}/mimeapps.list" ||
    fail 'Failed to add image mime types'
  
  log 'Image mime types have been added'
  log 'Media viewer has been installed'
}

# Installs the music player.
install_music_player () {
  log 'Installing the music player...'
  
  sudo pacman -S --noconfirm mpd ncmpcpp 2>&1 ||
    fail 'Failed to install the music player'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config"

  local mpd_home="/${config_home}/mpd"

  mkdir -p "${mpd_home}"/{playlists,database} ||
    fail 'Failed to create mpd config directories'

  cp /opt/stack/configs/mpd/conf "${mpd_home}/mpd.conf" ||
    fail 'Failed to copy the mpd config file'

  local ncmpcpp_home="/${config_home}/ncmpcpp"

  mkdir -p "${ncmpcpp_home}" &&
    cp /opt/stack/configs/ncmpcpp/config "${ncmpcpp_home}/config" ||
    fail 'Failed to copy ncmpcpp config file'

  sudo systemctl --user enable mpd.service 2>&1 ||
    fail 'Failed to enable mpd service'

  log 'Mpd service has been enabled'

  local desktop_home='/usr/local/share/applications'

  sudo mkdir -p "${desktop_home}" || fail

  local desktop_file="${desktop_home}/ncmpcpp.desktop"

  printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    'Name=Ncmpcpp' \
    'comment=Console music player' \
    'Exec=ncmpcpp' \
    'Terminal=true' \
    'Icon=ncmpcpp' \
    'MimeType=audio/mpeg' \
    'Catogories=Music;Player;ConsoleOnly' \
    'Keywords=Music;Player;Audio' | sudo tee "${desktop_file}" > /dev/null ||
    fail 'Failed to create the desktop file'
  
  printf '%s\n' \
    'audio/mpeg=ncmpcpp.desktop' \
    'audio/mp3=ncmpcpp.desktop' \
    'audio/flac=ncmpcpp.desktop' \
    'audio/midi=ncmpcpp.desktop' >> "${config_home}/mimeapps.list" ||
    fail 'Failed to add audio mime types'
  
  log 'Audio mime types have been added'
  log 'Music player has been installed'
}

# Installs the video media player.
install_video_player () {
  log 'Installing video media player...'

  sudo pacman -S --noconfirm mpv 2>&1 ||
    fail 'Failed to install mpv'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config"

  printf '%s\n' \
    'video/mp4=mpv.desktop' \
    'video/mkv=mpv.desktop' \
    'video/mov=mpv.desktop' \
    'video/mpeg=mpv.desktop' \
    'video/avi=mpv.desktop' >> "${config_home}/mimeapps.list" ||
    fail 'Failed to add video mime types'
  
  log 'Video mime types have been added'
  log 'Video media player has been installed'
}

# Installs the audio and video media codecs.
install_media_codecs () {
  log 'Installing audio and video media codecs...'

  sudo pacman -S --noconfirm \
    faad2 ffmpeg4.4 libmodplug libmpcdec speex taglib wavpack 2>&1 ||
    fail 'Failed to install audio and video codecs'

  log 'Media codecs have been installed'
}

# Installs the office tools.
install_office_tools () {
  log 'Installing the office tools...'

  sudo pacman -S --noconfirm libreoffice-fresh 2>&1 ||
    fail 'Failed to install office tools'

  log 'Office tools have been installed'
}

# Installs the pdf and epub readers.
install_readers () {
  log 'Installing pdf and epub readers...'

  sudo pacman -S --noconfirm foliate 2>&1 &&
    yay -S --noconfirm --useask --removemake --diffmenu=false evince-no-gnome poppler 2>&1 ||
    fail 'Failed to install pdf and epub readers'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config"

  printf '%s\n' \
    'application/epub+zip=com.github.johnfactotum.Foliate.desktop' \
    'application/pdf=org.gnome.Evince.desktop' >> "${config_home}/mimeapps.list" ||
    fail 'Failed to add pdf and epub mime types'
  
  log 'Pdf and epub mime types have been added'
  log 'Pdf and epub readers have been installed'
}

# Installs the torrent client.
install_torrent_client () {
  log 'Installing the torrent client...'

  sudo pacman -S --noconfirm transmission-cli 2>&1 ||
    fail 'Failed to install transmission-cli'

  log 'Torrent client has been installed'
}

# Installs the desktop and ui theme.
install_theme () {
  log 'Installing the desktop theme...'

  local theme_url='https://github.com/dracula/gtk/archive/master.zip'

  sudo curl "${theme_url}" -sSLo /usr/share/themes/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    sudo unzip -q /usr/share/themes/Dracula.zip -d /usr/share/themes 2>&1 &&
    sudo mv /usr/share/themes/gtk-master /usr/share/themes/Dracula &&
    sudo rm -f /usr/share/themes/Dracula.zip ||
    fail 'Failed to install theme files'

  log 'Theme files have been installed'

  local icons_url='https://github.com/dracula/gtk/files/5214870/Dracula.zip'

  sudo curl "${icons_url}" -sSLo /usr/share/icons/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    sudo unzip -q /usr/share/icons/Dracula.zip -d /usr/share/icons 2>&1 &&
    sudo rm -f /usr/share/icons/Dracula.zip ||
    fail 'Failed to install icon files'

  log 'Icon files have been installed'

  local cursors_url='https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=1'

  sudo wget "${cursors_url}" -qO /usr/share/icons/breeze-snow.tgz \
    --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 3 2>&1 &&
    sudo tar -xzf /usr/share/icons/breeze-snow.tgz -C /usr/share/icons 2>&1 &&
    sudo sed -ri 's/Inherits=.*/Inherits=Breeze-Snow/' /usr/share/icons/default/index.theme &&
    sudo rm -f /usr/share/icons/breeze-snow.tgz ||
    fail 'Failed to install cursors'

  log 'Cursors have been installed'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local config_home="/home/${user_name}/.config/gtk-3.0"
  
  mkdir -p "${config_home}" &&
    cp /opt/stack/configs/gtk/settings.ini "${config_home}" ||
    fail 'Failed to copy gtk settings file'

  log 'Gtk settings file has been copied'

  local wallpapers_home="/home/${user_name}/.local/share/wallpapers"

  mkdir -p "${wallpapers_home}" &&
    cp /opt/stack/resources/wallpapers/* "${wallpapers_home}" ||
    fail 'Failed to copy wallpapers'
  
  log 'Wallpapers have been copied'

  config_home="/home/${user_name}/.config/stack"

  mkdir -p "${config_home}" || fail

  local settings='{"wallpaper": {"name": "default.jpeg", "mode": "fill"}}'

  echo "${settings}" > "${config_home}/desktop.json" ||
    fail 'Failed to add wallpaper into the desktop settings file'

  log 'Wallpaper has been set into the desktop settings file'
  log 'Desktop theme has been setup'
}

# Installs extras system fonts.
install_fonts () {
  log 'Installing extra fonts...'

  local fonts_home='/usr/share/fonts/extra-fonts'

  sudo mkdir -p "${fonts_home}" ||
    fail 'Failed to create fonts home directory'

  local fonts=(
    "FiraCode https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"
    "FantasqueSansMono https://github.com/belluzj/fantasque-sans/releases/download/v1.8.0/FantasqueSansMono-Normal.zip"
    "Hack https://github.com/source-foundry/Hack/releases/download/v3.003/Hack-v3.003-ttf.zip"
    "Hasklig https://github.com/i-tu/Hasklig/releases/download/v1.2/Hasklig-1.2.zip"
    "JetBrainsMono https://github.com/JetBrains/JetBrainsMono/releases/download/v2.242/JetBrainsMono-2.242.zip"
    "Mononoki https://github.com/madmalik/mononoki/releases/download/1.3/mononoki.zip"
    "VictorMono https://rubjo.github.io/victor-mono/VictorMonoAll.zip"
    "Cousine https://fonts.google.com/download?family=Cousine"
    "RobotoMono https://fonts.google.com/download?family=Roboto%20Mono"
    "ShareTechMono https://fonts.google.com/download?family=Share%20Tech%20Mono"
    "SpaceMono https://fonts.google.com/download?family=Space%20Mono"
    "PixelMix https://dl.dafont.com/dl/?f=pixelmix"
  )

  local font=''

  for font in "${fonts[@]}"; do
    local name=''
    name="$(echo "${font}" | cut -d ' ' -f 1)" || fail

    local url=''
    url="$(echo "${font}" | cut -d ' ' -f 2)" || fail

    sudo curl "${url}" -sSLo "${fonts_home}/${name}.zip" \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
      sudo unzip -q "${fonts_home}/${name}.zip" -d "${fonts_home}/${name}" 2>&1 &&
      sudo chmod -R 755 "${fonts_home}/${name}" &&
      sudo rm -f "${fonts_home}/${name}.zip" ||
      fail "Failed to install font ${name}"

    log "Font ${name} has been installed"
  done

  log 'Update the fonts cache...'

  fc-cache -f 2>&1 ||
    fail 'Failed to update the fonts cache'

  log 'Fonts cache has been updated'
  log 'Installing some extra glyphs...'

  sudo pacman -S --noconfirm ttf-font-awesome noto-fonts-emoji 2>&1 ||
    fail 'Failed to install extra glyphs'

  log 'Extra glyphs have been installed'
}

# Installs various system sound resources.
install_sounds () {
  log 'Installing extra system sounds...'

  local sounds_home='/usr/share/sounds/stack'
  
  sudo mkdir -p "${sounds_home}" &&
    sudo cp /opt/stack/resources/sounds/normal.wav "${sounds_home}" &&
    sudo cp /opt/stack/resources/sounds/critical.wav "${sounds_home}" ||
    fail 'Failed to copy system sound files'

  log 'System sounds have been installed'
}

# Installs various extra packages.
install_extra_packages () {
  log 'Installing some extra packages...'

  yay -S --noconfirm --removemake \
    digimend-kernel-drivers-dkms-git xkblayout-state-git 2>&1 ||
    fail 'Failed to install extra packages'
  
  log 'Extra packages have been installed'
}

log 'Installing the desktop...'

if equals "$(id -u)" 0; then
  fail 'Script desktop.sh must be run as non root user'
fi

install_compositor &&
  install_window_manager &&
  install_status_bars &&
  install_settings_manager &&
  install_launchers &&
  install_keyboard_bindings &&
  install_login_screen &&
  install_screen_locker &&
  install_notification_server &&
  install_file_manager &&
  install_trash_manager &&
  install_terminals &&
  install_text_editor &&
  install_web_browsers &&
  install_monitoring_tools &&
  install_screen_casters &&
  install_calculator &&
  install_media_viewer &&
  install_music_player &&
  install_video_player &&
  install_media_codecs &&
  install_office_tools &&
  install_readers &&
  install_torrent_client &&
  install_theme &&
  install_fonts &&
  install_sounds &&
  install_extra_packages

sleep 3
