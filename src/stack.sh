#!/bin/bash
# A bash script to setup a development stack environment

# Read command line options
yesToAll=false

while getopts y OPT; do
  case "$OPT" in
    y) yesToAll=true
  esac
done

# Set current relative path
dir=$(dirname $0)

# Load global goodies
source $dir"/global.sh"

# Initiate local variables
favorites="'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'firefox.desktop'"
bookmarks_file="/home/$USER/.config/gtk-3.0/bookmarks"

now=$(date)
distro=$(lsb_release -si)
version=$(lsb_release -sr)

# Print welcome screen
log "Scriptbox v1.0.0\n"
log "Date: $(d "$now")"
log "System: $(d "$distro $version")"
log "Host: $(d $HOSTNAME)"
log "User: $(d $USER)\n"

# Create temporary files folder
temp="/tmp/scriptbox/stack"

log "Creating temporary files folder to $temp."

mkdir -p $temp

info "Temporary files folder has been created successfully.\n"

# Rename default home folders
log "Renaming the default home folders (/home/$USER) to lower case."

mv /home/$USER/Desktop /home/$USER/desktop
mv /home/$USER/Downloads /home/$USER/downloads
mv /home/$USER/Templates /home/$USER/templates
mv /home/$USER/Public /home/$USER/public
mv /home/$USER/Documents /home/$USER/documents
mv /home/$USER/Music /home/$USER/music
mv /home/$USER/Pictures /home/$USER/pictures
mv /home/$USER/Videos /home/$USER/videos

# Update the user dirs file
userdirs_file="/home/$USER/.config/user-dirs.dirs"

log "Backing up the user dirs file to $userdirs_file.bak."

cp $userdirs_file $userdirs_file.bak

log "Updating the contents of the user dirs file."

> $userdirs_file
echo "XDG_DESKTOP_DIR=\"$HOME/desktop\"" >> $userdirs_file
echo "XDG_DOWNLOAD_DIR=\"$HOME/downloads\"" >> $userdirs_file
echo "XDG_TEMPLATES_DIR=\"$HOME/templates\"" >> $userdirs_file
echo "XDG_PUBLICSHARE_DIR=\"$HOME/public\"" >> $userdirs_file
echo "XDG_DOCUMENTS_DIR=\"$HOME/documents\"" >> $userdirs_file
echo "XDG_MUSIC_DIR=\"$HOME/music\"" >> $userdirs_file
echo "XDG_PICTURES_DIR=\"$HOME/pictures\"" >> $userdirs_file
echo "XDG_VIDEOS_DIR=\"$HOME/videos\"" >> $userdirs_file

cat $userdirs_file

log "User dirs file has been updated successfully."

log "Backing up the nautilus bookmarks file to $bookmarks_file.bak."

cp $bookmarks_file $bookmarks_file.bak

log "Updating the contents of the nautilus bookmarks file."

> $bookmarks_file
echo "file:///home/"$USER"/downloads Downloads" | tee -a $bookmarks_file
echo "file:///home/"$USER"/documents Documents" | tee -a $bookmarks_file
echo "file:///home/"$USER"/music Music" | tee -a $bookmarks_file
echo "file:///home/"$USER"/pictures Pictures" | tee -a $bookmarks_file
echo "file:///home/"$USER"/videos Videos" | tee -a $bookmarks_file

cat $bookmarks_file

info "The default home folders have been renamed successfully.\n"

# Create various folders
log "Creating folders to host databases and code sources."

mkdir -p /home/$USER/dbs

sources_home=/home/$USER/sources
mkdir -p $sources_home
mkdir -p $sources_home/me
mkdir -p $sources_home/temp

echo "file://$sources_home Sources" | tee -a $bookmarks_file

info "Host folders have been created successfully.\n"

# Upgrade the system
if [[ $yesToAll = false ]]; then
  read -p "Do you want to upgrade your system?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Upgrading the base system with the latest updates."

  sudo apt -y -qq update
  sudo apt -y -qq upgrade

  log "Removing any not used packages."

  sudo apt -y -qq autoremove

  log "Installing the following third-party software dependencies:"

  packages=(tree curl unzip htop gconf-service gconf-service-backend gconf2
            gconf2-common libappindicator1 libgconf-2-4 libindicator7
            libpython-stdlib python python-minimal python2.7 python2.7-minimal libatomic1
            gimp vlc)

  log $packages

  sudo apt -y -qq install ${packages[@]}

  log "Installing GUI for UFW to manage firewall rules."

  sudo add-apt-repository -y -n universe
  sudo apt -y -qq update
  sudo apt -y -qq install gufw

  log "Firewall has been set to deny any incoming and allow any outgoing traffic."

  log "Enabling UFW service."

  sudo ufw enable
  sudo ufw status verbose

  log "Installing the latest version of VeraCrypt software."

  sudo add-apt-repository -y -n ppa:unit193/encryption
  sudo apt -y -qq update
  sudo apt -y -qq install veracrypt

  log "VeraCrypt has been installed."

  info "System has been updated successfully.\n"
fi

# Install system languages
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install the Greek language?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the greek language packages."

  sudo apt -y -qq install `check-language-support -l el`

  log "Adding greek layout into the keyboard input sources."

  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'gr')]"

  log "Set regional formats back to US."

  sudo update-locale LANG=en_US.UTF-8
  sudo update-locale LANGUAGE=
  sudo update-locale LC_CTYPE="en_US.UTF-8"
  sudo update-locale LC_NUMERIC=en_US.UTF-8
  sudo update-locale LC_TIME=en_US.UTF-8
  sudo update-locale LC_COLLATE="en_US.UTF-8"
  sudo update-locale LC_MONETARY=en_US.UTF-8
  sudo update-locale LC_MESSAGES="en_US.UTF-8"
  sudo update-locale LC_PAPER=en_US.UTF-8
  sudo update-locale LC_NAME=en_US.UTF-8
  sudo update-locale LC_ADDRESS=en_US.UTF-8
  sudo update-locale LC_TELEPHONE=en_US.UTF-8
  sudo update-locale LC_MEASUREMENT=en_US.UTF-8
  sudo update-locale LC_IDENTIFICATION=en_US.UTF-8
  sudo update-locale LC_ALL=
  locale

  info "System languages have been updated successfully.\n"
fi

# Set local RTC time
if [[ $yesToAll = false ]]; then
  read -p "Do you want to use local RTC time?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Use local RTC time instead of UTC."

  timedatectl set-local-rtc 1 --adjust-system-clock
  gsettings set org.gnome.desktop.interface clock-show-date true

  info "System has been set to use local RTC time successfully.\n"
fi

# Disable screen lock
if [[ $yesToAll = false ]]; then
  read -p "Do you want to disable screen lock?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Disabling screen lock."

  gsettings set org.gnome.desktop.screensaver lock-enabled false
  gsettings set org.gnome.desktop.session idle-delay 0
  gsettings set org.gnome.settings-daemon.plugins.power idle-dim false

  info "Screen lock has been disabled successfully.\n"
fi

# Install Dropbox
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Dropbox?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Dropbox."

  dropbox_list=/etc/apt/sources.list.d/dropbox.list
  sudo touch $dropbox_list
  sudo echo "deb [arch=i386,amd64] http://linux.dropbox.com/ubuntu $(lsb_release -cs) main" | sudo tee -a $dropbox_list
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1C61A2656FB57B7E4DE0F4C1FC918B335044912E

  sudo apt -y -qq update
  sudo apt -y -qq install python3-gpg dropbox

  log "Starting the Dropbox daemon."

  dropbox start -i &>/dev/null

  info "Dropbox has been installed successfully.\n"
fi

# Install Chrome
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Chrome?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Downloading the latest version of Chrome."

  wget -q --show-progress -P $temp https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

  log "Installing Chrome using deb packaging."

  sudo dpkg -i $temp/google-chrome-stable_current_amd64.deb

  # Adding Chrome in favorites applications
  favorites=$favorites", 'google-chrome.desktop'"

  info "Chrome has been installed successfully.\n"
fi

# Install Skype
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Skype?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Downloading the latest version of Skype."

  wget -q --show-progress -P $temp https://repo.skype.com/latest/skypeforlinux-64.deb

  log "Installing Skype using deb packaging."

  sudo dpkg -i $temp/skypeforlinux-64.deb

  # Adding Skype in favorites applications
  favorites=$favorites", 'skypeforlinux.desktop'"

  info "Skype has been installed successfully.\n"
fi

# Install Slack
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Slack?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Slack."

  sudo apt -y -qq install slack

  # Adding Slack in favorites applications
  favorites=$favorites", 'slack.desktop'"

  info "Slack has been installed successfully.\n"
fi

# Install Microsoft Teams
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Microsoft Teams?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  msteams_version="1.3.00.5153"

  log "Downloading the version $msteams_version of Microsoft Teams."

  wget -q --show-progress -P $temp https://packages.microsoft.com/repos/ms-teams/pool/main/t/teams/teams_${msteams_version}_amd64.deb

  log "Installing Microsoftt Teams using deb packaging."

  sudo dpkg -i $temp/teams_${msteams_version}_amd64.deb

  # Adding Microsoft Teams in favorites applications
  favorites=$favorites", 'teams.desktop'"

  info "Microsoft Teams has been installed successfully.\n"
fi

# Install Virtual Box
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Virtual Box?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Virtual Box."

  sudo add-apt-repository -y -n multiverse
  sudo apt -y -qq update
  sudo apt -y -qq install virtualbox

  # Adding Virtual Box in favorites applications
  favorites=$favorites", 'virtualbox.desktop'"

  info "Virtual Box has been installed successfully.\n"
fi

# Install Git
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Git?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Git."

  ppa="git-core/ppa"

  if ! grep -q "^deb .*$ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
   sudo add-apt-repository -y -n ppa:$ppa
   sudo apt -y -qq update
  fi

  sudo apt -y -qq install git

  read -p "Enter your git username:($USER) " username

  if [[ $username == "" ]]; then
   username = $USER
  fi

  git config --global user.name "$username"

  log "You Git username has been set to $(git config --global user.name)."

  read -p "Enter your Git email:($USER@$HOSTNAME) " email

  if [[ $email == "" ]]; then
   email = $USER@$HOSTNAME
  fi

  git config --global user.email "$email"

  log "Your Git email has been set to $(git config --global user.email)."

  info "Git has been installed successfully.\n"
fi

# Install Node
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Node?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  nvm_version="0.35.3"

  log "Installing the version $nvm_version of NVM."

  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v$nvm_version/install.sh | bash

  source /home/$USER/.bashrc
  source /home/$USER/.nvm/nvm.sh

  log "Installing Node LTS and latest stable versions."

  nvm install --lts
  nvm install node
  nvm use --lts

  log "The following Node versions have been installed (/home/$USER/.nvm/versions/node):"
  nvm ls

  info "Node has been installed successfully.\n"
fi

# Install Open JDKs
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Open JDK?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the version 8 of Open JDK."

  sudo apt -y -qq install openjdk-8-jdk openjdk-8-doc openjdk-8-source

  log "Open JDK 8 has been installed successfully."

  log "Installing the version 11 (LTS) of Open JDK 11."

  sudo apt -y -qq install openjdk-11-jdk openjdk-11-doc openjdk-11-source

  log "Open JDK 11 (LTS) has been installed successfully."

  log "Selecting default executable (java) through update alternatives."

  sudo update-alternatives --config java

  log "Selecting default compiler (javac) through update alternatives."

  sudo update-alternatives --config javac

  log "Installing the latest version of Maven in /home/$USER/.m2."

  sudo apt -y -qq install maven

  log "Maven has been installed successfully."

  info "Java has been installed successfully.\n"
fi

# Install Docker
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Docker?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing latest version of docker community edition."

  sudo apt -y -qq update
  sudo apt -y -qq install apt-transport-https ca-certificates curl gnupg-agent software-properties-common

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository -y -n "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

  sudo apt -y -qq update
  sudo apt -y -qq install docker-ce docker-ce-cli containerd.io

  log "Creating docker user group."

  sudo groupadd docker

  log "Adding current user to the docker user group."

  sudo usermod -aG docker $USER

  docker_compose_version="1.25.5"

  log "Installing the version $docker_compose_version of docker compose."

  sudo curl -L "https://github.com/docker/compose/releases/download/$docker_compose_version/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose

  info "Docker has been installed successfully.\n"
fi

# Install Atom
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Atom?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Atom."

  wget -q https://packagecloud.io/AtomEditor/atom/gpgkey -O- | sudo apt-key add -
  sudo add-apt-repository -y -n "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main"

  sudo apt -y -qq update
  sudo apt -y -qq install atom

  # Adding Atom in favorites applications
  favorites=$favorites", 'atom.desktop'"

  info "Atom has been installed successfully.\n"
fi

# Install Visual Studio
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Visual Studio?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Downloading the latest version of Visual Studio."

  wget -q --show-progress -P $temp -O $temp/visual-studio.deb https://go.microsoft.com/fwlink/?LinkID=760868

  log "Installing Visual Studio using deb packaging."

  sudo dpkg -i $temp/visual-studio.deb

  # Adding Visual Studio in favorites applications
  favorites=$favorites", 'code.desktop'"

  info "Visual Studio has been installed successfully.\n"
fi

# Install IntelliJ
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install IntelliJ?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of IntelliJ comunity edition."

  sudo snap install intellij-idea-community --classic

  # Adding IntelliJ in favorites applications
  favorites=$favorites", 'idea.desktop'"

  info "IntelliJ has been installed successfully.\n"
fi

# Install DBeaver
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install DBeaver?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of DBeaver."

  wget -O - https://dbeaver.io/debs/dbeaver.gpg.key | apt-key add -
  echo "deb https://dbeaver.io/debs/dbeaver-ce /" | tee /etc/apt/sources.list.d/dbeaver.list

  sudo apt -y -qq update
  sudo apt -y -qq install dbeaver-ce

  # Adding DBeaver in favorites applications
  favorites=$favorites", 'dbeaver.desktop'"

  info "DBeaver has been installed successfully."
fi

# Install MongoDB Compass
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install MongoDB Compass?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  compass_version="1.20.5"

  log "Downloading the version $compass_version of MongoDB Compass community."

  wget -q --show-progress -P $temp -O $temp/compass.deb "https://downloads.mongodb.com/compass/mongodb-compass-community_${compass_version}_amd64.deb"

  log "Installing MongoDB Compass using deb packaging."

  sudo dpkg -i $temp/compass.deb

  # Adding MongoDB Compass in favorites applications
  favorites=$favorites", 'mongodb-compass-community.desktop'"

  info "MongoDB compass has been installed successfully.\n"
fi

# Install Postman
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Postman?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Postman via snap."

  sudo snap install postman

  # Adding Postman in favorites applications
  favorites=$favorites", 'postman.desktop'"

  info "Postman has been isntalled successfully."
fi

# Install QBittorrent
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install QBittorrent?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of QBittorrent."

  sudo add-apt-repository -y -n ppa:qbittorrent-team/qbittorrent-stable
  sudo apt -y -qq update
  sudo apt -y -qq install qbittorrent

  info "QBittorrent has been installed successfully.\n"
fi

# Install libre office
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Libre Office?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Libre Office."

  sudo add-apt-repository -y -n ppa:libreoffice/ppa
  sudo apt -y -qq update
  sudo apt -y -qq install libreoffice

  info "Libre Office has been installed successfully.\n"
fi

# Update the dock panel
log "Updating the dock."

gsettings set org.gnome.shell favorite-apps "[$favorites]"
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 26
gsettings set org.gnome.nautilus.desktop trash-icon-visible false

log "Dock has been updated successfully."

# Cleaning up the system from temporary files
log "Cleaning up any temporary file under $temp."

rm -rf $temp

log "Temporary files have been removed."

info "Stack installation completed successfully.\n"

read -p "Do you want to reboot?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  sudo reboot
fi
