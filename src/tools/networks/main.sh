#!/bin/bash

set -o pipefail

source src/commons/process.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/networks/commands.sh

LOGS='/var/log/stack/tools/networks.log'

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: networks [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-6s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
  
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-67s %s\n' \
      'help' 'Show this help message.' \
      '' ''
  fi

  printf ' %-67s %s\n' \
    'show status' 'Show the current status of networking.' \
    'show device <name>' 'Show the data of a device.' \
    'show connection <name>' 'Show the data of a connection.' \
    '' '' \
    'list devices' 'List the network devices.' \
    'list connections' 'List the network connections.' \
    'list wifis <device> <signal>' 'Detect wifi networks with a min signal.' \
    '' '' \
    'up device <name>' 'Enable a network device.' \
    'down device <name>' 'Disable a network device.' \
    'remove device <name>' 'Remove a software network device.' \
    '' '' \
    'up hotspot <broacaster> <provider>' 'Start up a hotspot for wifi connections.' \
    'down hotspot' 'Shut hotspot broacaster down.' \
    '' '' \
    'add ethernet <device> <name> <ip> <gate> <dns>' 'Add a static ethernet connection.' \
    'add dhcp <device> <name>' 'Add a dhcp ethernet connection.' \
    'add wifi <device> <ssid> <secret>' 'Add a wifi connection.' \
    'add vpn <ovpn-file> <username> <password>' 'Add a vpn connection.' \
    'up connection <name>' 'Enable a connection.' \
    'down connection <name>' 'Disable a connection.' \
    'remove connection <name>' 'Remove a connection.' \
    '' '' \
    'add proxy <name> <host> <port> <username> <password> <no-proxy>' 'Add a new proxy server profile.' \
    'remove proxy <name>' 'Remove a proxy server profile.' \
    'list proxies' 'List all proxy server profiles.' \
    'set proxy <name>' 'Applies proxy server settings.' \
    'unset proxy' 'Disables any proxy server settings.' \
    '' '' \
    'power network on|off' 'Set the system network to on or off.' \
    'power wifi on|off' 'Set the wifi device to on or off.'
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
    'show device') show_device "${3}";;
    'show connection') show_connection "${3}";;
    'list devices') list_devices;;
    'list connections') list_connections;;
    'list wifis') list_wifis "${3}" "${4}";;
    'list proxies') list_proxies;;
    'power network') power_network "${3}";;
    'power wifi') power_wifi "${3}";;
    'up device') up_device "${3}";;
    'down device') down_device "${3}";;
    'up connection') up_connection "${3}";;
    'down connection') down_connection "${3}";;
    'add ethernet') add_ethernet "${3}" "${4}" "${5}" "${6}" "${7}";;
    'add dhcp') add_dhcp "${3}" "${4}";;
    'add wifi') add_wifi "${3}" "${4}" "${5}";;
    'add vpn') add_vpn "${3}" "${4}" "${5}";;
    'add proxy') add_proxy "${3}" "${4}" "${5}" "${6}" "${7}" "${8}";;
    'remove device') remove_device "${3}";;
    'up hotspot') up_hotspot "${3}" "${4}";;
    'down hotspot') down_hotspot;;
    'remove connection') remove_connection "${3}";;
    'remove proxy') remove_proxy "${3}";;
    'set proxy') set_proxy "${3}";;
    'unset proxy') unset_proxy;;
    *)
      log 'Ooops, invalid or unknown command!'
      return 2;;
  esac
}

run () {
  local OPTIND='' opt=''

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
  shift $((OPTIND - 1))
  
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
      prompt networks

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
