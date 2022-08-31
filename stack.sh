#!/usr/bin/env bash


echo -e "Starting the stack installation process..."

read -p "Do you want to install a desktop environment? [Y/n] " answer
answer=${answer:-"yes"}

if [[ $answer =~ ^(yes|y)$ ]]; then
  echo -e "Installing the BSPWM window manager..."

  pacman -S picom bspwm sxhkd rofi rofi-emoji rofi-calc xsel polybar feh firefox sxiv mpv

  echo -e "Setting up the desktop environment configuration..."

  mkdir -p /home/$username/.config/{picom,bspwm,sxhkd,polybar,rofi}

  curl $config_url/picom -sSo /home/$username/.config/picom/picom.conf \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.config/picom/picom.conf

  curl $config_url/bspwm -sSo /home/$username/.config/bspwm/bspwmrc \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /home/$username/.config/bspwm/bspwmrc

  curl $bin_url/bspwm -sSo /home/$username/.config/bspwm/rules \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /home/$username/.config/bspwm/rules

  curl $config_url/sxhkd -sSo /home/$username/.config/sxhkd/sxhkdrc \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.config/sxhkd/sxhkdrc

  curl $config_url/polybar -sSo /home/$username/.config/polybar/config.ini \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.config/polybar/config.ini

  curl $config_url/rofi -sSo /home/$username/.config/rofi/config.rasi \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.config/rofi/config.rasi

  curl $config_url/mime -sSo /home/$username/.config/mimeapps.list \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.config/mimeapps.list

  chown -R $username:$username /home/$username/.config

  if [[ $virtual_box =~ ^(yes|y)$ ]]; then
    sed -i 's/vsync = true;/vsync = false;/' /home/$username/.config/picom/picom.conf

    echo -e "Vsync setting in picom has been disabled"
  fi

  echo -e "\nSetting up the polybar launcher..."

  cat << 'EOF' > /home/$username/.config/polybar/launch.sh
  #!/usr/bin/env bash

  # Terminate already running bar instances
  # If all your bars have ipc enabled, you can use 
  polybar-msg cmd quit
  # Otherwise you can use the nuclear option:
  # killall -q polybar

  # Launch bar
  echo "---" | tee -a /tmp/polybar.log
  polybar main 2>&1 | tee -a /tmp/polybar.log & disown

  echo "Bars launched..."
EOF

  chmod +x /home/$username/.config/polybar/launch.sh
  chown $username:$username /home/$username/.config/polybar/launch.sh

  echo -e "Polybar launcher has been set"

  echo -e "\nInstalling the screen locker..."

  curl https://dl.suckless.org/tools/slock-1.4.tar.gz -sSLo ./slock-1.4.tar.gz \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  tar -xzvf ./slock-1.4.tar.gz

  cd /slock-1.4

  curl https://tools.suckless.org/slock/patches/control-clear/slock-git-20161012-control-clear.diff -sSLo ./control-clear.diff \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  patch -p1 < ./control-clear.diff

  sed -ri 's/(.*)nogroup(.*)/\1nobody\2/' ./config.def.h
  sed -ri 's/.*INIT.*/  [INIT] = "#1a1b26",/' ./config.def.h
  sed -ri 's/.*INPUT.*/  [INPUT] = "#383c4a",/' ./config.def.h
  sed -ri 's/.*FAILED.*/  [FAILED] = "#ff2369"/' ./config.def.h
  sed -ri 's/(.*)controlkeyclear.*/\1controlkeyclear = 1;/' ./config.def.h
  make install
  cd / && rm -rf /slock-1.4 /slock-1.4.tar.gz

  echo -e "Screen lock has been set"

  echo -e "Installing the power launcher via rofi script..."

  curl $bin_url/power -sSo /usr/local/bin/power \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /usr/local/bin/power

  echo -e "\n$username $hostname =NOPASSWD: /sbin/shutdown now,/sbin/reboot" >> /etc/sudoers

  echo -e "User '$username' has granted to trigger power events"

  echo -e "Power launcher has been installed"

  cp /etc/X11/xinit/xinitrc /home/$username/.xinitrc

  sed -i '/twm &/d' /home/$username/.xinitrc
  sed -i '/xclock -geometry 50x50-1+1 &/d' /home/$username/.xinitrc
  sed -i '/xterm -geometry 80x50+494+51 &/d' /home/$username/.xinitrc
  sed -i '/xterm -geometry 80x20+494-0 &/d' /home/$username/.xinitrc
  sed -i '/exec xterm -geometry 80x66+0+0 -name login/d' /home/$username/.xinitrc

  echo "xsetroot -cursor_name left_ptr" >> /home/$username/.xinitrc
  echo "picom --fade-in-step=1 --fade-out-step=1 --fade-delta=0 &" >> /home/$username/.xinitrc
  echo "~/.fehbg &" >> /home/$username/.xinitrc
  echo "udiskie --notify-command \"ln -s /run/media/$USER $HOME/media/local\" &" >> /home/$username/.xinitrc
  echo "exec bspwm" >> /home/$username/.xinitrc

  chown -R $username:$username /home/$username/.xinitrc

  echo '' >> /home/$username/.bash_profile
  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> /home/$username/.bash_profile

  echo -e "Setting up the wallpaper..."

  mkdir -p /home/$username/images/wallpapers
  curl https://images.hdqwalls.com/wallpapers/arch-liinux-4k-t0.jpg -sSLo /home/$username/images/wallpapers/arch-liinux-4k-t0.jpg \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60

  chown -R $username:$username /home/$username/images/

  cat << EOF > /home/$username/.fehbg
  #!/bin/sh
  feh --no-fehbg --bg-fill '/home/$username/images/wallpapers/arch-liinux-4k-t0.jpg'
EOF

  chown $username:$username /home/$username/.fehbg
  chmod 754 /home/$username/.fehbg

  echo -e "Wallpaper has been set successfully"

  echo -e "Installing the virtual terminal..."

  pacman -S alacritty

  mkdir -p /home/$username/.config/alacritty

  curl $config_url/alacritty -sSo /home/$username/.config/alacritty/alacritty.yml \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chown -R $username:$username /home/$username/.config/alacritty

  sed -i '/PS1.*/d' /home/$username/.bashrc
  echo -e "\nbranch () {" >> /home/$username/.bashrc
  echo ' git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/  [\\1]/"' >> /home/$username/.bashrc
  echo -e "}\n" >> /home/$username/.bashrc
  echo "PS1='\W\[\e[0;35m\]\$(branch)\[\e[m\]  '" >> /home/$username/.bashrc

  echo -e '\nexport EDITOR="nano"' >> /home/$username/.bashrc

  cp /etc/skel/.bash_profile /root
  cp /etc/skel/.bashrc /root
  sed -i '/PS1.*/d' /root/.bashrc
  echo -e "PS1='\[\e[1;31m\]\u\[\e[m\] \W  '" >> /root/.bashrc

  echo -e "Virtual terminal has been installed"

  echo -e "Installing the theme, icons and cursors..."

  theme_url="https://github.com/dracula/gtk/archive/master.zip"
  curl $theme_url -sSLo /usr/share/themes/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  unzip -q /usr/share/themes/Dracula.zip -d /usr/share/themes
  mv /usr/share/themes/gtk-master /usr/share/themes/Dracula
  rm -f /usr/share/themes/Dracula.zip

  echo -e "Theme files have been installed under '/usr/share/themes'"

  icons_url="https://github.com/dracula/gtk/files/5214870/Dracula.zip"
  curl $icons_url -sSLo /usr/share/icons/Dracula.zip \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  unzip -q /usr/share/icons/Dracula.zip -d /usr/share/icons
  rm -f /usr/share/icons/Dracula.zip

  echo -e "Icon files have been installed under '/usr/share/icons'"

  cursors_url="https://www.dropbox.com/s/mqt8s1pjfgpmy66/Breeze-Snow.tgz?dl=0"
  curl $cursors_url -sSLo /usr/share/icons/breeze-snow.tgz \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  tar -xzf /usr/share/icons/breeze-snow.tgz -C /usr/share/icons
  rm -f /usr/share/icons/breeze-snow.tgz

  sed -ri 's/Inherits=.*/Inherits=Breeze-Snow/' /usr/share/icons/default/index.theme

  echo -e "Cursor files have been installed under '/usr/share/icons'"

  mkdir -p /home/$username/.config/gtk-3.0
  curl $config_url/gtk -sSo /home/$username/.config/gtk-3.0/settings.ini \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60

  chown -R $username:$username /home/$username/.config/gtk-3.0

  echo -e "Theme, icons and cursors have been installed"

  echo -e "Installing the file manager..."

  pacman -S nnn fzf

  mkdir -p /home/$username/.config/nnn
  curl $config_url/nnn -sSo /home/$username/.config/nnn/.env_vars \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chown -R $username:$username /home/$username/.config/nnn/
  echo -e '\nsource $HOME/.config/nnn/.env_vars' >> /home/$username/.bashrc

  sed -i 's/Exec=nnn/Exec=alacritty -e nnn/' /usr/share/applications/nnn.desktop

  echo -e "File manager set to get open via terminal in xdg-open calls"

  echo -e "Installing extra nnn plugins..."

  curl https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs -sSLo ./nnn-getplugs \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  HOME=/home/$username sh ./nnn-getplugs > /dev/null
  rm -f ./nnn-getplugs

  cp /home/$username/.config/nnn/plugins/mocq /home/$username/.config/nnn/plugins/mocq.bak
  sed -ri 's/(.*)# mocp$/\1alacritty -e mocp \&/' /home/$username/.config/nnn/plugins/mocq

  curl $bin_url/remove-plugin -sSo /home/$username/.config/nnn/plugins/remove \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /home/$username/.config/nnn/plugins/remove

  curl $bin_url/trash-plugin -sSo /home/$username/.config/nnn/plugins/trash \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /home/$username/.config/nnn/plugins/trash

  curl $bin_url/mount-plugin -sSo /home/$username/.config/nnn/plugins/mount \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /home/$username/.config/nnn/plugins/mount

  chown -R $username:$username /home/$username/.config/nnn/plugins

  echo -e "Creating user home directories..."

  mkdir -p /home/$username/downloads \
    /home/$username/documents \
    /home/$username/images \
    /home/$username/audios \
    /home/$username/videos \
    /home/$username/virtuals \
    /home/$username/sources \
    /home/$username/data \
    /home/$username/media

  chown -R $username:$username /home/$username/downloads \
    /home/$username/documents \
    /home/$username/images \
    /home/$username/audios \
    /home/$username/videos \
    /home/$username/virtuals \
    /home/$username/sources \
    /home/$username/data \
    /home/$username/media

  echo -e "Main user home forders have been created"
  echo -e "File manager has been installed"

  echo -e "Installing the music player..."

  sudo pacman -S moc

  echo -e "Installing codecs and various dependecies..."

  sudo pacman -S --asdeps --needed faad2 ffmpeg4.4 libmodplug libmpcdec speex taglib wavpack

  mkdir -p /home/$username/.moc/
  curl $config_url/moc.config -sSo /home/$username/.moc/config \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.moc/config

  mkdir -p /home/$username/.moc/themes
  curl $config_url/moc.theme -sSo /home/$username/.moc/themes/dark \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.moc/themes/dark

  chown -R $username:$username /home/$username/.moc/

  cat << EOF > /usr/share/applications/moc.desktop
[Desktop Entry]
Type=Application
Name=moc
comment=Console music player
Exec=alacritty -e mocp
Terminal=true
Icon=moc
MimeType=audio/mpeg
Catogories=Music;Player;ConsoleOnly
Keywords=Music;Player;Audio
EOF

  echo -e "Music player has been installed"

  echo -e "Installing various document viewers..."

  pacman -S xournalpp poppler foliate

  sudo -u $username yay -S --useask --removemake --nodiffmenu evince-no-gnome > /dev/null

  echo -e "Document viewers have been installed"

  echo -e "Installing the trash..."

  pacman -S trash-cli

  curl $bin_url/trash -sSo /usr/local/bin/trash \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 755 /usr/local/bin/trash

  echo -e '\nalias rr="rm"' >> /home/$username/.bashrc
  echo -e 'alias tt="trash"\n' >> /home/$username/.bashrc

  echo -e "Trash has been installed successfully"

  echo -e "Desktop environment configuration is done"
else
  echo -e "Desktop environment has been skipped"
fi

echo -e "\nInstalling the bootloader via GRUB..."

if [[ $uefi == true ]]; then
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
  grub-install --target=i386-pc $device
fi

sed -i '/#GRUB_SAVEDEFAULT=true/i GRUB_DEFAULT=saved' /etc/default/grub
sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/' /etc/default/grub
sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

if [[ $virtual_box =~ ^(yes|y)$ && $uefi == true ]]; then
  mkdir -p /boot/EFI/BOOT
  cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI
fi

echo -e "Bootloader has been installed"

echo -e "\nHardening system's security..."

sed -i 's;# dir = /var/run/faillock;dir = /var/lib/faillock;' /etc/security/faillock.conf

echo -e "Faillocks set to be persistent after system reboot"

sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

echo -e "Disable permission for SSH with the root user"

echo -e "Setting up a simple stateful firewall..."

nft flush ruleset
nft add table inet my_table
nft add chain inet my_table my_input '{ type filter hook input priority 0 ; policy drop ; }'
nft add chain inet my_table my_forward '{ type filter hook forward priority 0 ; policy drop ; }'
nft add chain inet my_table my_output '{ type filter hook output priority 0 ; policy accept ; }'
nft add chain inet my_table my_tcp_chain
nft add chain inet my_table my_udp_chain
nft add rule inet my_table my_input ct state related,established accept
nft add rule inet my_table my_input iif lo accept
nft add rule inet my_table my_input ct state invalid drop
nft add rule inet my_table my_input meta l4proto ipv6-icmp accept
nft add rule inet my_table my_input meta l4proto icmp accept
nft add rule inet my_table my_input ip protocol igmp accept
nft add rule inet my_table my_input meta l4proto udp ct state new jump my_udp_chain
nft add rule inet my_table my_input 'meta l4proto tcp tcp flags & (fin|syn|rst|ack) == syn ct state new jump my_tcp_chain'
nft add rule inet my_table my_input meta l4proto udp reject
nft add rule inet my_table my_input meta l4proto tcp reject with tcp reset
nft add rule inet my_table my_input counter reject with icmpx port-unreachable

mv /etc/nftables.conf /etc/nftables.conf.bak
nft -s list ruleset > /etc/nftables.conf

echo -e "Firewall ruleset has been saved to '/etc/nftables.conf'"

cat << EOF > /etc/X11/xorg.conf.d/01-screenlock.conf
# Prevents to overpass screen locker by killing xorg or switching vt
Section "ServerFlags"
    Option "DontVTSwitch" "True"
    Option "DontZap"      "True"
EndSection
EOF

echo -e "Security configuration has been completed"

echo -e "\nConfiguring pacman..."

cat << 'EOF' > /usr/share/libalpm/hooks/orphan-packages.hook
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Operation = Remove
Target = *

[Action]
Description = Search for any left over orphan packages
When = PostTransaction
Exec = /usr/bin/bash -c "/usr/bin/pacman -Qtd || /usr/bin/echo 'No orphan packages found'"
EOF

echo -e "Orphan packages post installation hook has been set"

echo -e "Pacman has been configured"

echo -e "Settin up the login screen"

mv /etc/issue /etc/issue.bak
curl $assets_url/issue -sSo /etc/issue \
  --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60

cat << 'EOF' > /etc/systemd/system/login-issue.service
[Unit]
Description=Set login prompt via /etc/issue
Before=getty@tty1.service getty@tty2.service getty@tty3.service getty@tty4.service getty@tty5.service getty@tty6.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sed -i "5s/.*/  $(date)/" /etc/issue'

[Install]
WantedBy=multi-user.target
EOF

systemctl enable login-issue

sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" /lib/systemd/system/getty@.service
sed -ri "s;(ExecStart=-/sbin/agetty)(.*);\1 --nohostname\2;" /lib/systemd/system/serial-getty@.service

echo -e "Login screen has been set"

echo -e "\nEnabling system services..."

systemctl enable systemd-timesyncd
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable acpid
systemctl enable cups
systemctl enable sshd
systemctl enable fstrim.timer
systemctl enable nftables
systemctl enable reflector.timer
systemctl enable paccache.timer

if [[ $virtual_box =~ ^(yes|y)$ ]]; then
  systemctl enable vboxservice
fi

echo -e "\nThe stack script has been completed"
echo -e "Exiting the script and prepare for reboot..."