#!/usr/bin/env bash


echo -e "Starting the stack installation process..."

read -p "Do you want to install a desktop environment? [Y/n] " answer
answer=${answer:-"yes"}

if [[ $answer =~ ^(yes|y)$ ]]; then
  echo -e "Installing the BSPWM window manager..."

  pacman -S feh firefox sxiv mpv

  echo -e "Setting up the desktop environment configuration..."

  curl $config_url/mime -sSo /home/$username/.config/mimeapps.list \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60
  chmod 644 /home/$username/.config/mimeapps.list

  chown -R $username:$username /home/$username/.config

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

  echo "~/.fehbg &" >> /home/$username/.xinitrc
  echo "udiskie --notify-command \"ln -s /run/media/$USER $HOME/media/local\" &" >> /home/$username/.xinitrc

  chown -R $username:$username /home/$username/.xinitrc

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

echo -e "\nThe stack script has been completed"
echo -e "Exiting the script and prepare for reboot..."