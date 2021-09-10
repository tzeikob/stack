#!/bin/bash
# A shell script to install and setup your development stack

# Global variables and functions
VERSION="1.0.0"
YES="^([Yy][Ee][Ss]|[Yy]|"")$"
TEMP="/tmp/stack.$(date +%s)"
LOG_FILE="$TEMP/stdout.log"
GIT_USER_NAME=""
GIT_USER_EMAIL=""

# Third-party dependencies
NVM_VERSION="0.38.0"
DOCKER_COMPOSE_VERSION="1.29.2"
DROPBOX_VERSION="2020.03.04"
MONGODB_COMPASS_VERSION="1.28.1"

# Log a normal info message, log message emoji
log () {
  echo -e "\e[97m$1\e[0m $2"
  echo -e "$1" >> $LOG_FILE
}

# Log a progress message, progress message emoji
progress () {
  echo -ne "\033[2K\e[97m$1\e[0m $2\\r"
  echo -e "$1" >> $LOG_FILE
}

# Log an error and exit the process, abort message
abort () {
  echo -e "\n\e[97m$1\e[0m \U1F480"
  echo -e "\n$1" >> $LOG_FILE

  echo -e "Process exited with code: 1"
  echo -e "Process exited with code: 1" >> $LOG_FILE

  exit 1
}

# Check if tasks list contains a given task, tasksContains taskName
tasksContains () {
  local result=false

  for task in "${tasks[@]}"; do
    if [[ $1 == $task ]]; then
      result=true
      break
    fi
  done

  echo $result
}

# Ask if a task should be added to tasks list or not, ask question taskName
ask () {
  read -p "$1(Y/n) " answer
  if [[ $answer =~ $YES ]]; then
    tasks+=($2)
  fi
}

# Update apt repositories
updateRepositories () {
  log "Updating apt repositories" "\U1F4AC"

  sudo apt-get -y update >> $LOG_FILE 2>&1

  log "Repositories have been updated"
}

# Remove unnecessary apt packages
removeUnnecessaryPackages () {
  log "Removing unnecessary apt packages" "\U1F4AC"

  sudo apt-get -y autoremove >> $LOG_FILE 2>&1

  log "Unnecessary packages have been removed"
}

# Upgrade the system via apt
upgradeSystem () {
  log "Upgrading system with latest updates" "\U1F4AC"

  sudo apt-get -y upgrade >> $LOG_FILE 2>&1

  log "Latest updates have been installed"
}

# Install prerequisite packages
installPrerequisites () {
  log "Installing a few prerequisite packages" "\U1F4AC"

  local packages=(
    tree
    wget
    curl
    unzip
    htop
    gconf-service
    gconf-service-backend
    gconf2
    gconf2-common
    libappindicator1
    libgconf-2-4
    libindicator7
    libpython2-stdlib
    python
    python2.7
    python2.7-minimal
    libatomic1
    poppler-utils
    dconf-editor
  )

  sudo apt-get -y install ${packages[@]} >> $LOG_FILE 2>&1

  log "Prerequisite packages have been installed"
}

# Task to set local RTC time
setLocalRTCTime () {
  log "Configuring system to use local RTC time"

  timedatectl set-local-rtc 1 --adjust-system-clock >> $LOG_FILE 2>&1

  log "Now the system is using the local RTC Time instead of UTC"

  gsettings set org.gnome.desktop.interface clock-show-date true >> $LOG_FILE 2>&1

  log "Clock has been set to show the date as well"

  log "System has been set to use local RTC time successfully\n"
}

# Task to increase inotify watches limit to monitor more files
increaseInotifyLimit () {
  log "Setting the inotify watches limit to a higher value"

  local watches_limit=524288
  echo fs.inotify.max_user_watches=$watches_limit | sudo tee -a /etc/sysctl.conf >> $LOG_FILE 2>&1 && sudo sysctl -p >> $LOG_FILE 2>&1

  log "You are now able to monitor much more files"

  log "The inotify watches limit has been set to $watches_limit\n"
}

# Task to enable system's firewall via UFW
enableFirewall () {
  log "Installing GUFW to manage firewall rules via user interface"

  log "Downloading and extracting the package" "\U1F4AC"

  sudo apt-get -y install gufw >> $LOG_FILE 2>&1

  log "GUFW package has been installed"

  log "Enabling the system's firewall via the UFW service"

  sudo ufw enable >> $LOG_FILE 2>&1
  sudo ufw status verbose

  log "Any incoming traffic has been set to deny and outgoing to allow"

  log "Firewall has been enabled successfully\n"
}

# Task to install extra system languages, Greek
installGreekLanguage () {
  log "Installing extra language packages"

  log "Downloading and setting Greek language packages" "\U1F4AC"

  sudo apt-get -y install `check-language-support -l el` >> $LOG_FILE 2>&1

  log "Greek language packages have been installed"

  log "Adding greek layout into the keyboard input sources"

  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'gr')]" >> $LOG_FILE 2>&1

  log "Setting regional formats back to US"

  sudo update-locale LANG=en_US.UTF-8 >> $LOG_FILE 2>&1
  sudo update-locale LANGUAGE= >> $LOG_FILE 2>&1
  sudo update-locale LC_CTYPE="en_US.UTF-8" >> $LOG_FILE 2>&1
  sudo update-locale LC_NUMERIC=en_US.UTF-8 >> $LOG_FILE 2>&1
  sudo update-locale LC_TIME=en_US.UTF-8 >> $LOG_FILE 2>&1
  sudo update-locale LC_COLLATE="en_US.UTF-8" >> $LOG_FILE 2>&1
  sudo update-locale LC_MONETARY=en_US.UTF-8 >> $LOG_FILE 2>&1
  sudo update-locale LC_MESSAGES="en_US.UTF-8" >> $LOG_FILE 2>&1
  sudo update-locale LC_PAPER=en_US.UTF-8 >> $LOG_FILE 2>&1
  sudo update-locale LC_NAME=en_US.UTF-8 >> $LOG_FILE 2>&1
  sudo update-locale LC_ADDRESS=en_US.UTF-8 >> $LOG_FILE 2>&1
  sudo update-locale LC_TELEPHONE=en_US.UTF-8 >> $LOG_FILE 2>&1
  sudo update-locale LC_MEASUREMENT=en_US.UTF-8 >> $LOG_FILE 2>&1
  sudo update-locale LC_IDENTIFICATION=en_US.UTF-8 >> $LOG_FILE 2>&1
  sudo update-locale LC_ALL= >> $LOG_FILE 2>&1

  log "System languages have been updated successfully\n"
}

# Task to install Virtual Box
installVirtualBox () {
  log "Installing the latest version of Virtual Box"

  log "Downloading and extracting the package" "\U1F4AC"

  sudo apt-get -y install virtualbox >> $LOG_FILE 2>&1

  log "Package has been installed"

  log "Virtual Box has been installed successfully\n"
}

# Task to install Docker and Compose
installDocker () {
  log "Installing the latest version of Docker"

  log "Downloading and extracting prerequisite packages" "\U1F4AC"

  sudo apt-get -y install apt-transport-https ca-certificates curl gnupg lsb-release >> $LOG_FILE 2>&1

  log "Prerequisite packages have been installed"

  log "Adding docker repository to apt sources" "\U1F4AC"

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >> $LOG_FILE 2>&1
  
  echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  log "Docker apt repository has been added to sources"

  updateRepositories

  log "Installing Docker packages" "\U1F4AC"

  sudo apt-get -y install docker-ce docker-ce-cli containerd.io >> $LOG_FILE 2>&1

  log "Docker packages have been installed"

  log "Creating the docker user group"

  sudo groupadd docker >> $LOG_FILE 2>&1

  log "Adding current user $USER to the docker user group"

  sudo usermod -aG docker $USER >> $LOG_FILE 2>&1

  log "Installing the Docker Compose" "\U1F4AC"

  sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >> $LOG_FILE 2>&1
  sudo chmod +x /usr/local/bin/docker-compose >> $LOG_FILE 2>&1

  log "Docker compose version $DOCKER_COMPOSE_VERSION has been installed"

  log "Docker has been installed successfully\n"
}

# Task to install Dropbox
installDropbox () {
  log "Installing the Dropbox version $DROPBOX_VERSION"

  log "Downloading the package file" "\U1F4AC"

  wget -q -P $TEMP -O $TEMP/dropbox.deb "https://linux.dropbox.com/packages/ubuntu/dropbox_${DROPBOX_VERSION}_amd64.deb" >> $LOG_FILE 2>&1

  log "Package file has been downloaded"

  log "Extracting and installing the package file" "\U1F4AC"

  sudo apt-get -y install $TEMP/dropbox.deb >> $LOG_FILE 2>&1

  log "Package has been installed"

  log "Dropbox has been installed successfully\n"
}

# Task to install git
installGit () {
  log "Installing the latest version of Git"

  log "Downloading and extracting the package" "\U1F4AC"

  sudo apt-get -y install git >> $LOG_FILE 2>&1

  log "The package has been installed"

  if [[ -n $GIT_USER_NAME ]]; then
    git config --global user.name "$GIT_USER_NAME" >> $LOG_FILE 2>&1
    log "Git global user name has been set to $(git config --global user.name)"
  fi

  if [[ -n $GIT_USER_EMAIL ]]; then
    git config --global user.email "$GIT_USER_EMAIL" >> $LOG_FILE 2>&1
    log "Git global user email has been set to $(git config --global user.email)"
  fi

  log "Git has been installed successfully\n"
}

# Task to configure cmd prompt to show current git branch
enableGitPrompt () {
  log "Setting cmd prompt to show current branch in git folders (~/.bashrc)"

  echo '' >> ~/.bashrc
  echo '# Show git branch name' >> ~/.bashrc
  echo 'parse_git_branch() {' >> ~/.bashrc
  echo ' git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/:\\1/"' >> ~/.bashrc
  echo '}' >> ~/.bashrc
  echo "PS1='\${debian_chroot:+(\$debian_chroot)}\[\\033[01;32m\]\u@\h\[\\033[00m\]:\[\\033[01;34m\]\w\[\\033[01;31m\]\$(parse_git_branch)\[\\033[00m\]\$ '" >> ~/.bashrc

  log "Cmd prompt will now shown as user@host:~/path/to/folder[:branch]"

  log "Command prompt has been updated successfully\n"
}

# Task to install Node via NVM
installNode () {
  log "Installing Node via the NVM version $NVM_VERSION"

  log "Downloading NVM installation script" "\U1F4AC"

  wget -q -P $TEMP -O $TEMP/nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh >> $LOG_FILE 2>&1

  log "NVM script has been downloaded"

  log "Installing NVM package" "\U1F4AC"

  bash $TEMP/nvm-install.sh >> $LOG_FILE 2>&1
  source /home/$USER/.bashrc >> $LOG_FILE 2>&1
  source /home/$USER/.nvm/nvm.sh >> $LOG_FILE 2>&1

  log "NVM has been installed under /home/$USER/.nvm"

  log "Installing Node latest LTS version" "\U1F4AC"

  nvm install --no-progress --lts >> $LOG_FILE 2>&1

  log "Node latest LTS version has been installed successfully"

  log "Installing Node latest stable version" "\U1F4AC"

  nvm install --no-progress node >> $LOG_FILE 2>&1

  log "Node latest stable version has been installed successfully"

  nvm use --lts >> $LOG_FILE 2>&1

  log "Node versions can be found under /home/$USER/.nvm/versions/node"
  log "Node $(nvm current) is currently in use"

  log "Making local NPM dep's binaries available in cmd line"

  echo "" >> ~/.bashrc
  echo "# Make local NPM dep's binaries to be available in cmd line" >> ~/.bashrc
  echo 'export PATH="./node_modules/.bin:$PATH"' >> ~/.bashrc

  log "Path './node_modules/.bin' has been added to PATH (~/.bashrc)"

  log "Node has been installed successfully\n"
}

# Task to install Java, Open JDK and Maven
installJava () {
  log "Installing the Java Development Kit version 11"

  log "Downloading and extracting OpenJDK packages" "\U1F4AC"

  sudo apt-get -y install openjdk-11-jdk openjdk-11-doc openjdk-11-source >> $LOG_FILE 2>&1

  log "OpenJDK has been installed successfully"

  log "JDK currently in use is:"

  java -version

  log "Setting java into the update-alternatives"

  sudo update-alternatives --display java >> $LOG_FILE 2>&1

  log "Installing the latest version of Maven" "\U1F4AC"

  sudo apt-get -y install maven >> $LOG_FILE 2>&1

  log "Maven has been installed"

  log "Java has been installed successfully\n"
}

# Task to install Atom
installAtom () {
  log "Installing the latest version of Atom"

  sudo snap install atom --classic

  log "Atom has been installed successfully\n"
}

# Task to install Visual Studio Code
installVSCode () {
  log "Installing the latest version of Visual Studio Code"

  sudo snap install code --classic

  local extensions=(
    dbaeumer.vscode-eslint
    yzhang.markdown-all-in-one
    streetsidesoftware.code-spell-checker
  )

  log "Installing extra plugins and extensions" "\U1F4AC"

  for ext in ${extensions[@]}; do
    code --install-extension "$ext" >> $LOG_FILE 2>&1
  done

  log "The following plugins and extensions have been installed: \n${extensions[*]}"

  log "Visual Studio Code has been installed successfully\n"
}

# Task to install Sublime Text
installSublimeText () {
  log "Installing the latest version of Sublime Text"

  sudo snap install sublime-text --classic

  log "Sublime Text has been installed successfully\n"
}

# Task to install the Neovim editor
installNeovim () {
  log "Installing the latest version of Neovim editor"

  sudo snap install --beta nvim --classic

  log "Neovim has been installed successfully\n"
}

# Task to install IntelliJ Idea
installIntelliJIdea () {
  log "Installing the latest version of IntelliJ Idea"

  sudo snap install intellij-idea-community --classic

  log "IntelliJ Idea has been installed successfully\n"
}

# Task to install MongoDB Compass
installMongoDBCompass () {
  log "Installing the MongoDB Compass version $MONGODB_COMPASS_VERSION"

  log "Downloading the package file" "\U1F4AC"

  wget -q -P $TEMP -O $TEMP/compass.deb "https://downloads.mongodb.com/compass/mongodb-compass_${MONGODB_COMPASS_VERSION}_amd64.deb" >> $LOG_FILE 2>&1

  log "Package file has been downloaded"

  log "Extracting and installing the package file" "\U1F4AC"

  sudo apt-get -y install $TEMP/compass.deb >> $LOG_FILE 2>&1

  log "Package file has been installed"

  log "MongoDB compass has been installed successfully\n"
}

# Task to install DBeaver
installDBeaver () {
  log "Installing the latest version of DBeaver"

  sudo snap install dbeaver-ce

  log "DBeaver has been installed successfully\n"
}

# Task to install Postman
installPostman () {
  log "Installing the latest version of Postman"

  sudo snap install postman

  log "Postman has been isntalled successfully\n"
}

# Task to install Chrome
installChrome () {
  log "Installing the latest version of Chrome"

  log "Downloading the package file" "\U1F4AC"

  wget -q -P $TEMP -O $TEMP/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb >> $LOG_FILE 2>&1

  log "Package file has been downloaded"

  log "Extracting and installing the package file" "\U1F4AC"

  sudo apt-get -y install $TEMP/chrome.deb >> $LOG_FILE 2>&1

  log "Package file has been installed"

  log "Chrome has been installed successfully\n"
}

# Task to install Thunderbird
installThunderbird () {
  log "Installing the latest version of Thunderbird"

  sudo snap install thunderbird

  log "Thunderbird has been installed successfully\n"
}

# Task to install Slack
installSlack () {
  log "Installing the latest version of Slack"

  sudo snap install slack --classic

  log "Slack has been installed successfully\n"
}

# Task to install Discord
installDiscord () {
  log "Installing the latest version of Discord"

  sudo snap install discord

  log "Discord has been installed successfully\n"
}

# Task to install Telegram
installTelegram () {
  log "Installing the latest version of Telegram"

  sudo snap install telegram-desktop

  log "Telegram has been installed successfully\n"
}

# Task to install Microsoft Teams
installMSTeams () {
  log "Installing the latest version of Microsoft Teams"

  sudo snap install teams

  log "Microsoft Teams has been installed successfully\n"
}

# Task to install Skype
installSkype () {
  log "Installing the latest version of Skype"

  sudo snap install skype

  log "Skype has been installed successfully\n"
}

# Task to install TeamViewer
installTeamViewer () {
  log "Installing the latest version of TeamViewer"

  log "Downloading the package file" "\U1F4AC"

  wget -q -P $TEMP -O $TEMP/teamviewer.deb "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb" >> $LOG_FILE 2>&1

  log "Package file has been downloaded"

  log "Extracting and installing the package file" "\U1F4AC"

  sudo apt-get -y install $TEMP/teamviewer.deb >> $LOG_FILE 2>&1

  log "Package file has been installed"

  log "TeamViewer has been installed successfully\n"
}

# Task to install Libre Office
installLibreOffice () {
  log "Installing the latest version of Libre Office"

  sudo snap install libreoffice

  log "Libre Office has been installed successfully\n"
}

# Task to install Gimp
installGimp () {
  log "Installing the latest version of Gimp"

  log "Downloading and extracting the package" "\U1F4AC"

  sudo apt-get -y install gimp >> $LOG_FILE 2>&1

  log "Package file has been installed"

  log "Gimp has been installed successfully\n"
}

# Task to install VLC player
installVLC () {
  log "Installing the latest version of VLC player"

  log "Downloading and extracting the package" "\U1F4AC"

  sudo apt-get -y install vlc >> $LOG_FILE 2>&1

  log "Package file has been installed"

  log "VLC has been installed successfully\n"
}

# Task to install Rhythmbox player
installRhythmbox () {
  log "Installing the latest version of Rhythmbox"

  log "Downloading and extracting the package" "\U1F4AC"

  sudo apt-get -y install rhythmbox >> $LOG_FILE 2>&1

  log "Package file has been installed"

  log "Rhythmbox has been installed successfully\n"
}

# Task to install Spotify
installSpotify () {
  log "Installing the latest version of Spotify"

  sudo snap install spotify

  log "Spotify has been installed successfully\n"
}

# Task to configure desktop look and feel
configureDesktop () {
  log "Configuring desktop's look and feel"

  gsettings set org.gnome.shell.extensions.desktop-icons show-home false >> $LOG_FILE 2>&1
  gsettings set org.gnome.shell.extensions.desktop-icons show-trash false >> $LOG_FILE 2>&1

  log "All desktop icons are now hidden"

  log "Desktop has been updated successfully\n"
}

# Task to configure dock's look and feel
configureDock () {
  log "Configuring dock's look and feel"

  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM >> $LOG_FILE 2>&1

  log "Dock position has been changed to bottom"

  gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 26 >> $LOG_FILE 2>&1

  log "Dock size has been changed to 26 pixels"

  log "Dock has been updated successfully\n"
}

# Task to rename the default home folders
renameHomeFolders () {
  log "Renaming home folders in '/home/$USER'"

  mv /home/$USER/Desktop /home/$USER/desktop
  mv /home/$USER/Downloads /home/$USER/downloads
  mv /home/$USER/Templates /home/$USER/templates
  mv /home/$USER/Public /home/$USER/public
  mv /home/$USER/Documents /home/$USER/documents
  mv /home/$USER/Music /home/$USER/music
  mv /home/$USER/Pictures /home/$USER/pictures
  mv /home/$USER/Videos /home/$USER/videos

  # Task to update the user dirs file
  local userdirs_file="/home/$USER/.config/user-dirs.dirs"

  log "Backing up the user dirs file ($userdirs_file)"

  cp $userdirs_file $userdirs_file.bak

  log "Updating the user dirs file"

  > $userdirs_file
  echo "XDG_DESKTOP_DIR=\"$HOME/desktop\"" >> $userdirs_file
  echo "XDG_DOWNLOAD_DIR=\"$HOME/downloads\"" >> $userdirs_file
  echo "XDG_TEMPLATES_DIR=\"$HOME/templates\"" >> $userdirs_file
  echo "XDG_PUBLICSHARE_DIR=\"$HOME/public\"" >> $userdirs_file
  echo "XDG_DOCUMENTS_DIR=\"$HOME/documents\"" >> $userdirs_file
  echo "XDG_MUSIC_DIR=\"$HOME/music\"" >> $userdirs_file
  echo "XDG_PICTURES_DIR=\"$HOME/pictures\"" >> $userdirs_file
  echo "XDG_VIDEOS_DIR=\"$HOME/videos\"" >> $userdirs_file

  log "User dirs file has been updated"

  # Update the bookmarks file
  local bookmarks_file="/home/$USER/.config/gtk-3.0/bookmarks"

  log "Backing up the bookmarks file ($bookmarks_file)"

  cp $bookmarks_file $bookmarks_file.bak

  log "Updating the bookmarks file"

  > $bookmarks_file
  echo "file:///home/"$USER"/downloads Downloads" >> $bookmarks_file
  echo "file:///home/"$USER"/documents Documents" >> $bookmarks_file
  echo "file:///home/"$USER"/music Music" >> $bookmarks_file
  echo "file:///home/"$USER"/pictures Pictures" >> $bookmarks_file
  echo "file:///home/"$USER"/videos Videos" >> $bookmarks_file

  log "Home folders and bookmarks renamed successfully\n"
}

# Task to disable screen lock
disableScreenLock () {
  log "Disabling the auto screen lock operation"

  gsettings set org.gnome.desktop.screensaver lock-enabled false >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.session idle-delay 0 >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.power idle-dim false >> $LOG_FILE 2>&1

  log "Idle delay has been set to 0"
  log "Power idle dim has been disabled"

  log "Screen lock has been disabled successfully\n"
}

# Task to set shortcuts for multiple monitor workspaces
configureWorkspaceShortcuts () {
  log "Setting shortcuts for workspaces and windows navigation"

  gsettings set org.gnome.mutter workspaces-only-on-primary false >> $LOG_FILE 2>&1

  log "Workspaces for multiple monitor setups have been enabled"

  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-up "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-up "['<Super>Up']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-down "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-down "['<Super>Down']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-last "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['']" >> $LOG_FILE 2>&1

  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>Insert']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>Home']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>Page_Up']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Super>Delete']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-5 "['<Super>End']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-6 "['<Super>Page_Down']" >> $LOG_FILE 2>&1

  log "Workspaces shortcuts have been set"

  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-up "['<Super><Alt>Up']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-down "['<Super><Alt>Down']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-last "['']" >> $LOG_FILE 2>&1

  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-1 "['<Super><Alt>Insert']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-2 "['<Super><Alt>Home']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-3 "['<Super><Alt>Page_Up']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-4 "['<Super><Alt>Delete']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-5 "['<Super><Alt>End']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-6 "['<Super><Alt>Page_Down']" >> $LOG_FILE 2>&1

  gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-left "['<Super><Alt>Left']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-right "['<Super><Alt>Right']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-up "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-down "['']" >> $LOG_FILE 2>&1

  gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "['<Ctrl><Super>Up']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings minimize "['<Ctrl><Super>Down']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings maximize "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings unmaximize "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings maximize-horizontally "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings maximize-vertically "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings begin-move "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings begin-resize "['']" >> $LOG_FILE 2>&1

  gsettings set org.gnome.mutter.keybindings toggle-tiled-left "['<Ctrl><Super>Left']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.mutter.keybindings toggle-tiled-right "['<Ctrl><Super>Right']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-corner-ne "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-corner-nw "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-corner-se "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-corner-sw "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-side-e "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-side-n "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-side-w "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings move-to-side-s "['']" >> $LOG_FILE 2>&1

  gsettings set org.gnome.desktop.wm.keybindings always-on-top "['<Ctrl><Super>Insert']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings lower "['<Ctrl><Super>Home']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings raise "['<Ctrl><Super>Page_Up']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Ctrl><Super>Delete']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings close "['<Ctrl><Super>End']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings show-desktop "['<Ctrl><Super>Page_Down']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings activate-window-menu "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings toggle-on-all-workspaces "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings raise-or-lower "['']" >> $LOG_FILE 2>&1

  log "Windows navigation shortcuts have been set"

  gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Ctrl>Up']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-windows "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-windows-backward "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-panels "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-panels-backward "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-group "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-group-backward "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings cycle-windows "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings cycle-windows-backward "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings cycle-panels "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings cycle-panels-backward "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings cycle-group "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings cycle-group-backward "['']" >> $LOG_FILE 2>&1

  log "Application switcher shortcut has been set"

  # Disable switch display modes cause might interfere with rest shortcuts
  gsettings set org.gnome.mutter.keybindings switch-monitor "['']" >> $LOG_FILE 2>&1

  log "Shortcuts for workspaces and windows have been configured successfully\n"
}

# Task to set system shortcuts
configureSystemShortcuts () {
  log "Setting shortcuts for various system operations"

  gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward  "['']" >> $LOG_FILE 2>&1

  log "Keyboard input source shortcut has been set"

  gsettings set org.gnome.settings-daemon.plugins.media-keys volume-up "['<Super>period']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys volume-down "['<Super>comma']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys volume-mute "['<Super>slash']" >> $LOG_FILE 2>&1

  log "Sound volume shortcuts have been set"

  gsettings set org.gnome.settings-daemon.plugins.media-keys screenshot "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys screenshot-clip "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys window-screenshot "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys window-screenshot-clip "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys area-screenshot-clip "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys area-screenshot "['Print']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys screencast "['<Super>Print']" >> $LOG_FILE 2>&1

  log "Screenshot and screencast shortcuts have been set"

  gsettings set org.gnome.shell.keybindings focus-active-notification "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.shell.keybindings open-application-menu "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.shell.keybindings toggle-application-view "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.shell.keybindings toggle-message-tray "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.shell.keybindings toggle-overview "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.mutter.wayland.keybindings restore-shortcuts "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings panel-main-menu "['']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "['Scroll_Lock']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys logout "['<Super>Scroll_Lock']" >> $LOG_FILE 2>&1

  log "Lock and logout shortcuts have been set"

  gsettings set org.gnome.settings-daemon.plugins.media-keys control-center "['<Super>s']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "['<Super>t']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys www "['<Super>w']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys home "['<Super>e']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys calculator "['<Super>c']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys email "['<Super>m']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.desktop.wm.keybindings panel-run-dialog "['<Super>backslash']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>i']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys search "['<Super>f']" >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys help "['<Super>h']" >> $LOG_FILE 2>&1

  log "Launcher shortcuts have been set"

  local k=(
    '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/'
    '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/'
    '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/'
    '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/'
    '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/'
  )
  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['${k[0]}', '${k[1]}', '${k[2]}', '${k[3]}', '${k[4]}']" >> $LOG_FILE 2>&1

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Network Settings' >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'gnome-control-center network' >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>n' >> $LOG_FILE 2>&1

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name 'Bluetooth Settings' >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command 'gnome-control-center bluetooth' >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding '<Super>b' >> $LOG_FILE 2>&1

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ name 'Sound Settings' >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ command 'gnome-control-center sound' >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ binding '<Super>a' >> $LOG_FILE 2>&1

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ name 'Power Off' >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ command 'gnome-session-quit --power-off' >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ binding '<Super>Pause' >> $LOG_FILE 2>&1

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ name 'Open Editor' >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ command 'gedit' >> $LOG_FILE 2>&1
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ binding '<Super>g' >> $LOG_FILE 2>&1

  log "Custom keybindigns have been set"

  log "System shortcuts have been configured successfully\n"
}

# Task to print a good bye message
sayGoodBye () {
  progress "Stack crew ready for landing" "\U1F4AC"
  sleep 2
  progress "Current velocity is 5 meters/sec" "\U1F4AC"
  sleep 4
  progress "Touch down, we have touch down!" "\U1F4AC"
  sleep 2

  # Clean up any unnecessary package
  removeUnnecessaryPackages

  local endTime=`date +%s`
  local runtime=$(((endTime-startTime)/60))

  log "Installation has been completed in $runtime mins \U1F389"
  log "Have a nice coding time, $USER!\n"
}

# Task to reboot the system
rebootSystem () {
  log "Script has been switched to restart mode..."
  
  # Count down 45 secs before reboot
  for secs in $(seq 45 -1 0); do
    progress "Reboot will start in $secs secs (Ctrl-C to cancel)"
    sleep 1
  done

  reboot
}

# Create the temporary folder
mkdir -p $TEMP

# Echoing welcome messages
log "Stack v$VERSION"
log "Running on $(lsb_release -si) $(lsb_release -sr) $(lsb_release -sc)"
log "Logged in as $USER@$HOSTNAME with kernel $(uname -r)"
log "Temporary folder has been created ($TEMP)"
log "Logs have been routed to $LOG_FILE"

# Disallow to run this script as root or with sudo
if [[ "$UID" == "0" ]]; then
  abort "Error: Do not run this script as root or using sudo"
  exit 1
fi

# Read options, y to enable yes to all tasks
yesToAll=false
while getopts :y opt; do
  case $opt in
    y)
     yesToAll=true
     log "Option -y (yes to all tasks) has been enabled";;
    *) abort "Error: Ooops argument $OPTARG is not supported";;
  esac
done

log "Script initialization has been completed"

# Fill up task execution list
tasks=()

if [[ $yesToAll = false ]]; then
  log "\nCaptain, the system is out of order" "\U1F4AC"
  ask "Should system time be set to local RTC time?" setLocalRTCTime
  ask "Do you need to monitor many files?" increaseInotifyLimit
  ask "Do you want to enable firewall?" enableFirewall
  ask "Is Greek an extra language you need?" installGreekLanguage

  log "\nDope, shippin' with containers is" "\U1F4AC"
  ask "Do you want to install Virtual Box?" installVirtualBox
  ask "Do you want to install Docker and Compose?" installDocker
  ask "Do you want to install Dropbox?" installDropbox

  log "\nWe all say coding is so sexy" "\U1F4AC"
  ask "Do you want to install Git?" installGit

  if [[ $(tasksContains installGit) == true ]]; then
    read -p "Awesome, what's your git user name?(enter to skip) " GIT_USER_NAME
    read -p "May I have your git user email as well?(enter to skip) " GIT_USER_EMAIL

    ask "Should cmd prompt show the branch in git folders?" enableGitPrompt
  fi

  ask "Do you want to install Node?" installNode
  ask "Do you want to install Java?" installJava
  ask "Do you want to install Atom?" installAtom
  ask "Do you want to install Visual Studio Code?" installVSCode
  ask "Do you want to install Sublime Text?" installSublimeText
  ask "Are you that brave to use Neovim editor?" installNeovim
  ask "Do you want to install IntelliJ Idea?" installIntelliJIdea

  log "\nIt's all about data" "\U1F4AC"
  ask "Do you want to install MongoDB Compass?" installMongoDBCompass
  ask "Do you want to install DBeaver?" installDBeaver
  ask "Do you want to install Postman?" installPostman

  log "\nWork in teams, get things done" "\U1F4AC"
  ask "Do you want to install Chrome?" installChrome
  ask "Do you want to install Thunderbird?" installThunderbird
  ask "Do you want to install Slack?" installSlack
  ask "Do you want to install Discord?" installDiscord
  ask "Do you want to install Telegram?" installTelegram
  ask "Do you want to install Microsoft Teams?" installMSTeams
  ask "Do you want to install Skype?" installSkype
  ask "Do you want to install TeamViewer?" installTeamViewer
  ask "Do you want to install Libre Office?" installLibreOffice

  log "\nNobody is escaping from media nowdays" "\U1F4AC"
  ask "Do you want to install Gimp?" installGimp
  ask "Do you want to install VLC player?" installVLC
  ask "Do you want to install Rhythmbox player?" installRhythmbox
  ask "Do you want to install Spotify?" installSpotify

  log "\nMe likes a clean look and feel" "\U1F4AC"
  ask "You may want to hide desktop icons?" configureDesktop
  ask "Do you want to reposition dock to the bottom?" configureDock
  ask "Do you like home folders renamed to lowercase?" renameHomeFolders
  ask "Would disabling screen lock be helpful to you?" disableScreenLock
  ask "Do you want to override default workspaces shortcuts?" configureWorkspaceShortcuts
  ask "Do you want to override default system shortcuts?" configureSystemShortcuts

  tasks+=(sayGoodBye)

  log "\nWe're almost done" "\U1F4AC"
  ask "Do you want to reboot after installation?" rebootSystem
else
  tasks+=(
    setLocalRTCTime
    increaseInotifyLimit
    enableFirewall
    installGreekLanguage
    installVirtualBox
    installDocker
    installDropbox
    installGit
    enableGitPrompt
    installNode
    installJava
    installAtom
    installVSCode
    installSublimeText
    installNeovim
    installIntelliJIdea
    installMongoDBCompass
    installDBeaver
    installPostman
    installChrome
    installThunderbird
    installSlack
    installDiscord
    installTelegram
    installMSTeams
    installSkype
    installTeamViewer
    installLibreOffice
    installGimp
    installVLC
    installRhythmbox
    installSpotify
    configureDesktop
    configureDock
    renameHomeFolders
    disableScreenLock
    configureWorkspaceShortcuts
    configureSystemShortcuts
    sayGoodBye
    rebootSystem
  )
fi

# Echoing launching messages
progress "\nStack crew ready for launch" "\U1F4AC"
sleep 2
progress "T-10 seconds to go..." "\U1F4AC"
sleep 2
for secs in $(seq 8 -1 0); do
  progress "Installation will launch in $secs (Ctrl-C to abort)" "\U1F4AC"
  sleep 1
done

progress "Igggnition..." "\U1F525\U1F4A8"
sleep 2
progress "Liftoff! We have Liftoff!" "\U1F4AC"
sleep 4

log "Installation has been started"

# Execute some preparatory tasks
updateRepositories
upgradeSystem
installPrerequisites

log "Stack is now ready to start executing tasks\n"

startTime=`date +%s`

# Start executing each task in order
for task in "${tasks[@]}"; do "${task}"; done