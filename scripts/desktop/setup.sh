#!/usr/bin/env bash

setup_compositor () {
  echo "Installing the picom compositor..."

  pacman -S --noconfirm picom

  local CONFIG_HOME="/home/$USERNAME/.config/picom"
  local CONFIG_FILE="$CONFIG_HOME/picom.conf"

  mkdir -p "$CONFIG_HOME"
  cp "/home/$USERNAME/stack/scripts/desktop/picom.conf" "$CONFIG_HOME"

  if [ "$IS_VIRTUAL_BOX" = "yes" ]; then
    echo "Virtual box machine detected"

    sed -i 's/vsync = true;/vsync = false;/' "$CONFIG_FILE"

    echo -e "Vsync has been disabled"
  fi

  echo "Configuration has been set under ~/.config/picom"
  echo "Compositor has been installed"
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

  local BASH_PROFILE="/home/$USERNAME/.bash_profile"

  echo '' >> "$BASH_PROFILE"
  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> "$BASH_PROFILE"

  echo "Xorg session set to be started automatically after user logins"

  echo "Xorg configuration set to ~/.xinitrc"
  echo "Xorg configuration has been completed"
}

echo -e "\nStarting the desktop installation process..."

source "~/stack/.options"

setup_compositor &&
  config_xorg

echo -e "\nSetting up the desktop has been completed"
echo "Moving to the next process..."
sleep 5
