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
  local PASSWORD
  local COMFIRMED

  read -rs -p "Enter a new password: " PASSWORD && echo
  read -rs -p "Re-enter the password: " COMFIRMED

  # Repeat until password comfirmed 
  while [ "$PASSWORD" != "$COMFIRMED" ]; do
    echo -e "\nOoops, passwords do not match"
    read -rs -p "Please enter a new password: " PASSWORD && echo
    read -rs -p "Re-enter the password: " COMFIRMED
  done

  set_option "$1_PASSWORD" "$PASSWORD"
}

set_mirror () {
  local OLD_IFS=$IFS
  IFS=","

  local COUNTRIES=($(reflector --list-countries | tail -n +3 | awk '{split($0,a,/[A-Z]{2}/); print a[1]}' | awk '{$1=$1;print}' | awk '{gsub(/ /, "_", $0); print $0","}'))

  for ((i = 0; i < ${#COUNTRIES[@]}; i = i + 4)); do
    first=$(echo ${COUNTRIES[$i]} | tr -d '\n' | awk '{gsub(/_/, " ", $0); print $0}')
    second=$(echo ${COUNTRIES[$((i + 1))]} | tr -d '\n' | awk '{gsub(/_/, " ", $0); print $0}')
    third=$(echo ${COUNTRIES[$((i + 2))]} | tr -d '\n' | awk '{gsub(/_/, " ", $0); print $0}')
    fourth=$(echo ${COUNTRIES[$((i + 3))]} | tr -d '\n' | awk '{gsub(/_/, " ", $0); print $0}')

    printf "%-25s\t%-25s\t%-25s\t%-25s\n" $first $second $third $fourth
  done

  read -p "Select a country closer to your location: [Greece] " COUNTRY
  COUNTRY=${COUNTRY:-"Greece"}

  COUNTRIES=$(echo ${COUNTRIES[*]} | tr -d '\n')
  local COUNTRY_RE=$(echo $COUNTRY | awk '{$1=$1;print}' | awk '{gsub(/ /, "_", $0); print $0}')

  while [[ ! " ${COUNTRIES[*]} " =~ " ${COUNTRY_RE} " ]]; do
    read -p "Please enter a valid country: [Greece] " COUNTRY
    COUNTRY=${COUNTRY:-"Greece"}

    COUNTRY_RE=$(echo $COUNTRY | awk '{$1=$1;print}' | awk '{gsub(/ /, "_", $0); print $0}')
  done

  IFS=$OLD_IFS

  set_option "COUNTRY" "$COUNTRY"
  echo "Mirror country is set to $COUNTRY"
}

set_timezone () {
  printf "%-25s\t%-25s\t\n" "Europe" "America"
  printf "%-25s\t%-25s\t\n" "Asia" "Africa"
  printf "%-25s\t%-25s\t\n" "Antarctica" "Arctic"

  read -p "Select your continent: [Europe] " CONTINENT
  CONTINENT=${CONTINENT:-"Europe"}

  while [[ ! "$CONTINENT" =~ (Europe|America|Asia|Africa|Antarctica|Arctic) ]]; do
    read -p "Please enter a valid continent: [Europe] " CONTINENT
    CONTINENT=${CONTINENT:-"Europe"}
  done

  echo

  CITIES=($(ls -pC /usr/share/zoneinfo/${CONTINENT} | grep -v /))

  for ((i = 0; i < ${#CITIES[@]}; i = i + 4)); do
    printf "%-25s\t%-25s\t%-25s\t%-25s\t\n" ${CITIES[$((i))]} ${CITIES[$((i + 1))]} ${CITIES[$((i + 2))]} ${CITIES[$((i + 3))]}
  done

  read -p "Enter the city closer to your timezone? " CITY
  TIMEZONE=$CONTINENT/$CITY

  while [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; do
    read -p "Please enter a valid timezone city: " CITY
    TIMEZONE=$CONTINENT/$CITY
  done

  set_option "TIMEZONE" "$TIMEZONE"
  echo "Current timezone is set to $TIMEZONE"
}

echo -e "Setting locations and timezones...\n"

set_mirror && echo
set_timezone && echo

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
