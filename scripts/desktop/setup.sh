#!/usr/bin/env bash

setup_compositor () {
  echo "Installing the picom compositor..."

  sudo pacman -S --noconfirm picom

  local CONFIG_HOME="/home/$USERNAME/.config/picom"
  local CONFIG_FILE="$CONFIG_HOME/picom.conf"

  mkdir -p "$CONFIG_HOME"
  cp "/home/$USERNAME/stack/scripts/desktop/picom.conf" "$CONFIG_HOME"

  if [ "$IS_VIRTUAL_BOX" = "yes" ]; then
    echo "Virtual box machine detected"

    sed -i 's/vsync = true;/vsync = false;/' "$CONFIG_FILE"

    echo -e "Vsync has been disabled"
  fi

  echo "Configuration has been set under /home/$USERNAME/.config/picom"
  echo "Compositor has been installed"
}

setup_window_manager () {
  echo "Installing BSPWM as the window manager..."

  sudo pacman -S --noconfirm bspwm sxhkd

  local BSPWM_CONFIG_HOME="/home/$USERNAME/.config/bspwm"
  local BSPWMRC="$BSPWM_CONFIG_HOME/bspwmrc"
  local BSPWM_RULES="$BSPWM_CONFIG_HOME/rules"

  mkdir -p BSPWM_CONFIG_HOME

  cp "/home/$USERNAME/stack/scripts/desktop/bspwmrc" "$BSPWM_CONFIG_HOME"
  chmod 755 "$BSPWMRC"

  cp "/home/$USERNAME/stack/scripts/desktop/bspwm-rules" "$BSPWM_CONFIG_HOME"
  chmod 755 "$BSPWM_RULES"

  echo "Window manager has been installed"
}

setup_bars () {
  echo "Setting up the status bar via polybar..."

  sudo pacman -S --noconfirm polybar

  local CONFIG_HOME="/home/$USERNAME/.config/polybar"
  local CONFIG_FILE="$CONFIG_HOME/config.ini"
  local LAUNCH_FILE="$CONFIG_HOME/launch.sh"

  mkdir -p CONFIG_HOME

  cp "/home/$USERNAME/stack/scripts/desktop/polybar/config.ini" "$CONFIG_FILE"
  chmod 644 "$CONFIG_FILE"

  cp "/home/$USERNAME/stack/scripts/desktop/polybar/launch.sh" "$LAUNCH_FILE"
  chmod 755 "$LAUNCH_FILE"

  echo "Polybar launcher script has been installed"
  echo "Status bars have been installed"
}

setup_bindings () {
  echo "Setting up key bindings via sxhkd..."

  sudo pacman -S --noconfirm sxhkd

  local SXHKD_CONFIG_HOME="/home/$USERNAME/.config/sxhkd"
  local SXHKDRC="$SXHKD_CONFIG_HOME/sxhkdrc"

  cp "/home/$USERNAME/stack/scripts/desktop/sxhkdrc" "$SXHKD_CONFIG_HOME"
  chmod 644 "$SXHKDRC"

  echo "Key bindings have been set"
}

config_xorg () {
  echo "Setting up xorg configuration..."

  local CONFIG_FILE="/home/$USERNAME/.xinitrc"

  cp /etc/X11/xinit/xinitrc "$CONFIG_FILE"

  sed -i '/twm &/d' "$CONFIG_FILE"
  sed -i '/xclock -geometry 50x50-1+1 &/d' "$CONFIG_FILE"
  sed -i '/xterm -geometry 80x50+494+51 &/d' "$CONFIG_FILE"
  sed -i '/xterm -geometry 80x20+494-0 &/d' "$CONFIG_FILE"
  sed -i '/exec xterm -geometry 80x66+0+0 -name login/d' "$CONFIG_FILE"

  echo "picom --fade-in-step=1 --fade-out-step=1 --fade-delta=0 &" >> "$CONFIG_FILE"
  echo "exec bspwm" >> "$CONFIG_FILE"

  local BASH_PROFILE="/home/$USERNAME/.bash_profile"

  echo '' >> "$BASH_PROFILE"
  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$BASH_PROFILE"

  echo "Xorg session set to be started automatically after user logins"

  echo "Xorg configuration saved to /home/$USERNAME/.xinitrc"
}

echo -e "\nStarting the desktop installation process..."

source ~/stack/.options

setup_compositor &&
  setup_window_manager &&
  setup_bars &&
  setup_bindings &&
  config_xorg

echo -e "\nSetting up the desktop has been completed"
echo "Moving to the next process..."
sleep 5
