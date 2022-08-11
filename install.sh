#!/usr/bin/env bash

clear

if [[ "$(id -u)" != "0" ]]; then
  echo "Error: script must be run as root"
  echo "Process exiting with code 1"
  exit 1
fi

if [[ ! -e /etc/arch-release ]]; then
  echo "Error: script must be run in an archiso only"
  echo "Process exiting with code 1"
  exit 1
fi

cat << EOF
[38;2;6;221;155m░[39m[38;2;7;221;154m█[39m[38;2;7;222;154m▀[39m[38;2;7;222;154m▀[39m[38;2;7;222;154m░[39m[38;2;7;222;153m▀[39m[38;2;7;222;153m█[39m[38;2;7;223;153m▀[39m[38;2;7;223;153m░[39m[38;2;7;223;152m█[39m[38;2;7;223;152m▀[39m[38;2;7;223;152m█[39m[38;2;7;223;152m░[39m[38;2;8;224;151m█[39m[38;2;8;224;151m▀[39m[38;2;8;224;151m▀[39m[38;2;8;224;151m░[39m[38;2;8;224;150m█[39m[38;2;8;224;150m░[39m[38;2;8;225;150m█[39m[38;2;8;225;150m[39m
[38;2;7;223;152m░[39m[38;2;7;223;152m▀[39m[38;2;7;223;152m▀[39m[38;2;8;224;151m█[39m[38;2;8;224;151m░[39m[38;2;8;224;151m░[39m[38;2;8;224;151m█[39m[38;2;8;224;150m░[39m[38;2;8;224;150m░[39m[38;2;8;225;150m█[39m[38;2;8;225;150m▀[39m[38;2;8;225;149m█[39m[38;2;8;225;149m░[39m[38;2;8;225;149m█[39m[38;2;8;225;149m░[39m[38;2;9;225;148m░[39m[38;2;9;226;148m░[39m[38;2;9;226;148m█[39m[38;2;9;226;148m▀[39m[38;2;9;226;147m▄[39m[38;2;9;226;147m[39m
[38;2;8;225;150m░[39m[38;2;8;225;149m▀[39m[38;2;8;225;149m▀[39m[38;2;8;225;149m▀[39m[38;2;8;225;149m░[39m[38;2;9;225;148m░[39m[38;2;9;226;148m▀[39m[38;2;9;226;148m░[39m[38;2;9;226;148m░[39m[38;2;9;226;147m▀[39m[38;2;9;226;147m░[39m[38;2;9;226;147m▀[39m[38;2;9;227;147m░[39m[38;2;9;227;146m▀[39m[38;2;9;227;146m▀[39m[38;2;9;227;146m▀[39m[38;2;10;227;146m░[39m[38;2;10;227;145m▀[39m[38;2;10;228;145m░[39m[38;2;10;228;145m▀[39m[38;2;10;228;145m[39m
EOF

echo -e "\nWelcome to Stack installation"
read -p "Do you want to proceed to the installation? [Y/n] " REPLY
REPLY=${REPLY:-"yes"}
REPLY=${REPLY,,}

if [[ ! $REPLY =~ ^(y|yes)$ ]]; then
  echo -e "Exiting the isntallation process..."
  exit 1
fi

bash scripts/askme.sh &&
  bash scripts/bootstrap.sh &&
  bash scripts/diskpart.sh &&
  bash scripts/base.sh &&
  arch-chroot /mnt /usr/bin/runuser -u $username -- /scripts/stack.sh &&
    echo "Unmounting all partitions under '/mnt'..." &&
    umount -R /mnt || echo "Ignoring any busy mounted points..." &&
    echo "Rebooting the system in 15 secs (ctrl-c to skip)..." &&
    sleep 15 &&
    reboot
