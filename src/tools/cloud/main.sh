#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/commons/input.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/validators.sh
source /opt/stack/tools/cloud/commands.sh

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: cloud [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-10s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
  
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-48s %s\n' \
      'help' 'Show this help message.'
  fi

  printf ' %-48s %s\n' \
    'list remotes <service>' 'List all synced remotes by service name.' \
    '' '' \
    'sync drive <name> <client> <secret> <folder>' 'Sync a google drive remote service.' \
    'sync dropbox <name> <app> <secret>' 'Sync a dropbox remote service.' \
    'delete remote <name>' 'Delete a synced remote service.' \
    '' '' \
    'mount remote <name>' 'Mount a synced remote.' \
    'unmount remote <name>' 'Unmount a mounted remote.' \
    'mount remotes' 'Mount all synced remotes.'
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
    'list remotes') list_remotes "${3}";;
    'sync drive') sync_drive "${3}" "${4}" "${5}" "${6}";;
    'sync dropbox') sync_dropbox "${3}" "${4}" "${5}";;
    'delete remote') delete_remote "${3}";;
    'mount remote') mount_remote "${3}";;
    'unmount remote') unmount_remote "${3}";;
    'mount remotes') mount_all;;
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
        set_quiet_mode 'on'
        show_help once
        return 0;;
     'q') set_quiet_mode 'on';;
     's') ON_SCRIPT_MODE='true';;
     *)
      log "Ooops, invalid or unknown option -${OPTARG}!"
      beep 2
      return $?;;
    esac
  done

  # Collect command arguments
  shift $((OPTIND-1))
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
      prompt audio

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

run "$@"

