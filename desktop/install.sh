#!/usr/bin/env bash

install_compositor () {
  echo "Installing the picom compositor..."

  sudo pacman -S --noconfirm picom

  local CONFIG_HOME=~/.config/picom
  local CONFIG_FILE="$CONFIG_HOME/picom.conf"

  mkdir -p "$CONFIG_HOME"
  cp ~/stack/desktop/picom/picom.conf "$CONFIG_HOME"

  if [ "$IS_VIRTUAL_BOX" = "yes" ]; then
    echo "Virtual box machine detected"

    sed -i 's/vsync = true;/vsync = false;/' "$CONFIG_FILE"

    echo -e "Vsync has been disabled"
  fi

  echo "Configuration has been set under ~/.config/picom"
  echo "Compositor has been installed"
}

install_window_manager () {
  echo "Installing BSPWM as the window manager..."

  sudo pacman -S --noconfirm bspwm

  local CONFIG_HOME=~/.config/bspwm
  local CONFIG_FILE="$CONFIG_HOME/bspwmrc"
  local RULES_FILE="$CONFIG_HOME/rules"

  mkdir -p "$CONFIG_HOME"

  cp ~/stack/desktop/bspwm/bspwmrc "$CONFIG_FILE"
  chmod 755 "$CONFIG_FILE"

  cp ~/stack/desktop/bspwm/rules "$RULES_FILE"
  chmod 755 "$RULES_FILE"

  echo "Window manager has been installed"
}

install_file_manager () {
  echo "Installing the file manager..."

  sudo pacman -S --noconfirm nnn fzf

  local CONFIG_HOME=~/.config/nnn

  mkdir -p "$CONFIG_HOME"
  cp ~/stack/desktop/nnn/env "$CONFIG_HOME"

  echo "Installing extra nnn plugins..."

  local GETPLUGS_URL="https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs"

  curl "$GETPLUGS_URL" -sSLo "$CONFIG_HOME/getplugs" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  HOME=~/ sh "$CONFIG_HOME/getplugs" > /dev/null

  echo "Extra plugins have been installed"

  cp ~/stack/desktop/nnn/remove "$CONFIG_HOME/plugins"
  chmod 755 "$CONFIG_HOME/plugins/remove"

  echo "Plugin remove has been installed"

  cp ~/stack/desktop/nnn/trash "$CONFIG_HOME/plugins"
  chmod 755 "$CONFIG_HOME/plugins/trash"

  echo "Plugin trash has been installed"

  cp ~/stack/desktop/nnn/mount "$CONFIG_HOME/plugins"
  chmod 755 "$CONFIG_HOME/plugins/mount"

  echo "Plugin mount has been installed"

  mkdir -p ~/downloads ~/documents ~/images ~/audios ~/videos ~/virtuals ~/sources ~/data ~/media

  echo -e "User home directories have been created"

  echo -e '\nsource "$HOME/.config/nnn/env"' >> ~/.bashrc
  sudo sed -i 's/Exec=nnn/Exec=alacritty -e nnn/' /usr/share/applications/nnn.desktop
  sed -ri 's/(.*)# mocp$/\1alacritty -e mocp \&/' "$CONFIG_HOME/plugins/mocq"

  echo "File manager hooks have been installed"
  echo "File manager has been installed"
}

install_trash () {
  echo "Installing the trash via the trash-cli..."

  sudo pacman -S --noconfirm trash-cli

  sudo cp ~/stack/desktop/trash-cli/trash.sh /usr/local/bin/trash
  sudo chmod 755 /usr/local/bin/trash

  echo "Added a proxy binary to orchestrate trash-cli commands"

  echo -e '\nalias rr="rm"' >> ~/.bashrc
  echo -e 'alias tt="trash"\n' >> ~/.bashrc

  echo "Set aliases for rm and trash"
  echo "Trash has been installed"
}

install_bars () {
  echo "Setting up the status bar via polybar..."

  sudo pacman -S --noconfirm polybar

  local CONFIG_HOME=~/.config/polybar
  local CONFIG_FILE="$CONFIG_HOME/config.ini"
  local LAUNCH_FILE="$CONFIG_HOME/launch.sh"

  mkdir -p "$CONFIG_HOME"

  cp ~/stack/desktop/polybar/config.ini "$CONFIG_FILE"
  chmod 644 "$CONFIG_FILE"

  cp ~/stack/desktop/polybar/launch.sh "$LAUNCH_FILE"
  chmod 755 "$LAUNCH_FILE"

  echo "Polybar launcher script has been installed"
  echo "Status bars have been installed"
}

install_launchers () {
  echo "Setting up the launchers via rofi..."

  sudo pacman -S --noconfirm rofi rofi-emoji rofi-calc xsel

  local CONFIG_HOME=~/.config/rofi
  local CONFIG_FILE="$CONFIG_HOME/rofi.rasi"
  local POWER_FILE=/usr/local/bin/power

  mkdir -p "$CONFIG_HOME"

  cp ~/stack/desktop/rofi/rofi.rasi "$CONFIG_FILE"
  chmod 644 "$CONFIG_FILE"

  sudo cp ~/stack/desktop/rofi/power "$POWER_FILE"
  sudo chmod 755 "$POWER_FILE"

  echo "Power launcher has been installed"
  echo "Launchers has been installed"
}

install_login_Screen () {
  echo "Setting up the getty login screen..."

  sudo pacman -S --noconfirm figlet
  yay -S --noconfirm figlet-fonts figlet-fonts-extra

  sudo mv /etc/issue /etc/issue.bak
  sudo cp ~/stack/desktop/getty/issue.sh /etc

  echo "Welcome screen theme has been set"

  sudo cp ~/stack/desktop/getty/login-issue.service /etc/systemd/system
  sudo systemctl enable login-issue

  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" /lib/systemd/system/getty@.service
  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" /lib/systemd/system/serial-getty@.service

  echo "Login issue service has been enabled"
  echo "Login screen has been set"
}

install_screen_locker () {
  echo "Installing the screen locker..."

  cd ~/ &&
    curl https://dl.suckless.org/tools/slock-1.4.tar.gz -sSLo ./slock-1.4.tar.gz \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  tar -xzvf ./slock-1.4.tar.gz
  
  cd ~/slock-1.4 &&
    curl https://tools.suckless.org/slock/patches/control-clear/slock-git-20161012-control-clear.diff -sSLo ./control-clear.diff \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  patch -p1 < ./control-clear.diff

  echo "Control clear patch has been added"

  sed -ri 's/(.*)nogroup(.*)/\1nobody\2/' ./config.def.h
  sed -ri 's/.*INIT.*/  [INIT] = "#1a1b26",/' ./config.def.h
  sed -ri 's/.*INPUT.*/  [INPUT] = "#383c4a",/' ./config.def.h
  sed -ri 's/.*FAILED.*/  [FAILED] = "#ff2369"/' ./config.def.h
  sed -ri 's/(.*)controlkeyclear.*/\1controlkeyclear = 1;/' ./config.def.h

  echo "Lock screen color theme has been applied"

  sudo make install
  cd / && rm -rf ~/slock-1.4 ~/slock-1.4.tar.gz

  echo -e "Screen locker has been installed"
}

install_wallpaper () {
  echo "Setting up the desktop wallpaper..."

  sudo pacman -S --noconfirm feh

  local WALLPAPERS_HOME=~/images/wallpapers
  local WALLPAPERS_HOST="https://images.hdqwalls.com/wallpapers"
  local FILE_NAME="arch-liinux-4k-t0.jpg"

  mkdir -p "$WALLPAPERS_HOME"
  curl "$WALLPAPERS_HOST/$FILE_NAME" -sSLo "$WALLPAPERS_HOME/$FILE_NAME" \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  
  echo "Default wallpaper has been se to $FILE_NAME"

  local CONFIG_HOME=~/.config/feh
  local FEHBG_FILE="$CONFIG_HOME/.fehbg"

  mkdir -p "$CONFIG_HOME"
  cp ~/stack/desktop/feh/fehbg "$FEHBG_FILE"

  echo "Startup background script installed"
  echo "Desktop wallpaper has been set"
}

install_theme () {
  echo "Installing theme, icons and cursors..."

  local THEME_URL="https://github.com/dracula/gtk/archive/master.zip"

  sudo curl "$THEME_URL" -sSLo /usr/share/themes/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60

  sudo unzip -q /usr/share/themes/Dracula.zip -d /usr/share/themes
  sudo mv /usr/share/themes/gtk-master /usr/share/themes/Dracula
  sudo rm -f /usr/share/themes/Dracula.zip

  echo "Theme has been installed"

  local ICONS_URL="https://github.com/dracula/gtk/files/5214870/Dracula.zip"

  sudo curl "$ICONS_URL" -sSLo /usr/share/icons/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60

  sudo unzip -q /usr/share/icons/Dracula.zip -d /usr/share/icons
  sudo rm -f /usr/share/icons/Dracula.zip

  echo "Theme icons have been installed"

  local CURSORS_URL="https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=0"

  sudo curl "$CURSORS_URL" -sSLo /usr/share/icons/breeze-snow.tgz \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60

  sudo tar -xzf /usr/share/icons/breeze-snow.tgz -C /usr/share/icons
  sudo sed -ri 's/Inherits=.*/Inherits=Breeze-Snow/' /usr/share/icons/default/index.theme
  sudo rm -f /usr/share/icons/breeze-snow.tgz

  echo "Cursors have been installed"

  local GTK_HOME=~/.config/gtk-3.0

  mkdir -p "$GTK_HOME"
  cp ~/stack/desktop/gtk/settings.ini "$GTK_HOME"

  echo "Theme has been setup"
}

install_fonts () {
  echo -e "\nInstalling extra fonts..."

  local FONTS_HOME="/usr/share/fonts/extra-fonts"
  mkdir -p "$FONTS_HOME"

  local FONTS=(
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
  )

  for FONT in "${FONTS[@]}"; do
    local NAME=$(echo "$FONT" | cut -d " " -f 1)
    local URL=$(echo "$FONT" | cut -d " " -f 2)

    curl "$URL" -sSLo "$FONTS_HOME/$NAME.zip" \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
    unzip -q "$FONTS_HOME/$NAME.zip" -d "$FONTS_HOME/$NAME"

    find "$FONTS_HOME/$NAME/" -depth -mindepth 1 -iname "*windows*" -exec rm -r {} +
    find "$FONTS_HOME/$NAME/" -depth -mindepth 1 -iname "*macosx*" -exec rm -r {} +
    find "$FONTS_HOME/$NAME/" -depth -type f -not -iname "*ttf*" -delete
    find "$FONTS_HOME/$NAME/" -empty -type d -delete
    rm -f "$FONTS_HOME/$NAME.zip"

    echo "Font $NAME has been installed"
  done

  fc-cache -f

  echo "Fonts have been installed under $FONTS_HOME"

  echo -e "\nInstalling some extra font glyphs..."

  pacman -S --noconfirm \
    ttf-font-awesome noto-fonts-emoji

  echo "Extra font glyphs have been installed"
}

setup_layouts () {
  echo -e "\nSetting the keyboard layouts..."

  local OLD_IFS=$IFS && IFS=","
  LAYOUTS="${LAYOUTS[*]}" && IFS=$OLD_IFS

  printf '%s\n' \
    'Section "InputClass"' \
    '  Identifier "system-keyboard"' \
    '  MatchIsKeyboard "on"' \
    '  Option "XkbLayout" "'${LAYOUTS}'"' \
    '  Option "XkbModel" "pc105"' \
    '  Option "XkbOptions" "grp:alt_shift_toggle"' \
    'EndSection' > /etc/X11/xorg.conf.d/00-keyboard.conf

  echo "Keyboard layouts have been set to $LAYOUTS"
}

setup_bindings () {
  echo "Setting up key bindings via sxhkd..."

  sudo pacman -S --noconfirm sxhkd

  local CONFIG_HOME=~/.config/sxhkd
  local CONFIG_FILE="$CONFIG_HOME/sxhkdrc"

  mkdir -p "$CONFIG_HOME"

  cp ~/stack/desktop/sxhkd/sxhkdrc "$CONFIG_FILE"
  chmod 644 "$CONFIG_FILE"

  echo "Key bindings have been set"
}

config_xorg () {
  echo "Setting up xorg configuration..."

  local CONFIG_FILE=~/.xinitrc

  cp /etc/X11/xinit/xinitrc "$CONFIG_FILE"

  sed -i '/twm &/d' "$CONFIG_FILE"
  sed -i '/xclock -geometry 50x50-1+1 &/d' "$CONFIG_FILE"
  sed -i '/xterm -geometry 80x50+494+51 &/d' "$CONFIG_FILE"
  sed -i '/xterm -geometry 80x20+494-0 &/d' "$CONFIG_FILE"
  sed -i '/exec xterm -geometry 80x66+0+0 -name login/d' "$CONFIG_FILE"

  echo "xsetroot -cursor_name left_ptr" >> "$CONFIG_FILE"
  echo "picom --fade-in-step=1 --fade-out-step=1 --fade-delta=0 &" >> "$CONFIG_FILE"
  echo "~/.config/feh/.fehbg &" >> "$CONFIG_FILE"
  echo 'udiskie --notify-command "ln -s /run/media/$USER $HOME/media/local" &' >> "$CONFIG_FILE"
  echo "exec bspwm" >> "$CONFIG_FILE"

  local BASH_PROFILE=~/.bash_profile

  echo '' >> "$BASH_PROFILE"
  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$BASH_PROFILE"

  echo "Xorg session set to be started automatically after user logins"
  echo "Xorg configuration saved to ~/.xinitrc"
}

echo -e "\nStarting the desktop installation process..."

source ~/stack/.options

install_compositor &&
  install_window_manager &&
  install_file_manager &&
  install_trash &&
  install_bars &&
  install_launchers &&
  install_login_Screen &&
  install_screen_locker &&
  install_wallpaper &&
  install_theme &&
  install_fonts &&
  setup_layouts &&
  setup_bindings &&
  config_xorg

echo -e "\nSetting up the desktop has been completed"
echo "Moving to the next process..."
sleep 5
