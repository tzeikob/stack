#!/usr/bin/env bash

set -Eeo pipefail

install_firefox () {
  echo "Installing the firefox browser..."

  sudo pacman -S --noconfirm firefox || exit 1

  echo -e "Firefox has been installed\n"
}

install_chrome () {
  echo "Installing the chrome browser..."

  yay -S --noconfirm google-chrome || exit 1

  echo -e "Chrome has been installed\n"
}

install_brave () {
  echo "Installing the brave browser..."

  yay -S --noconfirm brave-bin || exit 1

  echo -e "Brave has been installed\n"
}

install_tor () {
  echo "Installing the tor browser..."

  yay -S --noconfirm tor tor-browser || exit 1

  echo -e "Tor has been installed\n"
}

install_node () {
  echo "Installing the node via NVM..."

  local URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh"
  curl "$URL" -sSLo ~/stack/nvm-install.sh \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1

  bash ~/stack/nvm-install.sh || exit 1
  source ~/.bashrc
  source ~/.nvm/nvm.sh

  echo "NVM has been installed under ~/.nvm"
  echo "Installing latest node versions..."

  nvm install --no-progress --lts || exit 1

  echo "LTS version has been installed"

  nvm install --no-progress node || exit 1

  echo "Stable version has been installed"

  nvm use --lts || exit 1

  echo "Node $(nvm current) is currently in use"

  echo 'export PATH="./node_modules/.bin:$PATH"' >> ~/.bashrc

  echo "Path to global node modules has been added to PATH"
  echo -e "Node has been installed\n"
}

install_deno () {
  echo "Installing the Deno javascript runtime..."

  sudo pacman -S --noconfirm deno || exit 1

  deno --version || exit 1

  echo -e "Deno has been installed\n"
}

install_bun () {
  echo "Installing the Bun javascript runtime..."

  local URL="https://bun.sh/install"
  curl "$URL" -sSLo ~/stack/bun-install.sh \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1

  bash ~/stack/bun-install.sh || exit 1

  echo -e '\nexport BUN_INSTALL="$HOME./bun"' >> ~/.bashrc
  echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc

  bun --version || exit 1

  echo -e "Bun has been installed\n"
}

install_java () {
  echo "Installing the latest java development kit..."

  sudo pacman -S --noconfirm \
    jdk-openjdk openjdk-doc openjdk-src \
    jdk11-openjdk openjdk11-doc openjdk11-src \
    jdk8-openjdk openjdk8-doc openjdk8-src \
    maven || exit 1

  archlinux-java status || exit 1

  echo -e "Java has been installed\n"
}

install_rust () {
  echo "Installing the rust..."

  printf '%s\n' y y |
    sudo pacman -S rustup || exit 1

  echo "Setting the default toolchain..."

  rustup default stable || exit 1

  echo "Rust default toolchain set to stable"

  rustc -V || exit 1

  echo -e "Rust has been installed\n"
}

install_go () {
  echo "Installing the go language..."

  sudo pacman -S --noconfirm go go-tools || exit 1

  go version || exit 1

  echo -e "Go language has been installed\n"
}

install_php () {
  echo "Installing the PHP language..."

  sudo pacman -S --noconfirm \
    php php-apache php-cgi php-fpm php-gd \
    php-embed php-intl php-imap || exit 1

  php -v || exit 1

  echo -e "PHP has been installed\n"
}

install_ruby () {
  echo "Installing the ruby language..."

  sudo pacman -S --noconfirm \
    ruby ruby-irb ruby-rdoc ruby-docs rubygems || exit 1
  
  echo -e '\nexport GEM_HOME="$(ruby -e "puts Gem.user_dir")"' >> ~/.bashrc
  echo 'export PATH="$PATH:$GEM_HOME/bin"' >> ~/.bashrc
  source ~/.bashrc

  ruby -v || exit 1

  echo -e "Ruby language has been installed\n"
}

install_code () {
  echo "Installing the visual studio code..."

  sudo pacman -S --noconfirm code || exit 1

  echo "Installing various extensions..."

  code --install-extension dbaeumer.vscode-eslint
  code --install-extension yzhang.markdown-all-in-one
  code --install-extension streetsidesoftware.code-spell-checker

  echo "Extensions have been installed"

  echo -e "Visual studio code has been installed\n"
}

install_sublime () {
  echo "Installing the sublime text editor..."

  yay -S --noconfirm sublime-text-4 || exit 1

  echo -e "Sublime text has been installed\n"
}

install_neovim () {
  echo "Installing the neovim editor..."

  sudo pacman -S --noconfirm neovim || exit 1

  echo -e "Neovim has been installed\n"
}

install_eclipse () {
  echo "Installing eclipse..."

  yay -S --noconfirm eclipse-jee || exit 1

  echo -e "Eclipse has been installed\n"
}

install_intellij () {
  echo "Installing IntelliJ Idea community..."

  yay -S --noconfirm intellij-idea-ce || exit 1

  sudo sed -ri 's/^Exec=(.*)/Exec=env _JAVA_AWT_WM_NONREPARENTING=1 \1/' \
    /usr/share/applications/intellij-idea-ce.desktop

  echo -e "IntelliJ Idea community has been installed\n"
}

install_webstorm () {
  echo "Installing WebStorm editor..."

  yay -S --noconfirm webstorm || exit 1

  sudo sed -ri 's/^Exec=(.*)/Exec=env _JAVA_AWT_WM_NONREPARENTING=1 \1/' \
    /usr/share/applications/jetbrains-webstorm.desktop

  echo -e "WebStorm editor has been installed\n"
}

install_goland () {
  echo "Installing GoLand editor..."

  yay -S --noconfirm goland || exit 1

  sudo sed -ri 's/^Exec=(.*)/Exec=env _JAVA_AWT_WM_NONREPARENTING=1 \1/' \
    /usr/share/applications/jetbrains-goland.desktop

  echo -e "GoLand editor has been installed\n"
}

install_phpstorm () {
  echo "Installing PHPStorm editor..."

  yay -S --noconfirm phpstorm || exit 1

  sudo sed -ri 's/^Exec=(.*)/Exec=env _JAVA_AWT_WM_NONREPARENTING=1 \1/' \
    /usr/share/applications/jetbrains-phpstorm.desktop

  echo -e "PHPStorm editor has been installed\n"
}

install_pycharm () {
  echo "Installing PyCharm community..."

  sudo pacman -S --noconfirm pycharm-community-edition || exit 1

  sudo sed -ri 's/^Exec=(.*)/Exec=env _JAVA_AWT_WM_NONREPARENTING=1 \1/' \
    /usr/share/applications/pycharm.desktop

  echo -e "PyCharm community has been installed\n"
}

install_rubymine () {
  echo "Installing RubyMine editor..."

  yay -S --noconfirm rubymine || exit 1

  sudo sed -ri 's/^Exec=(.*)/Exec=env _JAVA_AWT_WM_NONREPARENTING=1 \1/' \
    /usr/share/applications/rubymine.desktop

  echo -e "RubyMine editor has been installed\n"
}

install_postman () {
  echo "Installing the postman..."

  yay -S --noconfirm postman-bin || exit 1

  echo -e "Postman has been installed\n"
}

install_compass () {
  echo "Installing mongodb compass..."

  yay -S --noconfirm mongodb-compass || exit 1

  echo -e "MongoDB Compass has been installed\n"
}

install_robo3t () {
  echo "Installing Robo3t..."

  yay -S --noconfirm robo3t-bin || exit 1

  echo -e "Robo3t has been installed\n"
}

install_studio3t () {
  echo "Installing Studio3t..."

  yay -S --noconfirm studio-3t || exit 1

  echo -e "Studio3t has been installed\n"
}

install_dbeaver () {
  echo "Installing the DBeaver..."

  sudo pacman -S --noconfirm dbeaver || exit 1

  echo -e "Dbeaver has been installed\n"
}

install_slack () {
  echo "Installing the slack..."

  yay -S --noconfirm slack-desktop || exit 1

  echo -e "Slack has been installed\n"
}

install_discord () {
  echo "Installing the discord..."

  sudo pacman -S --noconfirm discord || exit 1

  echo -e "Discord has been installed\n"
}

install_skype () {
  echo "Installing the skype..."

  yay -S --noconfirm skypeforlinux-stable-bin || exit 1

  echo -e "Skype has been installed\n"
}

install_teams () {
  echo "Installing the teams..."

  yay -S --noconfirm teams || exit 1

  echo -e "Teams has been installed\n"
}

install_irssi () {
  echo "Installing irssi client..."

  sudo pacman -S --noconfirm irssi || exit 1

  sudo cp ~/stack/apps/irssi/desktop /usr/share/applications/irssi.desktop

  echo -e "Irssi clinet has been installed\n"
}

install_libreoffice () {
  echo "Installing the libre office..."

  sudo pacman -S --noconfirm libreoffice-fresh || exit 1

  echo -e "Libre office has been installed\n"
}

install_xournal () {
  echo "Installing the hand write xounral++ editor..."

  sudo pacman -S --noconfirm xournalpp || exit 1

  printf '%s\n' \
    'application/x-xojpp=com.github.xournalapp.xournalapp.desktop' \
    'application/x-xopp=com.github.xournalapp.xournalapp.desktop' \
    'application/x-xopt=com.github.xournalapp.xournalapp.desktop' >> ~/.config/mimeapps.list

  echo "Mime types has been added"
  echo -e "Xounral++ has been installed\n"
}

install_foliate () {
  echo "Installing the epub foliate viewer..."

  sudo pacman -S --noconfirm foliate || exit 1

  printf '%s\n' \
    'application/epub+zip=com.github.johnfactotum.Foliate.desktop' >> ~/.config/mimeapps.list

  echo "Mime types has been added"
  echo -e "Foliate has been installed\n"
}

install_evince () {
  echo "Installing the evince pdf viewer..."

  yay -S --noconfirm --useask --removemake --nodiffmenu evince-no-gnome poppler > /dev/null || exit 1

  printf '%s\n' \
    'application/pdf=org.gnome.Evince.desktop' >> ~/.config/mimeapps.list

  echo "Mime types has been added"
  echo -e "Evince viewer has been installed\n"
}

install_teamviewer () {
  echo "Installing the team viewer... "

  yay -S --noconfirm teamviewer || exit 1

  echo "Enabling daemon service..."

  sudo systemctl enable teamviewerd || exit 1

  echo "Daemon service has been enabled"

  echo -e "Team viewer has been installed\n"
}

install_anydesk () {
  echo "Installing the AnyDesk... "

  yay -S --noconfirm anydesk-bin || exit 1

  echo "Enabling daemon service..."

  sudo systemctl enable anydesk || exit 1

  echo "Daemon service has been enabled"

  echo -e "AnyDesk has been installed\n"
}

install_tigervnc () {
  echo "Installing the TigerVNC... "

  sudo pacman -S --noconfirm tigervnc remmina libvncserver || exit 1

  echo -e "TigerVNC has been installed\n"
}

install_filezilla () {
  echo "Installing the Filezilla... "

  sudo pacman -S --noconfirm filezilla || exit 1

  echo -e "Filezilla has been installed\n"
}

install_rclone () {
  echo "Installing the RClone... "

  sudo pacman -S --noconfirm rclone || exit 1

  echo -e "RClone has been installed\n"
}

install_transmission () {
  echo "Installing the Transmission... "

  sudo pacman -S --noconfirm transmission-cli transmission-gtk || exit 1

  echo -e "Transmission has been installed\n"
}

install_docker () {
  echo "Installing the docker engine..."

  sudo pacman -S --noconfirm docker docker-compose || exit 1

  echo "Enabling the docker service..."

  sudo systemctl enable docker.service || exit 1

  echo "Docker service has been enabled"

  sudo usermod -aG docker "$USERNAME"

  echo "User added to the docker user group"

  echo -e "Docker has been installed\n"
}

install_virtualbox () {
  echo "Installing the Virtual Box..."

  local PKGS="virtualbox virtualbox-guest-iso"

  if [[ "${KERNELS[@]}" =~ stable ]]; then
    PKGS="$PKGS virtualbox-host-modules-arch"
  fi

  if [[ "${KERNELS[@]}" =~ lts ]]; then
    PKGS="$PKGS virtualbox-host-dkms"
  fi

  sudo pacman -S --noconfirm $PKGS || exit 1

  sudo usermod -aG vboxusers "$USERNAME"

  echo "User added to the vboxusers user group"

  echo -e "Virtual Box has been installed\n"
}

install_vmware () {
  echo "Installing the VMware..."

  sudo pacman -S --noconfirm fuse2 gtkmm pcsclite libcanberra &&
    yay -S --noconfirm --needed vmware-workstation  > /dev/null || exit 1

  echo "Enabling vmware services..."

  sudo systemctl enable vmware-networks.service &&
  sudo systemctl enable vmware-usbarbitrator.service || exit 1

  echo "Services has been enabled"

  echo -e "Vmware has been installed\n"
}

echo -e "\nStarting the apps installation process..."

if [[ "$(id -u)" == "0" ]]; then
  echo -e "\nError: process must be run as non root user"
  echo "Process exiting with code 1..."
  exit 1
fi

source ~/stack/.options

for APP in "${APPS[@]}"; do
  install_${APP}
done

echo -e "\nSetting up apps has been completed"
echo "Moving to the next process..."
sleep 5
