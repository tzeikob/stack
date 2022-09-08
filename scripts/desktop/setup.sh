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

setup_bindings () {
  echo "Setting up key bindings via sxhkd..."

  sudo pacman -S --noconfirm sxhkd

  local CONFIG_HOME=~/.config/sxhkd
  local CONFIG_FILE="$CONFIG_HOME/sxhkdrc"

  cp ~/stack/scripts/desktop/sxhkd/sxhkdrc "$CONFIG_HOME"
  chmod 644 "$CONFIG_HOME"

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
  setup_bindings &&
  config_xorg

echo -e "\nSetting up the desktop has been completed"
echo "Moving to the next process..."
sleep 5
