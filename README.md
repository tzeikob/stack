# Stack

Stack is a welcome script tool to speed up and automate the tasks you have to do in order to setup and install your development stack software right after a fresh and clean ubuntu installation.

> Note: This script tool is using **sudo** internally to get root access so to be able to setup your system and install third-party software, please read carefully before proceed.

## What this tool does?

### Opt in for optional tasks

The tool has been implemented in an opt in/out approach, where the user decides which of the provided tasks he goes with. The script will start iterating across a set of questions per task and every time the user opts in, the corresponding task wil be added to the execution list. A task could be either a configuration or installation task. The tasks are grouped in the following main scopes:

* Base system configuration
* Programming languages
* Development and IDEs
* Database and APIs
* Containerization and virtual machines
* Collaboration and team work
* Music and media
* Look and feel

Each task will be provide as a question to the user asking him to opt in or not:

```sh
Do you want to install Node?(Y/n) y
Do you want to install Visual Studio Code?(Y/n) y
...
```

### Mandatory and preparatory tasks

Apart from the opt in tasks the tool executes a set of mandatory and preparatory system tasks:

* Update the apt-get repositories
* Upgrade the system to latest updates
* Install a few prerequisite utility packages

These tasks will be executed before any opt in task though making sure the system along with any dependencies are set up.

## How to use it

### Run it as a standalone bash script

Just copy, paste and execute the following command in your prompt:

```sh
bash -c "$(wget -qO- https://git.io/JuSGv)"
```

Otherwise you can download the script file to your local folder, make it executable and run it like so:

```sh
wget https://raw.githubusercontent.com/tzeikob/stack/master/script.sh

chmod +x ./script.sh

./script
```

## List of opt in tasks

Below you can find the full list of each task provided currently by the tool.

```
Base system configuration

  - Set system time to local RTC time
  - Allow to monitor large amount of files
  - Enable firewall via UFW
  - Install extra unicode languages like Greek

Programming languages

  - Install Git
  - Install Node
  - Install Java

Development and IDEs

  - Install Visual Studio Code
  - Install Atom
  - Install Sublime Text
  - Install Neovim
  - Install IntelliJ Idea

Database and APIs

  - Install MongoDB Compass
  - Install DBeaver
  - Install Postman

Containerization and virtual machines

  - Install Docker and Compose
  - Install Virtual Box

Collaboration and team work

  - Install Chrome
  - Install Thunderbird
  - Install Slack
  - Install Discord
  - Install Telegram
  - Install Microsoft Teams
  - Install Skype
  - Install TeamViewer
  - Install Dropbox
  - Install Libre Office

Music and media

  - Install Rhythmbox
  - Install VLC
  - Install Spotify
  - Install Gimp

Look and feel

  - Hide desktop icons
  - Move dock to the bottom
  - Rename home folders to lowercase
  - Disable auto screen lock
  - Override default system shortcuts
  - Override default workspaces shortcuts
  - Set cmd prompt to show branch for git folders
```