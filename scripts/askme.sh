#!/usr/bin/env bash

trim () {
  local INPUT=""
  [[ -p /dev/stdin ]] && INPUT="$(cat -)" || INPUT="${@}"

  echo "$INPUT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

no_breaks () {
  local INPUT=""
  [[ -p /dev/stdin ]] && INPUT="$(cat -)" || INPUT="${@}"

  echo "$INPUT" | tr -d '\n'
}

remove_dups () {
  local ARR=("${@}")

  echo "${ARR[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

print () {
  local COLS=$1 && shift
  local PADDING=$1 && shift

  local ARR=("${@}")
  local LEN=${#ARR[@]}

  # Calculate total rows for the given length and columns
  local ROWS=$(((LEN + COLS - 1) / COLS))

  for ((i = 0; i < $ROWS; i++)); do
    for ((j = 0; j < $COLS; j++)); do
      # Map the index of the item to print vertically
      local INDX=$((i + (j * ROWS)))

      if [[ ! -z "${ARR[$INDX]}" ]]; then
        local TEXT=$(no_breaks "${ARR[$INDX]}")

        printf " %-${PADDING}s\t" "$TEXT"
      fi
    done

    printf "\n"
  done
}

contains () {
  local ITEM=$1 && shift

  local ARR=("${@}")
  local LEN=${#ARR[@]}

  for ((i = 0; i < $LEN; i++)); do
    if [[ "$ITEM" == "${ARR[$i]}" ]]; then
      return 0
    fi
  done

  return 1
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
  local SUBJECT=$1
  local RE=$2
  local MESSAGE=$3

  echo " Setting password for the ${SUBJECT,,}"
  echo " $MESSAGE"

  local PASSWORD=""
  read -rs -p " Enter a new password: " PASSWORD && echo

  while [[ ! "$PASSWORD" =~ $RE ]]; do
    read -rs -p " Please enter a valid password: " PASSWORD && echo
  done

  local COMFIRMED=""
  read -rs -p " Re-enter the password: " COMFIRMED && echo

  # Repeat until password comfirmed 
  while [ "$PASSWORD" != "$COMFIRMED" ]; do
    echo " Ooops, passwords do not match"
    read -rs -p " Please enter a new password: " PASSWORD && echo

    while [[ ! "$PASSWORD" =~ $RE ]]; do
      read -rs -p " Please enter a valid password: " PASSWORD && echo
    done

    read -rs -p " Re-enter the password: " COMFIRMED && echo
  done

  PASSWORD="\"$PASSWORD\""

  set_option "${SUBJECT}_PASSWORD" "$PASSWORD"
  echo -e " Password for the ${SUBJECT,,} is set successfully\n"
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
    no_breaks
  ))

  print 4 25 "${COUNTRIES[@]}"

  local COUNTRY=""
  read -p " Enter the primary mirror country: [Greece] " COUNTRY
  COUNTRY=${COUNTRY:-"Greece"}
  COUNTRY="$(trim "$COUNTRY")"

  while ! contains "$COUNTRY" "${COUNTRIES[@]}"; do
    read -p " Please enter a valid country: " COUNTRY
    COUNTRY="$(trim "$COUNTRY")"
  done

  local MIRROR_SET="\"$COUNTRY\""

  while [[ ! -z "$COUNTRY" ]]; do
    read -p " Enter another secondary mirror country (none to skip): " COUNTRY
    COUNTRY="$(trim "$COUNTRY")"

    while [ ! -z "$COUNTRY" ] && ! contains "$COUNTRY" "${COUNTRIES[@]}"; do
      read -p " Please enter a valid country: " COUNTRY
      COUNTRY="$(trim "$COUNTRY")"
    done

    [[ ! -z "$COUNTRY" ]] && MIRROR_SET="$MIRROR_SET \"$COUNTRY\""
  done

  IFS=$OLD_IFS

  MIRROR_SET="$(trim "$MIRROR_SET")"

  set_option "MIRRORS" "($MIRROR_SET)"
  echo -e " Mirror countries set to $MIRROR_SET\n"
}

set_timezone () {
  local CONTINENTS=(
    "Africa" "America" "Antarctica" "Arctic" "Asia"
    "Atlantic" "Australia" "Europe" "Indian" "Pacific"
  )

  print 4 15 "${CONTINENTS[@]}"

  local CONTINENT=""
  read -p " Select your continent: [Europe] " CONTINENT
  CONTINENT=${CONTINENT:-"Europe"}
  CONTINENT=$(trim "$CONTINENT")

  while ! contains "$CONTINENT" "${CONTINENTS[@]}"; do
    read -p " Please enter a valid continent: " CONTINENT
    CONTINENT=$(trim "$CONTINENT")
  done

  local CITIES=($(ls -1 -pU /usr/share/zoneinfo/$CONTINENT | grep -v /))

  echo && print 4 20 "${CITIES[@]}"

  local CITY=""
  read -p " Enter the city closer to your timezone? " CITY
  CITY=$(trim "$CITY")

  while [ ! -f "/usr/share/zoneinfo/$CONTINENT/$CITY" ]; do
    read -p " Please enter a valid timezone city: " CITY
    CITY=$(trim "$CITY")
  done

  local TIMEZONE="\"$CONTINENT/$CITY\""

  set_option "TIMEZONE" "$TIMEZONE"
  echo -e " Current timezone is set to $TIMEZONE\n"
}

set_keymap () {
  local OLD_IFS=$IFS
  IFS=","

  local EXTRA="apple|mac|window|sun|atari|amiga|ttwin|ruwin"
  EXTRA="$EXTRA|wangbe|adnw|applkey|backspace|bashkir|bone"
  EXTRA="$EXTRA|carpalx|croat|colemak|ctrl|defkeymap|euro|keypad|koy"

  local MAPS=($(
    localectl --no-pager list-keymaps |
    trim |
    awk '{print $0","}' |
    sed -n -E "/$EXTRA/!p"
  ))

  print 4 25 "${MAPS[@]}"

  local KEYMAP=""
  read -p " Enter your keyboard's keymap (extra for more maps): [us] " KEYMAP
  KEYMAP=${KEYMAP:-"us"}
  KEYMAP=$(trim "$KEYMAP")

  if [ "$KEYMAP" == "extra" ]; then
    local EXTRA=($(
      localectl --no-pager list-keymaps |
      trim |
      awk '{print $0","}' |
      sed -n -E "/$EXTRA/p"
    ))

    echo && print 4 30 "${EXTRA[@]}"

    read -p " Enter your keyboard's keymap: " KEYMAP
    KEYMAP=$(trim "$KEYMAP")
  fi

  while [ -z "$(find /usr/share/kbd/keymaps/ -type f -name "$KEYMAP.map.gz")" ]; do
    read -p " Please enter a valid keyboard map: " KEYMAP
    KEYMAP=$(trim "$KEYMAP")
  done

  IFS=$OLD_IFS

  KEYMAP="\"$KEYMAP\""

  set_option "KEYMAP" "$KEYMAP"
  echo -e " Keyboard keymap is set to $KEYMAP\n"
}

set_layouts () {
  local LAYOUTS=(
    af al am ara at au az ba bd be bg br brai bt bw by ca cd ch cm cn cz
    de dk dz ee epo es et fi fo fr gb ge gh gn gr hr hu id ie il in iq ir
    is it jp ke kg kh kr kz la latam lk lt lv ma mao md me mk ml mm mn mt
    mv my ng nl no np ph pk pl pt ro rs ru se si sk sn sy tg th tj tm tr
    tw tz ua us uz vnza
  )

  print 8 6 "${LAYOUTS[@]}"

  local LAYOUT=""
  read -p " Enter your primary keyboard layout: [us] " LAYOUT
  LAYOUT=${LAYOUT:-"us"}
  LAYOUT="$(trim "$LAYOUT")"

  while ! contains "$LAYOUT" "${LAYOUTS[@]}"; do
    read -p " Please enter a valid layout: " LAYOUT
    LAYOUT="$(trim "$LAYOUT")"
  done

  local LAYOUT_SET="\"$LAYOUT\""

  while [[ ! -z "$LAYOUT" ]]; do
    read -p " Enter another secondary layout (none to skip): " LAYOUT
    LAYOUT="$(trim "$LAYOUT")"

    while [[ ! -z "$LAYOUT" ]] && ! contains "$LAYOUT" "${LAYOUTS[@]}"; do
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
  local OLD_IFS=$IFS
  IFS=" "

  local LANGS=($(
    cat /etc/locale.gen |
    tail -n +24 |
    tr -d '#' |
    awk '{split($0,a,/ /); print a[1]}' |
    awk '{split($0,a,/_/); print a[1]}' |
    trim |
    awk '{print $0" "}'
  ))

  LANGS=($(remove_dups "${LANGS[@]}"))

  print 8 10 "${LANGS[@]}"

  local LANG=""
  read -p " Enter the language of your locale: [en] " LANG
  LANG=${LANG:-"en"}
  LANG="$(trim "$LANG")"

  while ! contains "$LANG" "${LANGS[@]}"; do
    read -p " Please enter a valid language: " LANG
    LANG="$(trim "$LANG")"
  done

  IFS=","

  local LOCALES=($(
    cat /etc/locale.gen |
    tail -n +24 |
    tr -d '#' |
    awk "/^$LANG/{print}" |
    trim |
    awk '{print $0","}' |
    no_breaks
  ))

  echo && print 5 20 "${LOCALES[@]}"

  local LOCALE=""
  read -p " Enter your locale: " LOCALE
  LOCALE="$(trim "$LOCALE")"

  while ! contains "$LOCALE" "${LOCALES[@]}"; do
    read -p " Please enter a valid locale: " LOCALE
    LOCALE="$(trim "$LOCALE")"
  done

  IFS=$OLD_IFS

  LOCALE="\"$(trim "$LOCALE")\""

  set_option "LOCALE" "$LOCALE"
  echo -e " Locale is set to $LOCALE\n"
}

set_hostname () {
  local HOSTNAME=""
  local RE="^[a-z][a-z0-9_-]+$"

  read -p " Enter a name for your host: [arch] " HOSTNAME
  HOSTNAME=${HOSTNAME:-"arch"}
  HOSTNAME=${HOSTNAME,,}

  if [[ ! "$HOSTNAME" =~ $RE ]]; then
    echo " Hostname should be at least 2 chars of [a-z0-9_-]"
    echo " First char must always be a latin letter"
  fi

  while [[ ! "$HOSTNAME" =~ $RE ]]; do
    read -p " Please enter a valid hostname: " HOSTNAME
    HOSTNAME=${HOSTNAME,,}
  done

  HOSTNAME="\"$HOSTNAME\""

  set_option "HOSTNAME" "$HOSTNAME"
  echo -e " Hostname is set to $HOSTNAME\n"
}

set_username () {
  local USERNAME=""
  local RE="^[a-z][a-z0-9_-]+$"

  read -p " Enter a username for your user: [bob] " USERNAME
  USERNAME=${USERNAME:-"bob"}
  USERNAME=${USERNAME,,}

  if [[ ! "$USERNAME" =~ $RE ]]; then
    echo " Username should be at least 2 chars of [a-z0-9_-]"
    echo " First char must always be a latin letter"
  fi

  while [[ ! "$USERNAME" =~ $RE ]]; do
    read -p " Please enter a valid username: " USERNAME
    USERNAME=${USERNAME,,}
  done

  USERNAME="\"$USERNAME\""

  set_option "USERNAME" "$USERNAME"
  echo -e " Username is set to $USERNAME\n"
}

set_disk () {
  lsblk -dA -o NAME,SIZE,FSUSE%,FSTYPE,TYPE,MOUNTPOINTS,LABEL | awk '{print " "$0}'

  local DEVICE=""
  read -p " Enter the installation disk: " DEVICE
  DEVICE="/dev/$DEVICE"

  while [ ! -b "$DEVICE" ]; do
    read -p " Please enter a valid disk block device: " DEVICE
    DEVICE="/dev/$DEVICE"
  done

  echo -e "\n CAUTION, all data in $DEVICE will be lost"

  local REPLY=""
  read -p " Proceed and use it as installation disk? [y/N] " REPLY
  REPLY=${REPLY:-"no"}
  REPLY=${REPLY,,}

  if [[ ! $REPLY =~ ^(y|yes)$ ]]; then
    read -p " Enter another disk block device: " DEVICE
    DEVICE="/dev/$DEVICE"

    while [ ! -b "$DEVICE" ]; do
      read -p " Please enter a valid disk block device: " DEVICE
      DEVICE="/dev/$DEVICE"
    done
  fi

  DEVICE="\"$DEVICE\""

  set_option "DISK" "$DEVICE"
  echo -e " Installation disk is set to block device $DEVICE\n"
}

clear

echo "Locations and Timezones:" &&
  set_mirrors &&
  set_timezone &&
echo "Languages and Locales:" &&
  set_keymap &&
  set_layouts &&
  set_locale &&
echo "Users and Passwords:" &&
  set_hostname &&
  set_username &&
  set_password "USER" \
    "^[a-zA-Z0-9@&!#%\$_-]{4,}$" \
    "Password must be at least 4 chars of a-z A-Z 0-9 @&!#%\$_-" &&
  set_password "ROOT" \
    "^[a-zA-Z0-9@&!#%\$_-]{4,}$" \
    "Password must be at least 4 chars of a-z A-Z 0-9 @&!#%\$_-" &&
echo "Disks and Partitioning:" &&
  set_disk

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
