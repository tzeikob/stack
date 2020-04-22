#!/bin/bash
# A bash script to setup a development stack environment

# Define relative paths
dir=$(dirname $0)
script_path=$dir"/index.sh"
global_path=$(dirname $dir)"/common/global.sh"

# Import global common dependencies
source $global_path

# Load terminal configuration
dconf load /org/gnome/terminal/legacy/profiles:/ < $dir/terminal.dconf

# Initiate apt log file
apt_log_path=$dir"/apt.log"
> $apt_log_path

# Open a terminal along to tail installation's logs
gnome-terminal --tab -- bash -c "tail -f ${apt_log_path}; sleep 8h" > /dev/null 2>&1

# Read command line options
yesToAll=false

while getopts y OPT; do
  case "$OPT" in
    y) yesToAll=true
  esac
done

highlight " -ScriptBox v1.0.0, $(date +"%a %d %B %Y %H:%M %Z")- "

log "Starting the stack script $script_path."
log "Loading global dependencies from $global_path.\n"

# Create temporary files folder
temp="/tmp/scriptbox/stack"

log "Creating temporary files folder to $temp."

mkdir -p $temp

info "Temporary folder has been created successfully.\n"

# Loading extra fonts
log "Installing extra system fonts."

wget -q --show-progress -P $temp https://github.com/tonsky/FiraCode/releases/download/3.1/FiraCode_3.1.zip

unzip $temp/FiraCode_3.1.zip -d $temp >> $apt_log_path
mkdir -p /home/$USER/.local/share/fonts
cp $temp/ttf/* /home/$USER/.local/share/fonts

log "Updating system's font cache."

fc-cache -f -v >> $apt_log_path

info "Fonts have been installed successfully.\n"

# Rename default home folders
log "Refactoring user's home folders in /home/$USER."

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

log "Updating the user dirs file $userdirs_file."

> $userdirs_file

echo "XDG_DESKTOP_DIR=\"$HOME/desktop\"" >> $userdirs_file
echo "XDG_DOWNLOAD_DIR=\"$HOME/downloads\"" >> $userdirs_file
echo "XDG_TEMPLATES_DIR=\"$HOME/templates\"" >> $userdirs_file
echo "XDG_PUBLICSHARE_DIR=\"$HOME/public\"" >> $userdirs_file
echo "XDG_DOCUMENTS_DIR=\"$HOME/documents\"" >> $userdirs_file
echo "XDG_MUSIC_DIR=\"$HOME/music\"" >> $userdirs_file
echo "XDG_PICTURES_DIR=\"$HOME/pictures\"" >> $userdirs_file
echo "XDG_VIDEOS_DIR=\"$HOME/videos\"" >> $userdirs_file

log "User dirs file has been updated successfully."

# Update the bookmarks file
bookmarks_file="/home/$USER/.config/gtk-3.0/bookmarks"

log "Backing up the bookmarks file to $bookmarks_file.bak."

cp $bookmarks_file $bookmarks_file.bak

log "Updating the bookmarks file $bookmarks_file."

> $bookmarks_file

echo "file:///home/"$USER"/downloads Downloads" >> $bookmarks_file
echo "file:///home/"$USER"/documents Documents" >> $bookmarks_file
echo "file:///home/"$USER"/music Music" >> $bookmarks_file
echo "file:///home/"$USER"/pictures Pictures" >> $bookmarks_file
echo "file:///home/"$USER"/videos Videos" >> $bookmarks_file

# Create various host folders
log "Creating host folders to store databases and sources."

databases_home=/home/$USER/databases
mkdir -p $databases_home
mkdir -p $databases_home/mysql
mkdir -p $databases_home/mongo

sources_home=/home/$USER/sources
mkdir -p $sources_home
mkdir -p $sources_home/me
mkdir -p $sources_home/temp

echo "file://$sources_home Sources" >> $bookmarks_file

info "User's home folder has been refactored successfully.\n"

# Upgrade the system
if [[ $yesToAll = false ]]; then
  read -p "Do you want to upgrade your system?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Upgrading the base system with the latest updates."

  sudo apt-get -y update >> $apt_log_path
  sudo apt-get -y upgrade >> $apt_log_path

  log "Removing any not used packages."

  sudo apt-get -y autoremove >> $apt_log_path

  packages=(tree curl unzip htop gconf-service gconf-service-backend gconf2
            gconf2-common libappindicator1 libgconf-2-4 libindicator7
            libpython2-stdlib python python2.7 python2.7-minimal libatomic1
            gimp vlc)

  log "Installing the following third-party software dependencies: \n${packages[*]}"

  sudo apt-get -y install ${packages[@]} >> $apt_log_path

  log "Installing GUI for UFW to manage firewall rules."

  sudo add-apt-repository -y -n universe >> $apt_log_path
  sudo apt-get -y update >> $apt_log_path
  sudo apt-get -y install gufw >> $apt_log_path

  log "Enabling UFW service."

  sudo ufw enable
  sudo ufw status verbose

  log "Firewall has been set to deny any incoming and allow any outgoing traffic."

  log "Installing the latest version of VeraCrypt."

  sudo add-apt-repository -y -n ppa:unit193/encryption >> $apt_log_path
  sudo apt-get -y update >> $apt_log_path
  sudo apt-get -y install veracrypt >> $apt_log_path

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

  sudo apt-get -y install `check-language-support -l el` >> $apt_log_path

  log "Adding greek layout into the keyboard input sources."

  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'gr')]"

  log "Setting regional formats back to US."

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

  info "System languages have been updated successfully.\n"
fi

# Set local RTC time
if [[ $yesToAll = false ]]; then
  read -p "Do you want to use local RTC time?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Setting system to use local RTC time instead of UTC."

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

# Install Chrome
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Chrome?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Chrome."

  wget -q --show-progress -P $temp https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

  sudo apt-get -y install $temp/google-chrome-stable_current_amd64.deb >> $apt_log_path

  info "Chrome has been installed successfully.\n"
fi

# Install Skype
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Skype?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Skype."

  wget -q --show-progress -P $temp https://repo.skype.com/latest/skypeforlinux-64.deb

  sudo apt-get -y install $temp/skypeforlinux-64.deb >> $apt_log_path

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

  sudo snap install slack --classic

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

  log "Installing the version $msteams_version of Microsoftt Teams."

  wget -q --show-progress -P $temp https://packages.microsoft.com/repos/ms-teams/pool/main/t/teams/teams_${msteams_version}_amd64.deb

  sudo apt-get -y install $temp/teams_${msteams_version}_amd64.deb >> $apt_log_path

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

  sudo add-apt-repository -y -n multiverse >> $apt_log_path
  sudo apt-get -y update >> $apt_log_path
  sudo apt-get -y install virtualbox >> $apt_log_path

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
   sudo add-apt-repository -y -n ppa:$ppa >> $apt_log_path
   sudo apt-get -y update >> $apt_log_path
  fi

  sudo apt-get -y install git >> $apt_log_path

  read -p "Enter your git username:($USER) " username

  if [[ $username == "" ]]; then
   username=$USER
  fi

  git config --global user.name "$username"

  log "You Git username has been set to $(git config --global user.name)."

  read -p "Enter your Git email:($USER@$HOSTNAME) " email

  if [[ $email == "" ]]; then
   email="$USER@$HOSTNAME"
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

  wget -q --show-progress -P $temp -O $temp/nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v$nvm_version/install.sh

  bash $temp/nvm-install.sh >> $apt_log_path
  source /home/$USER/.bashrc >> $apt_log_path
  source /home/$USER/.nvm/nvm.sh >> $apt_log_path

  log "NVM has been installed under /home/$USER/.nvm."

  log "Installing Node LTS and latest stable versions."

  nvm install --no-progress --lts >> $apt_log_path
  nvm install --no-progress node >> $apt_log_path
  nvm use --lts >> $apt_log_path

  log "Node versions can be found under /home/$USER/.nvm/versions/node."

  log "Node $(nvm current) is currently in use."

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

  sudo apt-get -y install openjdk-8-jdk openjdk-8-doc openjdk-8-source >> $apt_log_path

  log "Open JDK 8 has been installed successfully."

  log "Installing the version 11 (LTS) of Open JDK."

  sudo apt-get -y install openjdk-11-jdk openjdk-11-doc openjdk-11-source >> $apt_log_path

  log "Open JDK 11 (LTS) has been installed successfully."

  log "JDK currently in use is:"

  java -version

  sudo update-alternatives --display java >> $apt_log_path

  log "Installing the latest version of Maven."

  sudo apt-get -y install maven >> $apt_log_path

  log "Maven has been installed."

  mvn -version >> $apt_log_path

  info "JDKs have been installed successfully.\n"
fi

# Install Docker
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Docker?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of docker community edition."

  sudo apt-get -y update >> $apt_log_path
  sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common >> $apt_log_path

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -  >> $apt_log_path
  sudo add-apt-repository -y -n "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >> $apt_log_path

  sudo apt-get -y update >> $apt_log_path
  sudo apt-get -y install docker-ce docker-ce-cli containerd.io >> $apt_log_path

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
  sudo add-apt-repository -y -n "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" >> $apt_log_path

  sudo apt-get -y update >> $apt_log_path
  sudo apt-get -y install atom >> $apt_log_path

  info "Atom has been installed successfully.\n"
fi

# Install Visual Studio Code
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Visual Studio Code?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Visual Studio Code."

  wget -q --show-progress -P $temp -O $temp/visual-studio-code.deb https://go.microsoft.com/fwlink/?LinkID=760868

  sudo apt-get -y install $temp/visual-studio-code.deb >> $apt_log_path

  settings_home="/home$USER/.config/Code/User/"
  settings_file="settings.json"

  log "Configuring visual studio code ($settings_home}/${settings_file})."

  mkdir -p $settings_home

  > $settings_home/$settings_file
  echo "{" >> $settings_home/$settings_file
  echo " "editor.fontFamily": "Fira Code"," >> $settings_home/$settings_file
  echo " "editor.fontLigatures": true," >> $settings_home/$settings_file
  echo " "workbench.colorTheme": "Monokai Pro (Filter Ristretto)"," >> $settings_home/$settings_file
  echo " "workbench.iconTheme": "Monokai Pro (Filter Ristretto) Icons"" >> $settings_home/$settings_file
  echo "}" >> $settings_home/$settings_file

  code --install-extension monokai.theme-monokai-pro-vscode

  info "Visual Studio Code has been installed successfully.\n"
fi

# Install IntelliJ
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install IntelliJ?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of IntelliJ community edition."

  sudo snap install intellij-idea-community --classic

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

  wget -O - https://dbeaver.io/debs/dbeaver.gpg.key | sudo apt-key add -
  echo "deb https://dbeaver.io/debs/dbeaver-ce /" | sudo tee /etc/apt/sources.list.d/dbeaver.list >> $apt_log_path

  sudo apt-get -y update >> $apt_log_path
  sudo apt-get -y install dbeaver-ce >> $apt_log_path

  info "DBeaver has been installed successfully.\n"
fi

# Install MongoDB Compass
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install MongoDB Compass?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  compass_version="1.20.5"

  log "Installing the version $compass_version of MongoDB Compass community."

  wget -q --show-progress -P $temp -O $temp/compass.deb "https://downloads.mongodb.com/compass/mongodb-compass-community_${compass_version}_amd64.deb"

  sudo apt-get -y install $temp/compass.deb >> $apt_log_path

  info "MongoDB compass has been installed successfully.\n"
fi

# Install Postman
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Postman?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Postman."

  sudo snap install postman

  info "Postman has been isntalled successfully.\n"
fi

# Install QBittorrent
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install QBittorrent?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of QBittorrent."

  sudo add-apt-repository -y -n ppa:qbittorrent-team/qbittorrent-stable >> $apt_log_path
  sudo apt-get -y update >> $apt_log_path
  sudo apt-get -y install qbittorrent >> $apt_log_path

  info "QBittorrent has been installed successfully.\n"
fi

# Install Libre Office
if [[ $yesToAll = false ]]; then
  read -p "Do you want to install Libre Office?(Y/n) " answer
else
  answer="yes"
fi

if [[ $answer =~ $yes ]]; then
  log "Installing the latest version of Libre Office."

  sudo add-apt-repository -y -n ppa:libreoffice/ppa >> $apt_log_path
  sudo apt-get -y update >> $apt_log_path
  sudo apt-get -y install libreoffice >> $apt_log_path

  info "Libre Office has been installed successfully.\n"
fi

# Update the desktop
log "Updating the desktop appearence."

gsettings set org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 26
gsettings set org.gnome.shell.extensions.desktop-icons show-home false
gsettings set org.gnome.shell.extensions.desktop-icons show-trash false

info "Desktop has been updated successfully.\n"

# Cleaning up the system from temporary files
log "Cleaning up temporary files folder $temp."

rm -rf $temp

info "Temporary files have been removed.\n"

# Ask user to reboot
log "Stack installation completed successfully."
read -p "Do you want to reboot?(Y/n) " answer

if [[ $answer =~ $yes ]]; then
  sudo reboot
fi
