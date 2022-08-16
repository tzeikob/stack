#!/usr/bin/env bash

trim () {
  local input=""
  [[ -p /dev/stdin ]] && input="$(cat -)" || input="${@}"

  echo -e "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

no_breaks () {
  local input=""
  [[ -p /dev/stdin ]] && input="$(cat -)" || input="${@}"

  echo -e "$input" | tr -d '\n'
}

spaces_to_under () {
  local input=""
  [[ -p /dev/stdin ]] && input="$(cat -)" || input="${@}"

  echo -e "$input" | awk '{gsub(/ /, "_", $0); print $0}'
}

under_to_spaces () {
  local input=""
  [[ -p /dev/stdin ]] && input="$(cat -)" || input="${@}"

  echo -e "$input" | awk '{gsub(/_/, " ", $0); print $0}'
}

remove_dups () {
  local ARR=("${@}")

  echo "${ARR[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

print () {
  local COLS=$1 && shift
  local UNDERSCORES=$1 && shift

  local ARR=("${@}")
  local LEN=${#ARR[@]}

  # Calculate total rows for the given length and columns
  local ROWS=$(((LEN + COLS - 1) / COLS))

  for ((i = 0; i < $ROWS; i++)); do
    for ((j = 0; j < $COLS; j++)); do
      # Map the index of the item to print vertically
      local index=$((i + (j * ROWS)))

      if [[ ! -z "${ARR[$index]}" ]]; then
        local text=$(no_breaks "${ARR[index]}")

        # Replace underscores with spaces
        if [[ "$UNDERSCORES" == true ]]; then
          text=$(under_to_spaces "$text")
        fi

        printf " %-25s\t" "$text"
      fi
    done

    printf "\n"
  done
}

set_option () {
  touch -f .options

  # Override pre-existing option
  if grep -Eq "^$1.*" .options; then
    sed -i -e "/^$1.*/d" .options
  fi

  echo "$1=$2" >> .options
}

set_password () {
  local PASSWORD
  local COMFIRMED

  read -rs -p " Enter a new password: " PASSWORD && echo
  read -rs -p " Re-enter the password: " COMFIRMED

  # Repeat until password comfirmed 
  while [ "$PASSWORD" != "$COMFIRMED" ]; do
    echo -e "\n Ooops, passwords do not match"
    read -rs -p " Please enter a new password: " PASSWORD && echo
    read -rs -p " Re-enter the password: " COMFIRMED
  done

  set_option "$1_PASSWORD" "$PASSWORD"
}

set_mirrors () {
  local OLD_IFS=$IFS
  IFS=","

  local COUNTRIES=($(
    reflector --list-countries |
    tail -n +3 |
    awk '{split($0,a,/[A-Z]{2}/); print a[1]}' |
    trim |
    awk '{print $0","}' |
    spaces_to_under |
    no_breaks
  ))

  IFS=$OLD_IFS

  print 4 true "${COUNTRIES[@]}"

  local COUNTRY=""
  read -p " Enter the primary mirror country: [Greece] " COUNTRY
  COUNTRY=${COUNTRY:-"Greece"}
  COUNTRY="$(trim "$COUNTRY")"

  while [[ ! " ${COUNTRIES[*]} " =~ " $(spaces_to_under "$COUNTRY") " ]]; do
    read -p " Please enter a valid country: " COUNTRY
    COUNTRY="$(trim "$COUNTRY")"
  done

  local MIRROR_SET="\"$COUNTRY\""

  while [[ ! -z "$COUNTRY" ]]; do
    read -p " Enter another secondary mirror country (none to skip): " COUNTRY
    COUNTRY="$(trim "$COUNTRY")"

    while [ ! -z "$COUNTRY" ] && [[ ! " ${COUNTRIES[*]} " =~ " $(spaces_to_under "$COUNTRY") " ]]; do
      read -p " Please enter a valid country: " COUNTRY
      COUNTRY="$(trim "$COUNTRY")"
    done

    [[ ! -z "$COUNTRY" ]] && MIRROR_SET="$MIRROR_SET \"$COUNTRY\""
  done

  MIRROR_SET="$(trim "$MIRROR_SET")"

  set_option "MIRRORS" "($MIRROR_SET)"
  echo -e " Mirror countries set to $MIRROR_SET\n"
}

set_timezone () {
  local CONTINENTS=(
    "Africa" "America" "Antarctica" "Arctic" "Asia"
    "Atlantic" "Australia" "Europe" "Indian" "Pacific"
  )

  print 4 false "${CONTINENTS[@]}"

  local CONTINENT=""
  read -p " Select your continent: [Europe] " CONTINENT
  CONTINENT=${CONTINENT:-"Europe"}
  CONTINENT=$(trim "$CONTINENT")

  while [[ ! "$CONTINENT" =~ ^(Africa|America|Antarctica|Arctic|Asia|Atlantic|Australia|Europe|Indian|Pacific)$ ]]; do
    read -p " Please enter a valid continent: " CONTINENT
    CONTINENT=$(trim "$CONTINENT")
  done

  echo

  local CITIES=($(ls -1 -pU /usr/share/zoneinfo/$CONTINENT | grep -v /))

  print 4 false "${CITIES[@]}"

  local CITY=""
  read -p " Enter the city closer to your timezone? " CITY
  CITY=$(trim "$CITY")

  while [ ! -f "/usr/share/zoneinfo/$CONTINENT/$CITY" ]; do
    read -p " Please enter a valid timezone city: " CITY
    CITY=$(trim "$CITY")
  done

  local TIMEZONE="$CONTINENT/$CITY"

  set_option "TIMEZONE" "$TIMEZONE"
  echo -e " Current timezone is set to $TIMEZONE\n"
}

set_keymap () {
  local OLD_IFS=$IFS
  IFS=","

  local extra="apple|mac|window|sun|atari|amiga|ttwin|ruwin"
  extra="$extra|wangbe|adnw|applkey|backspace|bashkir|bone"
  extra="$extra|carpalx|croat|colemak|ctrl|defkeymap|euro|keypad|koy"

  local MAPS=($(
    localectl --no-pager list-keymaps |
    trim |
    awk '{print $0","}' |
    sed -n -E "/$extra/!p"
  ))

  print 4 false "${MAPS[@]}"

  read -p " Enter your keyboard's keymap (extra for more maps): [us] " KEYMAP
  KEYMAP=${KEYMAP:-"us"}
  KEYMAP=$(trim "$KEYMAP")

  if [ "$KEYMAP" == "extra" ]; then
    local EXTRA=($(
      localectl --no-pager list-keymaps |
      trim |
      awk '{print $0","}' |
      sed -n -E "/$extra/p"
    ))

    echo
    print 4 false "${EXTRA[@]}"

    read -p " Enter your keyboard's keymap: " KEYMAP
    KEYMAP=$(trim "$KEYMAP")
  fi

  IFS=$OLD_IFS

  while [ -z "$(find /usr/share/kbd/keymaps/ -type f -name "$KEYMAP.map.gz")" ]; do
    read -p " Please enter a valid keyboard map: " KEYMAP
    KEYMAP=$(trim "$KEYMAP")
  done

  set_option "KEYMAP" "$KEYMAP"
  echo -e " Keyboard keymap is set to $KEYMAP\n"
}

set_layouts () {
  LAYOUTS=(
    af al am ara at au az ba bd be bg br brai bt bw by ca cd ch cm cn cz
    de dk dz ee epo es et fi fo fr gb ge gh gn gr hr hu id ie il in iq ir
    is it jp ke kg kh kr kz la latam lk lt lv ma mao md me mk ml mm mn mt
    mv my ng nl no np ph pk pl pt ro rs ru se si sk sn sy tg th tj tm tr
    tw tz ua us uz vnza
  )

  print 4 false "${LAYOUTS[@]}"

  read -p " Enter your primary keyboard layout: [us] " LAYOUT
  LAYOUT=${LAYOUT:-"us"}
  LAYOUT="$(trim "$LAYOUT")"

  while [[ ! " ${LAYOUTS[*]} " =~ " $LAYOUT " ]]; do
    read -p " Please enter a valid layout: " LAYOUT
    LAYOUT="$(trim "$LAYOUT")"
  done

  local LAYOUT_SET="\"$LAYOUT\""

  while [[ ! -z "$LAYOUT" ]]; do
    read -p " Enter another secondary layout (none to skip): " LAYOUT
    LAYOUT="$(trim "$LAYOUT")"

    while [[ ! -z "$LAYOUT" ]] && [[ ! " ${LAYOUTS[*]} " =~ " $LAYOUT " ]]; do
      read -p " Please enter a valid layout: " LAYOUT
      LAYOUT="$(trim "$LAYOUT")"
    done

    [[ ! -z "$LAYOUT" ]] && LAYOUT_SET="$LAYOUT_SET \"$LAYOUT\""
  done

  LAYOUT_SET="$(trim "$LAYOUT_SET")"

  set_option "LAYOUTS" "($LAYOUT_SET)"
  echo -e "Keyboard layout(s) is set to $LAYOUT_SET\n"
}

set_locale () {
  local LOCALES=($(
    cat /etc/locale.gen |
    tail -n +23 |
    tr -d '#' |
    awk '{split($0,a,/ /); print a[1]}'
  ))

  local LANGS=($(
    echo "${LOCALES[@]}" |
    tr ' ' '\n' |
    awk '{split($0,a,/_/); print a[1]}' |
    awk '{print $0" "}'
  ))

  LANGS=($(remove_dups "${LANGS[@]}"))

  print 4 false "${LANGS[@]}"

  local LANG=""
  read -p " Enter the language of your locale: [en] " LANG
  LANG=${LANG:-"en"}
  LANG="$(trim "$LANG")"

  while ! grep -q "$LANG" /etc/locale.gen; do
    read -p " Please enter a valid locale language: " LANG
    LANG="$(trim "$LANG")"
  done

  local ENCODINGS=($(
    cat /etc/locale.gen |
    tail -n +23 |
    tr -d '#' |
    awk "/^$LANG/{print}" |
    awk '{split($0,a,/_/); print a[2]}' |
    spaces_to_under |
    awk '{print $0" "}'
  ))

  print 4 true "${ENCODINGS[@]}"

  local ENCODING=""
  read -p " Enter a locale encoding: " ENCODING
  ENCODING="$(trim "$ENCODING")"

  local LOCALE=$(trim "${LANG}_$ENCODING")

  while ! grep -q "$LOCALE" /etc/locale.gen; do
    read -p " Please enter a valid locale encoding: " ENCODING
    ENCODING="$(trim "$ENCODING")"
    LOCALE=$(trim "${LANG}_$ENCODING")
  done

  set_option "LOCALE" "$LOCALE"
  echo -e "Locale is set to $LOCALE\n"
}

clear

echo "Locations and Timezones:" &&
  set_mirrors &&
  set_timezone &&
echo "Languages and Locales:" &&
  set_keymap &&
  set_layouts &&
  set_locale

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
KERNEL=${KERNEL,,}

while [[ ! $KERNEL =~ ^(stable|lts|all)$ ]]; do
  echo -e "Invalid linux kernel: $KERNEL"
  read -p "Please enter which linux kernel to install: [STABLE/lts/all] " KERNEL
  KERNEL=${KERNEL:-"stable"}
  KERNEL=${KERNEL,,}
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
REPLY=${REPLY,,}

if [[ ! $REPLY =~ ^(y|yes)$ ]]; then
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
CPU=${CPU,,}

while [[ ! $CPU =~ ^(amd|intel)$ ]]; do
  echo -e "Invalid CPU vendor: $CPU"
  read -p "Please enter a valid CPU vendor: [AMD/intel] " CPU
  CPU=${CPU:-"amd"}
  CPU=${CPU,,}
done

set_option "CPU" "$CPU"
echo "CPU is set to $CPU"

read -p "Which GPU vendor video drivers to install? [nvidia/amd/intel/nouveau/qxl/vmware/none] " GPU
GPU=${GPU,,}

while [[ ! $GPU =~ ^(nvidia|amd|intel|nouveau|qxl|vmware|none)$ ]]; do
  echo -e "Invalid GPU driver vendor: $GPU"
  read -p "Please enter a valid GPU driver vendor: [nvidia/amd/intel/nouveau/qxl/vmware/none] " GPU
  GPU=${GPU,,}
done

set_option "GPU" "$GPU"
echo "GPU is set to $GPU"

read -p "Is this a virtual box machine? [y/N] " IS_VM
IS_VM=${IS_VM:-"no"}
IS_VM=${IS_VM,,}

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
