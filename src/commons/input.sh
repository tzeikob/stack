#!/bin/bash

source src/commons/error.sh
source src/commons/math.sh
source src/commons/validators.sh

AES=$'╬'
AES_LN=$'╬\n'
KVS=$'▒'

CLR=$'\u001b[33m'
RST=$'\u001b[0m'

# Shows a prompt asking the user to enter the
# next command, which is kept in the global var REPLY.
# Arguments:
#  label: the label of the prompt
# Outputs:
#  A minimal prompt line.
prompt () {
  local label="${1:-"prompt"}"

  label="${CLR}${label}>> ${RST}"

  REPLY=''

  read -rep "${label}" REPLY 2>&1
  
  if has_failed; then
    return 1
  fi

  history -s "${REPLY}"
}

# Asks the user to enter a value, where the answer is
# kept in the global var REPLY.
# Options:
#  n: print an empty line before, -nn 2 lines and so on
# Arguments:
#  prompt: a text line
# Outputs:
#  A prompt text line.
ask () {
  # Trap ctrl-c abort signals for read cmd
  trap "echo; return 1" SIGINT INT

  local OPTIND opt

  while getopts ':n' opt; do
    case "${opt}" in
     'n') printf '\n';;
    esac
  done

  # Collect arguments
  shift $((OPTIND - 1))

  local prompt="${CLR}${1}${RST}"

  REPLY=''

  echo "${prompt}"
  read -re REPLY 2>&1

  # Print a blank line after user input
  if is_given "${REPLY}"; then
    echo
  fi

  return 0
}

# Asks the user to enter a secret value, the answer is
# kept in the global var REPLY.
# Options:
#  n: print an empty line before, -nn 2 lines and so on
# Arguments:
#  prompt: a text line
# Outputs:
#  A prompt text line.
ask_secret () {
  # Trap ctrl-c abort signals for read cmd
  trap "echo; return 1" SIGINT INT
  
  local OPTIND opt

  while getopts ':n' opt; do
    case "${opt}" in
     'n') printf '\n';;
    esac
  done

  # Collect arguments
  shift $((OPTIND - 1))

  local prompt="${CLR}${1}${RST}"

  REPLY=''

  echo "${prompt}"

  local char=''
  while IFS= read -rs -n1 char; do
    if [[ ${char} == $'\0' ]]; then
      break
    elif [[ ${char} == $'\177' || ${char} == $'\b' ]]; then
      if [ ${#REPLY} -gt 0 ]; then
        REPLY="${REPLY%?}"
        printf '\b \b'
      fi
    else
      REPLY+="${char}"
      printf '*'
    fi
  done

  # Print a blank line after user input
  if is_given "${REPLY}"; then
    printf '\n\n'
  else
    printf '\n'
  fi
}

# Shows a Yes/No menu and asks user to select an option,
# where the selection is kept in the global var REPLY
# either as a yes or no value.
# Options:
#  n: print an empty line before, -nn 2 lines and so on
# Arguments:
#  prompt: a text line
# Outputs:
#  A menu of yes or no options.
confirm () {
  local OPTIND opt

  while getopts ':n' opt; do
    case "${opt}" in
     'n') printf '\n';;
    esac
  done

  # Collect arguments
  shift $((OPTIND - 1))

  local prompt="${1}"

  REPLY=''
  
  local options="no${KVS}No${AES}yes${KVS}Yes"

  echo -e "${CLR}${prompt}${RST}"

  REPLY="$(echo "${options}" |
    LC_CTYPE=C.UTF-8 smenu -nm -/ prefix -W "${AES_LN}" -S /\(.*"${KVS}"\)//v)" || return 1
  
  # Print a blank line after user input
  echo

  # Remove the value part from the selected option
  if is_given "${REPLY}"; then
    REPLY="$(echo "${REPLY}" | sed -r "s/(.*)${KVS}.*/\1/")" || return 1
  fi
}

# Shows a menu and asks user to pick one option, where
# the selection is kept in the global var REPLY as a
# value equal to the key property of the selected option.
# Options:
#  n: print an empty line before, -nn 2 lines and so on
# Arguments:
#  prompt:  a text line
#  options: a json array of {key, value} pairs
#  mode:    horizontal, vertical, tabular
#  slots:   number of vertical or tabular slots
# Outputs:
#  A menu of the given options.
pick_one () {
  local OPTIND opt

  while getopts ':n' opt; do
    case "${opt}" in
     'n') printf '\n';;
    esac
  done

  # Collect arguments
  shift $((OPTIND - 1))

  local prompt="${1}"
  local options="${2}"
  local mode="${3}"
  local slots="${4:-6}"

  REPLY=''

  local len=0
  len="$(echo "${options}" | jq -cer 'length')" || return 1
  
  if is_true "${len} = 0"; then
    return 1
  fi

  local args=()
  if equals "${mode}" 'vertical'; then
    args+=(-l -L "${AES}" -n "${slots}")
  elif equals "${mode}" 'tabular'; then
    args+=(-t "${slots}")
  fi

  # Convert options to a line of key${KVS}value${AES} pairs
  options="$(echo "${options}" |
    jq -cer '[.[]|("\(.key)'"${KVS}"'\(.value)")]|join("'"${AES}"'")')" || return 1

  echo -e "${CLR}${prompt}${RST}"

  REPLY="$(echo "${options}" |
    LC_CTYPE=C.UTF-8 smenu -nm -/ prefix -W "${AES_LN}" "${args[@]}" -S /\(.*"${KVS}"\)//v)" || return 1
  
  # Print a blank line after user input
  echo

  # Remove the value part from the selected option
  if is_given "${REPLY}"; then
    REPLY="$(echo "${REPLY}" | sed -r "s/(.*)${KVS}.*/\1/")" || return 1
  fi
}

# Shows a menu and asks user to pick many options in order,
# where the selection is kept in the global var REPLY as a
# json array with elements equal to the key property of every
# selected option.
# Options:
#  n: print an empty line before, -nn 2 lines and so on
# Arguments:
#  prompt:  a text line
#  options: a json array of {key, value} pairs
#  mode:    horizontal, vertical, tabular
#  slots:   number of vertical or tabular slots
# Outputs:
#  A menu of the given options.
pick_many () {
  local OPTIND opt

  while getopts ':n' opt; do
    case "${opt}" in
     'n') printf '\n';;
    esac
  done

  # Collect arguments
  shift $((OPTIND - 1))

  local prompt="${1}"
  local options="${2}"
  local mode="${3}"
  local slots="${4:-6}"

  REPLY=''

  local len=0
  len="$(echo "${options}" | jq -cer 'length')" || return 1
  
  if is_true "${len} = 0"; then
    return 1
  fi

  local args=()
  if equals "${mode}" 'vertical'; then
    args+=(-l -L "${AES}" -n "${slots}")
  elif equals "${mode}" 'tabular'; then
    args+=(-t "${slots}")
  fi

  # Convert options to a line of key${KVS}value${AES} pairs
  options="$(echo "${options}" |
    jq -cer '[.[]|("\(.key)'"${KVS}"'\(.value)")]|join("'"${AES}"'")')" || return 1

  echo -e "${CLR}${prompt}${RST}"

  REPLY="$(echo "${options}" |
    LC_CTYPE=C.UTF-8 smenu -nm -/ prefix -W "${AES_LN}" "${args[@]}" -S /\(.*"${KVS}"\)//v -P "${AES}")" || return 1
  
  # Print a blank line after user input
  echo

  # Convert selected options to a json array of their keys
  if is_given "${REPLY}"; then
    REPLY="$(echo "${REPLY}" | awk -F"${AES}" '{
      out=""
      for (i=1;i<=NF;i++) {
        gsub(/('"${KVS}"'.*$)/, "", $i);
        out=out "\""$i"\","
      }
      print out
    }')" || return 1

    # Remove last post fixed comma
    if match "${REPLY}" ',$'; then
      REPLY="[${REPLY::-1}]"
    fi
  fi
}
