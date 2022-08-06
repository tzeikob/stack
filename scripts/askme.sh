#!/usr/bin/env bash

shopt -s nocasematch

trim () {
  echo -e "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

set_option () {
  touch -f .options

  # Override pre-existing option
  if grep -Eq "^${1}.*" .options; then
    sed -i -e "/^${1}.*/d" .options
  fi

  echo "${1}=${2}" >> .options
}

set_password () {
  read -rs -p "Enter a new password: " PASSWORD
  read -rs -p "Re-enter the password: " COMFIRMED

  # Repeat until password comfirmed 
  while [ "$PASSWORD" != "$COMFIRMED" ]; do
    echo "Ooops, passwords do not match"
    read -rs -p "Please enter a new password: " PASSWORD
    read -rs -p "Re-enter the password: " COMFIRMED
  done

  set_option "$1_PASSWORD" "$PASSWORD"
}

echo "Setting locations and timezones..."

read -p "Enter your current location? [Greece] " COUNTRY
COUNTRY=${COUNTRY:-"Greece"}

set_option "COUNTRY" "$COUNTRY"
echo "Current location is set to $COUNTRY"

read -p "Enter your current timezone? [Europe/Athens] " TIMEZONE
TIMEZONE=${TIMEZONE:-"Europe/Athens"}

while [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; do
  echo "Invalid timezone: $TIMEZONE"
  read -p "Please enter a valid timezone: [Europe/Athens] " TIMEZONE
  TIMEZONE=${TIMEZONE:-"Europe/Athens"}
done

set_option "TIMEZONE" "$TIMEZONE"
echo "Current timezone is set to $TIMEZONE"

echo -e "\nSetting locales and languages"

read -p "Enter your keyboard's keymap: [us] " KEYMAP
KEYMAP=${KEYMAP:-"us"}

KEYMAP_PATH=$(find /usr/share/kbd/keymaps/ -type f -name "$KEYMAP.map.gz")

while [ -z "$KEYMAP_PATH" ]; do
  echo "Invalid keyboard map: $KEYMAP"
  read -p "Please enter a valid keyboard map: [us] " KEYMAP
  KEYMAP=${KEYMAP:-"us"}

  KEYMAP_PATH=$(find /usr/share/kbd/keymaps/ -type f -name "$KEYMAP.map.gz")
done

set_option "KEYMAP" "$KEYMAP"
echo "Keyboard map is set to keymap $KEYMAP"

LAYOUTS_SET=(
  af al am ara at au az ba bd be bg br brai bt bw by ca cd ch cm cn cz
  de dk dz ee epo es et fi fo fr gb ge gh gn gr hr hu id ie il in iq ir
  is it jp ke kg kh kr kz la latam lk lt lv ma mao md me mk ml mm mn mt
  mv my ng nl no np ph pk pl pt ro rs ru se si sk sn sy tg th tj tm tr
  tw tz ua us uz vnza
)

read -p "Enter which keyboard layouts to install (e.g. us gr): [us] " LAYOUTS_RAW
LAYOUTS_RAW=${LAYOUTS_RAW:-"us"}
LAYOUTS_RAW="$(trim "$LAYOUTS_RAW")"

for LAYOUT in $LAYOUTS_RAW; do
  while [ -z "$LAYOUT" ] || [[ ! " ${LAYOUTS_SET[*]} " =~ " ${LAYOUT} " ]]; do
    echo "Invalid layout name: $LAYOUT"
    read -p "Please re-enter the layout: " LAYOUT
  done

  LAYOUTS="$LAYOUTS $LAYOUT"
done

LAYOUTS="$(trim "$LAYOUTS")"
echo "Keyboard layout(s) is set to $LAYOUTS"

read -p "Enter which locales to install (e.g. en_US el_GR): [en_US] " LOCALES_RAW
LOCALES_RAW=${LOCALES_RAW:-"en_US"}

for LOCALE in $LOCALES_RAW; do
  while [ -z "$LOCALE" ] || ! grep -q "$LOCALE" /etc/locale.gen; do
    echo "Invalid locale name: $LOCALE"
    read -p "Please re-enter the locale: " LOCALE
  done

  LOCALES="$LOCALES $LOCALE"
done

set_option "LOCALES" "$LOCALES"
echo "Locale(s) is set to $LOCALES"

echo -e "\nSetting users and hostname..."

read -p "Enter the host name of your system: [arch] " HOSTNAME
HOSTNAME=${HOSTNAME:-"arch"}
HOSTNAME=${HOSTNAME,,}

set_option "HOSTNAME" "$HOSTNAME"
echo "Hostname is set to $HOSTNAME"

read -p "Enter your user name: [bob] " USERNAME
USERNAME=${USERNAME:-"bob"}
USERNAME=${USERNAME,,}

set_option "USERNAME" "$USERNAME"
echo "User's name is set to $USERNAME"

echo "Setting user's password..."

set_password "USER"
echo "User's password is set successfully"

echo "Setting root user's password..."

set_password "ROOT"
echo "Root user's password is set successfully"

echo -e "\nSelecting kernel and packages"

read -p "Which linux kernel to install: [STABLE/lts/all] " KERNEL
KERNEL=${KERNEL:-"stable"}

while [[ ! $KERNEL =~ ^(stable|lts|all)$ ]]; do
  echo -e "Invalid linux kernel: $KERNEL"
  read -p "Please enter which linux kernel to install: [STABLE/lts/all] " KERNEL
  KERNEL=${KERNEL:-"stable"}
done

set_option "KERNEL" "$KERNEL"
echo "Linux kernel(s) is set to $KERNEL"

echo -e "\nSelect hard disk and file systems..."
echo "Select the installation disk:"
lsblk

read -p "Enter a valid block device: " DEVICE
DEVICE="/dev/$DEVICE"

while [ ! -b "$DEVICE" ]; do
  echo "Invalid block device: $DEVICE"
  read -p "Please enter a valid block device: " DEVICE
  DEVICE="/dev/$DEVICE"
done

echo -e "\nCAUTION, all data in $DEVICE will be lost"
read -p "Do you realy want to use this device as installation disk? [y/N] " REPLY
REPLY=${REPLY:-"no"}

if [[ ! $REPLY =~ ^(yes|y)$ ]]; then
  read -p "Enter another block device: " DEVICE
  DEVICE="/dev/$DEVICE"

  while [ ! -b "$DEVICE" ]; do
    echo "Invalid block device: $DEVICE"
    read -p "Please enter a valid block device: " DEVICE
    DEVICE="/dev/$DEVICE"
  done
fi

set_option "DISK" "$DEVICE"
echo "Installation disk is set to device $DEVICE"

echo "Setting the swap size..."

read -p "Enter the size of the swap file in GB (0 to skip): [0] " SWAPSIZE
SWAPSIZE=${SWAPSIZE:-0}

while [[ ! $SWAPSIZE =~ ^[0-9]+$ ]]; do
  echo -e "Invalid swap file size: $SWAPSIZE"
  read -p "Please enter a valid swap size in GB (0 to skip): [0] " SWAPSIZE
  SWAPSIZE=${SWAPSIZE:-0}
done

set_option "SWAPSIZE" "$SWAPSIZE"
echo "Swap size is set to $SWAPSIZE"

echo -e "\nSetting system environment and hardware drivers..."

read -p "What CPU is your system running on? [AMD/intel] " CPU
CPU=${CPU:-"amd"}

while [[ ! $CPU =~ ^(amd|intel)$ ]]; do
  echo -e "Invalid CPU vendor: $CPU"
  read -p "Please enter a valid CPU vendor: [AMD/intel] " CPU
  cpu_vendor=${CPU:-"amd"}
done

set_option "CPU" "$CPU"
echo "CPU is set to $CPU"

read -p "Which GPU vendor video drivers to install? [nvidia/amd/intel/nouveau/qxl/vmware/none] " GPU

while [[ ! $GPU =~ ^(nvidia|amd|intel|nouveau|qxl|vmware|none)$ ]]; do
  echo -e "Invalid GPU driver vendor: $GPU"
  read -p "Please enter a valid GPU driver vendor: [nvidia/amd/intel/nouveau/qxl/vmware/none] " GPU
done

set_option "GPU" "$GPU"
echo "GPU is set to $GPU"

read -p "Is this a virtual box machine? [y/N] " IS_VM
IS_VM=${IS_VM:-"no"}

set_option "IS_VM" "$IS_VM"
echo "VM is set to $IS_VM"

echo -e "\nResolving the system's hardware..."

IS_UEFI=false

if [ -d "/sys/firmware/efi/efivars" ]; then
  IS_UEFI=true
fi

set_option "IS_UEFI" "$IS_UEFI"
echo "UEFI is set to $IS_UEFI"

echo "System hardware has been resolved"
