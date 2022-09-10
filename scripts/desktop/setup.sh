#!/usr/bin/env bash

setup_compositor () {
  echo "Installing the picom compositor..."

  sudo pacman -S --noconfirm picom

  local CONFIG_HOME=~/.config/picom
  local CONFIG_FILE="$CONFIG_HOME/picom.conf"

  mkdir -p "$CONFIG_HOME"
  cp ~/stack/scripts/desktop/picom/picom.conf "$CONFIG_HOME"

  if [ "$IS_VIRTUAL_BOX" = "yes" ]; then
    echo "Virtual box machine detected"

    sed -i 's/vsync = true;/vsync = false;/' "$CONFIG_FILE"

    echo -e "Vsync has been disabled"
  fi

  echo "Configuration has been set under ~/.config/picom"
  echo "Compositor has been installed"
}

setup_window_manager () {
  echo "Installing BSPWM as the window manager..."

  sudo pacman -S --noconfirm bspwm

  local CONFIG_HOME=~/.config/bspwm
  local CONFIG_FILE="$CONFIG_HOME/bspwmrc"
  local RULES_FILE="$CONFIG_HOME/rules"

  mkdir -p "$CONFIG_HOME"

  cp ~/stack/scripts/desktop/bspwm/bspwmrc "$CONFIG_FILE"
  chmod 755 "$CONFIG_FILE"

  cp ~/stack/scripts/desktop/bspwm/rules "$RULES_FILE"
  chmod 755 "$RULES_FILE"

  echo "Window manager has been installed"
}

setup_bars () {
  echo "Setting up the status bar via polybar..."

  sudo pacman -S --noconfirm polybar

  local CONFIG_HOME=~/.config/polybar
  local CONFIG_FILE="$CONFIG_HOME/config.ini"
  local LAUNCH_FILE="$CONFIG_HOME/launch.sh"

  mkdir -p "$CONFIG_HOME"

  cp ~/stack/scripts/desktop/polybar/config.ini "$CONFIG_FILE"
  chmod 644 "$CONFIG_FILE"

  cp ~/stack/scripts/desktop/polybar/launch.sh "$LAUNCH_FILE"
  chmod 755 "$LAUNCH_FILE"

  echo "Polybar launcher script has been installed"
  echo "Status bars have been installed"
}

setup_launchers () {
  echo "Setting up the launchers via rofi..."

  sudo pacman -S --noconfirm rofi rofi-emoji rofi-calc xsel

  local CONFIG_HOME=~/.config/rofi
  local CONFIG_FILE="$CONFIG_HOME/rofi.rasi"
  local POWER_FILE=/usr/local/bin/power

  mkdir -p "$CONFIG_HOME"

  cp ~/stack/scripts/desktop/rofi/rofi.rasi "$CONFIG_FILE"
  chmod 644 "$CONFIG_FILE"

  sudo cp ~/stack/scripts/desktop/rofi/power "$POWER_FILE"
  sudo chmod 755 "$POWER_FILE"

  echo "Power launcher has been installed"
  echo "Launchers has been installed"
}

setup_login_Screen () {
  echo "Setting up the getty login screen..."

  sudo pacman -S --noconfirm figlet
  yay -S --noconfirm figlet-fonts figlet-fonts-extra

  sudo mv /etc/issue /etc/issue.bak
  sudo cp ~/stack/scripts/desktop/getty/issue.sh /etc

  echo "Welcome screen theme has been set"

  sudo cp ~/stack/scripts/desktop/getty/login-issue.service /etc/systemd/system
  sudo systemctl enable login-issue

  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" /lib/systemd/system/getty@.service
  sudo sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" /lib/systemd/system/serial-getty@.service

  echo "Login issue service has been enabled"
  echo "Login screen has been set"
}

setup_screen_locker () {
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

setup_wallpaper () {
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
  cp ~/stack/scripts/desktop/feh/fehbg "$FEHBG_FILE"

  echo "Startup background script installed"
  echo "Desktop wallpaper has been set"
}

setup_bindings () {
  echo "Setting up key bindings via sxhkd..."

  sudo pacman -S --noconfirm sxhkd

  local CONFIG_HOME=~/.config/sxhkd
  local CONFIG_FILE="$CONFIG_HOME/sxhkdrc"

  mkdir -p "$CONFIG_HOME"

  cp ~/stack/scripts/desktop/sxhkd/sxhkdrc "$CONFIG_FILE"
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
  echo "~/.config/feh/.fehbg &" >> "$CONFIG_FILE"
  echo "picom --fade-in-step=1 --fade-out-step=1 --fade-delta=0 &" >> "$CONFIG_FILE"
  echo "exec bspwm" >> "$CONFIG_FILE"

  local BASH_PROFILE=~/.bash_profile

  echo '' >> "$BASH_PROFILE"
  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$BASH_PROFILE"

  echo "Xorg session set to be started automatically after user logins"
  echo "Xorg configuration saved to ~/.xinitrc"
}

echo -e "\nStarting the desktop installation process..."

source ~/stack/.options

setup_compositor &&
  setup_window_manager &&
  setup_bars &&
  setup_launchers &&
  setup_login_Screen &&
  setup_screen_locker &&
  setup_wallpaper &&
  setup_bindings &&
  config_xorg

echo -e "\nSetting up the desktop has been completed"
echo "Moving to the next process..."
sleep 5
