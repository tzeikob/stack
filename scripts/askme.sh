#!/usr/bin/env bash

set -Eeo pipefail

save_option () {
  local KEY=$1
  local VALUE=$2

  if [ ! -f "$OPTIONS" ]; then
    echo "Error: no options file found"
    exit 1
  fi

  # Override pre-existing option
  if grep -Eq "^${KEY}.*" "$OPTIONS"; then
    sed -i -e "/^${KEY}.*/d" "$OPTIONS"
  fi

  echo "${KEY}=${VALUE}" >> "$OPTIONS"
}

save_string () {
  save_option "$1" "\"$2\""
}

save_array () {
  save_option "$1" "($2)"
}

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

contains () {
  local ITEM=$1 && shift

  local ARR=("${@}")
  local LEN=${#ARR[@]}

  for ((i = 0; i < $LEN; i++)); do
    if [ "$ITEM" = "${ARR[$i]}" ]; then
      return 0
    fi
  done

  return 1
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

      if [ ! -z "${ARR[$INDX]}" ]; then
        local TEXT="$(no_breaks "${ARR[$INDX]}")"

        printf "%-${PADDING}s\t" "$TEXT"
      fi
    done

    printf "\n"
  done
}

init_options () {
  rm -f "$OPTIONS" && touch "$OPTIONS" || exit 1
}

is_uefi () {
  local UEFI="no"

  if [ -d "/sys/firmware/efi/efivars" ]; then
    UEFI="yes"

    echo "UEFI mode has been detected"
  else
    echo "No UEFI mode has been detected"
  fi

  save_string "UEFI" "$UEFI"
  echo "UEFI is set to \"$UEFI\""
}

what_cpu () {
  echo "Start detecting CPU vendor..."

  local CPU=$(lscpu)

  if grep -E "AuthenticAMD" > /dev/null <<< ${CPU}; then
    CPU="amd"
  elif grep -E "GenuineIntel" > /dev/null <<< ${CPU}; then
    CPU="intel"
  else
    CPU="generic"
  fi

  local REPLY=""
  read -rep "Seems your system is running an ${CPU} CPU, right? [Y/n] " REPLY
  REPLY="${REPLY:-"yes"}"
  REPLY="${REPLY,,}"

  if [[ ! "$REPLY" =~ ^(y|yes)$ ]]; then
    read -rep "Okay, which CPU is running then? [amd/intel] " CPU
    CPU="${CPU,,}"

    while [[ ! "$CPU" =~ ^(amd|intel)$ ]]; do
      read -rep " Please enter a valid CPU vendor: " CPU
      CPU="${CPU,,}"
    done
  fi

  save_string "CPU" "$CPU"

  echo "CPU vendor is set to \"$CPU\""
}

what_gpu () {
  echo "Start detecting GPU vendor..."

  local GPU=$(lspci)

  if grep -E "NVIDIA|GeForce" > /dev/null <<< ${GPU}; then
    GPU="nvidia"
  elif grep -E "Radeon|AMD" > /dev/null <<< ${GPU}; then
    GPU="amd"
  elif grep -E "Integrated Graphics Controller" > /dev/null <<< ${GPU}; then
    GPU="intel"
  elif grep -E "Intel Corporation UHD" > /dev/null <<< ${GPU}; then
    GPU="intel"
  else
    GPU="generic"
  fi

  local REPLY=""
  read -rep "Is your system using an ${GPU} GPU, right? [Y/n] " REPLY
  REPLY="${REPLY:-"yes"}"
  REPLY="${REPLY,,}"

  if [[ ! "$REPLY" =~ ^(y|yes)$ ]]; then
    read -rep "Really? Which GPU is it then? [nvidia/amd/intel] " GPU
    GPU="${GPU,,}"

    while [[ ! "$GPU" =~ ^(nvidia|amd|intel)$ ]]; do
      read -rep " Please enter a valid GPU vendor: " GPU
      GPU="${GPU,,}"
    done
  fi

  save_string "GPU" "$GPU"

  echo "GPU vendor is set to \"$GPU\""
}

want_synaptics () {
  local REPLY=""
  read -rep "Do you want to install synaptic drivers? [y/N] " REPLY
  REPLY="${REPLY:-"no"}"
  REPLY="${REPLY,,}"

  local SYNAPTICS="no"

  if [[ "$REPLY" =~ ^(y|yes)$ ]]; then
    SYNAPTICS="yes"
  fi

  save_string "SYNAPTICS" "$SYNAPTICS"
  echo -e "Synaptics is set to \"$SYNAPTICS\"\n"
}

what_hardware () {
  echo "Started resolving system hardware..."

  is_uefi

  local VIRTUAL_VENDOR=$(systemd-detect-virt)

  if [ "$VIRTUAL_VENDOR" != "none" ]; then
    save_string "VIRTUAL" "yes"
    save_string "VIRTUAL_VENDOR" "$VIRTUAL_VENDOR"

    echo "Virtual is set to \"yes\""
    echo "Virtual vendor set to \"$VIRTUAL_VENDOR\""
  else
    save_string "VIRTUAL" "no"
    echo "Virtual is set to \"no\""

    what_cpu
    what_gpu
    want_synaptics
  fi

  echo -e "Hardware has been resolved successfully\n"
}

which_disk () {
  lsblk -dA -o NAME,SIZE,FSUSE%,FSTYPE,TYPE,MOUNTPOINTS,LABEL

  local DEVICE=""
  read -rep "Enter the installation disk: " DEVICE
  DEVICE="/dev/$DEVICE"

  while [ ! -b "$DEVICE" ]; do
    read -rep " Please enter a valid disk block device: " DEVICE
    DEVICE="/dev/$DEVICE"
  done

  echo -e "\nCAUTION, all data in \"$DEVICE\" will be lost"

  local REPLY=""
  read -rep "Proceed and use it as installation disk? [y/N] " REPLY
  REPLY="${REPLY:-"no"}"
  REPLY="${REPLY,,}"

  while [[ ! "$REPLY" =~ ^(y|yes)$ ]]; do
    read -rep "Enter another disk block device: " DEVICE
    DEVICE="/dev/$DEVICE"

    while [ ! -b "$DEVICE" ]; do
      read -rep " Please enter a valid disk block device: " DEVICE
      DEVICE="/dev/$DEVICE"
    done

    echo -e "\nCAUTION, all data in \"$DEVICE\" will be lost"
    read -rep "Proceed and use it as installation disk? [y/N] " REPLY
    REPLY="${REPLY:-"no"}"
    REPLY="${REPLY,,}"
  done

  save_string "DISK" "$DEVICE"

  read -rep "Is this disk an SSD drive? [Y/n] " REPLY
  REPLY="${REPLY:-"yes"}"
  REPLY="${REPLY,,}"

  if [[ "$REPLY" =~ ^(y|yes)$ ]]; then
    save_string "DISK_SSD" "yes"
  else
    save_string "DISK_SSD" "no"
  fi

  local DISCARDS=($(lsblk -dn --discard -o DISC-GRAN,DISC-MAX $DEVICE))

  if [[ "$DISCARDS[1]" =~ [1-9]+[TGMB] && "$DISCARDS[2]" =~ [1-9]+[TGMB] ]]; then
    read -rep "Do you want to enable trim on this disk? [Y/n] " REPLY
    REPLY="${REPLY:-"yes"}"
    REPLY="${REPLY,,}"

    if [[ "$REPLY" =~ ^(y|yes)$ ]]; then
      save_string "DISK_TRIM" "yes"
    else
      save_string "DISK_TRIM" "no"
    fi
  else
    save_string "DISK_TRIM" "no"
  fi

  echo -e "Installation disk is set to block device \"$DEVICE\"\n"
}

want_swap () {
  local REPLY=""
  read -rep "Do you want to enable swap? [Y/n] " REPLY
  REPLY="${REPLY:-"yes"}"
  REPLY="${REPLY,,}"

  if [[ ! "$REPLY" =~ ^(y|yes)$ ]]; then
    save_string "SWAP" "no"
    echo -e "Swap is set to \"no\"\n"
    return 0
  else
    save_string "SWAP" "yes"
  fi

  local SWAP_SIZE=""
  read -rep "Enter the size of the swap in GBytes: " SWAP_SIZE

  while [[ ! "$SWAP_SIZE" =~ ^[1-9][0-9]{,2}$ ]]; do
    read -rep " Please enter a valid swap size in GBytes: " SWAP_SIZE
  done

  local SWAP_TYPE=""
  read -rep "Enter the swap type: [FILE/partition] " SWAP_TYPE
  SWAP_TYPE="${SWAP_TYPE:-"file"}"
  SWAP_TYPE="${SWAP_TYPE,,}"

  while [[ ! "$SWAP_TYPE" =~ ^(file|partition)$ ]]; do
    read -rep " Enter a valid swap type: " SWAP_TYPE
    SWAP_TYPE="${SWAP_TYPE,,}"
  done

  save_string "SWAP_SIZE" "$SWAP_SIZE"
  save_string "SWAP_TYPE" "$SWAP_TYPE"

  echo "Swap is set to \"$SWAP_TYPE\""
  echo -e "Swap size is set to \"${SWAP_SIZE}GB\"\n"
}

which_mirrors () {
  local OLD_IFS=$IFS
  IFS=","

  reflector --list-countries > "$HOME/.mirrors" || exit 1

  local COUNTRIES=($(
    cat "$HOME/.mirrors" |
      tail -n +3 |
      awk '{split($0,a,/[A-Z]{2}/); print a[1]}' |
      trim |
      awk '{print $0","}' |
      no_breaks
  ))

  IFS=$OLD_IFS

  print 4 25 "${COUNTRIES[@]}"

  local COUNTRY=""
  read -rep "Enter the primary mirror country: [Greece] " COUNTRY
  COUNTRY="${COUNTRY:-"Greece"}"

  while ! contains "$COUNTRY" "${COUNTRIES[@]}"; do
    read -rep " Please enter a valid country: " COUNTRY
  done

  local MIRROR_SET="\"$COUNTRY\""

  while true; do
    read -rep "Enter another secondary mirror country (none to skip): " COUNTRY

    [ -z "$COUNTRY" ] && break

    while ! contains "$COUNTRY" "${COUNTRIES[@]}"; do
      read -rep " Please enter a valid country: " COUNTRY
    done

    [[ ! "$MIRROR_SET" =~ $COUNTRY ]] && MIRROR_SET="$MIRROR_SET \"$COUNTRY\""
  done

  save_array "MIRRORS" "$MIRROR_SET"
  echo -e "Mirror countries are set to [$MIRROR_SET]\n"
}

which_timezone () {
  local CONTINENTS=(
    "Africa" "America" "Antarctica" "Arctic" "Asia"
    "Atlantic" "Australia" "Europe" "Indian" "Pacific"
  )

  print 4 15 "${CONTINENTS[@]}"

  local CONTINENT=""
  read -rep "Select your continent: [Europe] " CONTINENT
  CONTINENT="${CONTINENT:-"Europe"}"

  while ! contains "$CONTINENT" "${CONTINENTS[@]}"; do
    read -rep " Please enter a valid continent: " CONTINENT
  done

  ls -1 -pU "/usr/share/zoneinfo/$CONTINENT" > "$HOME/.cities" || exit 1

  local CITIES=($(cat "$HOME/.cities" | grep -v /))

  echo && print 4 20 "${CITIES[@]}"

  local CITY=""
  read -rep "Enter the city closer to your timezone? " CITY

  while [ ! -f "/usr/share/zoneinfo/$CONTINENT/$CITY" ]; do
    read -rep " Please enter a valid timezone city: " CITY
  done

  local TIMEZONE="$CONTINENT/$CITY"

  save_string "TIMEZONE" "$TIMEZONE"
  echo -e "Current timezone is set to \"$TIMEZONE\"\n"
}

which_keymap () {
  local OLD_IFS=$IFS
  IFS=","

  local EXTRA="apple|mac|window|sun|atari|amiga|ttwin|ruwin"
  EXTRA="$EXTRA|wangbe|adnw|applkey|backspace|bashkir|bone"
  EXTRA="$EXTRA|carpalx|croat|colemak|ctrl|defkeymap|euro|keypad|koy"

  localectl --no-pager list-keymaps > "$HOME/.keymaps" || exit 1

  local MAPS=($(
    cat "$HOME/.keymaps" |
      trim |
      awk '{print $0","}' |
      sed -n -E "/$EXTRA/!p"
  ))

  local EXTRA=($(
    cat "$HOME/.keymaps" |
      trim |
      awk '{print $0","}' |
      sed -n -E "/$EXTRA/p"
  ))

  IFS=$OLD_IFS

  print 4 25 "${MAPS[@]}"

  local KEYMAP=""
  read -rep "Enter your keyboard's keymap (extra for more): [us] " KEYMAP
  KEYMAP="${KEYMAP:-"us"}"

  if [ "$KEYMAP" = "extra" ]; then
    echo && print 4 30 "${EXTRA[@]}"

    read -rep "Enter your keyboard's keymap: " KEYMAP
  fi

  while [ -z "$(find /usr/share/kbd/keymaps/ -type f -name "$KEYMAP.map.gz")" ]; do
    read -rep " Please enter a valid keyboard map: " KEYMAP
  done

  save_string "KEYMAP" "$KEYMAP"
  echo -e "Keyboard keymap is set to \"$KEYMAP\"\n"
}

which_layouts () {
  local LAYOUTS=(
    af al am ara at au az ba bd be bg br brai bt bw by ca cd ch cm cn cz
    de dk dz ee epo es et fi fo fr gb ge gh gn gr hr hu id ie il in iq ir
    is it jp ke kg kh kr kz la latam lk lt lv ma mao md me mk ml mm mn mt
    mv my ng nl no np ph pk pl pt ro rs ru se si sk sn sy tg th tj tm tr
    tw tz ua us uz vnza
  )

  print 8 6 "${LAYOUTS[@]}"

  local LAYOUT=""
  read -rep "Enter your primary keyboard layout: [us] " LAYOUT
  LAYOUT="${LAYOUT:-"us"}"

  while ! contains "$LAYOUT" "${LAYOUTS[@]}"; do
    read -rep " Please enter a valid layout: " LAYOUT
  done

  local LAYOUT_SET="\"$LAYOUT\""

  while true; do
    read -rep "Enter another secondary layout (none to skip): " LAYOUT

    [ -z "$LAYOUT" ] && break

    while ! contains "$LAYOUT" "${LAYOUTS[@]}"; do
      read -rep " Please enter a valid layout: " LAYOUT
    done

    [[ ! "$LAYOUT_SET" =~ $LAYOUT ]] && LAYOUT_SET="$LAYOUT_SET \"$LAYOUT\""
  done

  save_array "LAYOUTS" "$LAYOUT_SET"
  echo -e "Keyboard layouts are set to [$LAYOUT_SET]\n"
}

which_locale () {
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

  IFS=$OLD_IFS

  LANGS=($(remove_dups "${LANGS[@]}"))

  print 8 10 "${LANGS[@]}"

  local LANG=""
  read -rep "Enter the language of your locale: [en] " LANG
  LANG="${LANG:-"en"}"

  while ! contains "$LANG" "${LANGS[@]}"; do
    read -rep " Please enter a valid language: " LANG
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

  IFS=$OLD_IFS

  echo && print 5 20 "${LOCALES[@]}"

  local LOCALE=""
  read -rep "Enter your locale: " LOCALE

  while ! contains "$LOCALE" "${LOCALES[@]}"; do
    read -rep " Please enter a valid locale: " LOCALE
  done

  save_string "LOCALE" "$LOCALE"
  echo -e "Locale is set to \"$LOCALE\"\n"
}

what_hostname () {
  local HOSTNAME=""
  local RE="^[a-z][a-z0-9_-]+$"

  read -rep "Enter a name for your host: [arch] " HOSTNAME
  HOSTNAME="${HOSTNAME:-"arch"}"

  if [[ ! "$HOSTNAME" =~ $RE ]]; then
    echo " Hostname should be at least 2 chars of [a-z0-9_-]"
    echo " First char must always be a latin letter"
  fi

  while [[ ! "$HOSTNAME" =~ $RE ]]; do
    read -rep " Please enter a valid hostname: " HOSTNAME
  done

  save_string "HOSTNAME" "$HOSTNAME"
  echo -e "Hostname is set to \"$HOSTNAME\"\n"
}

what_username () {
  local USERNAME=""
  local RE="^[a-z][a-z0-9_-]+$"

  read -rep "Enter a username for your user: [bob] " USERNAME
  USERNAME="${USERNAME:-"bob"}"

  if [[ ! "$USERNAME" =~ $RE ]]; then
    echo " Username should be at least 2 chars of [a-z0-9_-]"
    echo " First char must always be a latin letter"
  fi

  while [[ ! "$USERNAME" =~ $RE ]]; do
    read -rep " Please enter a valid username: " USERNAME
  done

  save_string "USERNAME" "$USERNAME"
  echo -e "Username is set to \"$USERNAME\"\n"
}

what_password () {
  local SUBJECT=$1
  local RE="^[a-zA-Z0-9@&!#%\$_-]{4,}$"
  local MESSAGE="Password must be at least 4 chars of a-z A-Z 0-9 @&!#%\$_-"

  echo "Setting password for the ${SUBJECT,,}"
  echo "$MESSAGE"

  local PASSWORD=""
  read -rsp "Enter a new password: " PASSWORD && echo

  while [[ ! "$PASSWORD" =~ $RE ]]; do
    read -rsp " Please enter a valid password: " PASSWORD && echo
  done

  local COMFIRMED=""
  read -rsp "Re-enter the password: " COMFIRMED && echo

  # Repeat until password comfirmed 
  while [ "$PASSWORD" != "$COMFIRMED" ]; do
    echo " Ooops, passwords do not match"
    read -rsp "Please enter a new password: " PASSWORD && echo

    while [[ ! "$PASSWORD" =~ $RE ]]; do
      read -rsp " Please enter a valid password: " PASSWORD && echo
    done

    read -rsp "Re-enter the password: " COMFIRMED && echo
  done

  save_string "${SUBJECT}_PASSWORD" "$PASSWORD"
  echo -e "Password for the ${SUBJECT,,} is set successfully\n"
}

which_kernels () {
  local KERNELS=""
  read -rep "Which linux kernels to install: [STABLE/lts/all] " KERNELS
  KERNELS="${KERNELS:-"stable"}"
  KERNELS="${KERNELS,,}"

  while [[ ! "$KERNELS" =~ ^(stable|lts|all)$ ]]; do
    read -rep " Please enter a valid kernel option: " KERNELS
    KERNELS="${KERNELS,,}"
  done

  if [ "$KERNELS" = "all" ]; then
    KERNELS="\"stable\" \"lts\""
  else
    KERNELS="\"$KERNELS\""
  fi

  save_array "KERNELS" "$KERNELS"
  echo -e "Linux kernels are set to [$KERNELS]\n"
}

opt_in () {
  local APPS_CATEGORY=${1^^} && shift
  local APPS=("${@}")

  print 1 15 "${APPS[@]}"

  local REPLY=""
  read -rep "Which ${APPS_CATEGORY,,} you want to install? [All/none] " REPLY
  REPLY="${REPLY:-"all"}"
  REPLY="${REPLY,,}"

  if [[ "$REPLY" =~ ^all$ ]]; then
    local ALL=$(trim "$(printf " \"%s\"" "${APPS[@]}")")

    save_array "$APPS_CATEGORY" "$ALL"
    echo "You opted in for $ALL"
  elif [[ "$REPLY" =~ ^none$ ]]; then
    save_array "$APPS_CATEGORY" ""

    echo "You opted out ${APPS_CATEGORY,,}"
  else
    local REPLIES=($REPLY)
    local APPS_SET=""

    for APP in "${REPLIES[@]}"; do
      while ! contains "$APP" "${APPS[@]}"; do
        read -rep " Unknown $APP application, enter a valid name: " APP
        APP="${APP,,}"
      done

      [[ ! "$APPS_SET" =~ "$APP" ]] && APPS_SET="$APPS_SET \"$APP\""
    done

    APPS_SET=$(trim "$APPS_SET")

    save_array "$APPS_CATEGORY" "$APPS_SET"
    echo "You opted in for $APPS_SET"
  fi

  echo
}

while true; do
  init_options &&
    what_hardware &&
    which_disk &&
    want_swap &&
    which_mirrors &&
    which_timezone &&
    which_keymap &&
    which_layouts &&
    which_locale &&
    what_hostname &&
    what_username &&
    what_password "USER" &&
    what_password "ROOT" &&
    which_kernels &&
    opt_in "editors" "code" "atom" "sublime" "neovim" &&
    opt_in "browsers" "firefox" "chrome" "brave" "tor" &&
    opt_in "office" "libreoffice" "xournal" "foliate" "evince"

  echo "Configuration options have been set to:"
  cat "$OPTIONS" | awk '!/PASSWORD/ {print " "$0}'

  echo -e "\nCAUTION, THIS IS THE LAST WARNING!"
  echo "ALL data in the disk will be LOST FOREVER!"
  read -rep "Do you want to re-run configuration? [y/N] " REPLY
  REPLY="${REPLY:-"no"}"
  REPLY="${REPLY,,}"

  [[ ! "$REPLY" =~ ^(y|yes)$ ]] && break || clear
done

echo "Moving to the next process..."
sleep 5
