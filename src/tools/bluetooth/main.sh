#!/bin/bash

set -o pipefail

source src/commons/process.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/bluetooth/commands.sh

LOGS='/var/log/stack/bluetooth.log'

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: bluetooth [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-8s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'

    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-30s %s\n' \
      'help' 'Show this help message.' \
      '' ''
  fi

  printf ' %-30s %s\n' \
    'show status' 'Show a report of the bluetooth service.' \
    '' '' \
    'show controller <address>' 'Show the data of a controller.' \
    'show device <address>' 'Show the data of a device.' \
    '' '' \
    'list controllers' 'List the available controllers.' \
    'list devices <status>' 'List all devices or only those having status' \
    '' 'paired, connected, trusted or bonded.' \
    '' '' \
    'set controller <address>' 'Set the default controller.' \
    'set power on|off' 'Set the default controller power to on or off.' \
    'set scan on|off' 'Set the default controller scan mode to on or off.' \
    'set discoverable on|off' 'Set the default controller to be discoverable.' \
    'set pairable on|off' 'Set the default controller to be pairable.' \
    '' '' \
    'connect device <address>' 'Connect a bluetooth device.' \
    'disconnect device <address>' 'Disconnect a bluetooth device.' \
    'remove device <address>' 'Removes a bluetooth device.' \
    '' '' \
    'restart' 'Restart the bluetooth service.'
}

# Routes to the corresponding operation by matching
# the given command and object along with the list
# of arguments.
# Arguments:
#   command: the command to execute
#   object:  the object the command should operate on
#   args:    a list of arguments
execute () {
  local command="${1}"
  local object="${2}"
  
  case "${command}${object:+ ${object}}" in
    'show status') show_status;;
    'show controller') show_controller "${3}";;
    'show device') show_device "${3}";;
    'list controllers') list_controllers;;
    'list devices') list_devices "${3}";;
    'set controller') set_controller "${3}";;
    'set power') set_power "${3}";;
    'set scan') set_scan "${3}";;
    'set discoverable') set_discoverable "${3}";;
    'set pairable') set_pairable "${3}";;
    'connect device') connect_device "${3}";;
    'disconnect device') disconnect_device "${3}";;
    'remove device') remove_device "${3}";;
    'restart') restart_bluetooth;;
    *)
      log 'Ooops, invalid or unknown command!'
      return 2;;
  esac
}

run () {
  local opt=''

  while getopts ':hqs' opt; do
    case "${opt}" in
     'h')
        ON_QUIET_MODE='true'
        show_help once
        return 0;;
     'q') ON_QUIET_MODE='true';;
     's') ON_SCRIPT_MODE='true';;
     *)
      log "Ooops, invalid or unknown option -${OPTARG}!"
      beep 2
      return $?;;
    esac
  done

  # Collect command arguments
  shift $(calc "${OPTIND} - 1")
  local args_len=$#

  if is_true "${args_len} = 0" && on_script_mode; then
    log 'Option -s cannot be used in loop mode.'
    beep 2
    return $?
  fi

  local mode='once'
  if is_true "${args_len} = 0"; then
    mode='loop'
    clear
  fi

  while true; do
    if equals "${mode}" 'loop'; then
      prompt bluetooth

      local command=''
      command="$(echo "${REPLY}" | awk '{print (NF == 1) ? $1 : $0}')"

      case "${command}" in
        'help') clear && show_help && continue;;
        'clear') clear && continue;;
        'quit') break;;
        '') continue;;
      esac
      
      eval "execute ${REPLY[@]}"
    else
      execute "$@"
    fi

    # Save exit status code of the last executed operation
    local exit_code=$?
  
    if is_true "${exit_code} = 1"; then
      log 'Ooops, an unknwon error occurred!'
    fi

    on_loud_mode && beep "${exit_code}"

    if equals "${mode}" 'once'; then
      return ${exit_code}
    fi
  done

  clear
}

run "$@" 2>> "${LOGS}"
