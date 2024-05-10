#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/commons/input.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/validators.sh
source /opt/stack/tools/printers/commands.sh

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: printers [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-8s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
  
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-36s %s\n' \
      'help' 'Show this help message.' \
      '' ''
  fi

  printf ' %-36s %s\n' \
    'show status' 'Show a report of cups service and printers.' \
    'show printer <name>' 'Show the data of a printer.' \
    '' '' \
    'list printers' 'List all printers.' \
    'add printer <uri> <name> <driver>' 'Add a new printer.' \
    'remove printer <name>' 'Remove a printer.' \
    '' '' \
    'set default <name>' 'Set a printer as default destination.' \
    'set option <name> <key> <value>' 'Set the option of a printer with key equal' \
    '' 'to Quality, PageSize, MediaType, ToneSaveMode' \
    '' 'or printer-error-policy.' \
    '' '' \
    'share printer <name>' 'Share a printer to the local network.' \
    'unshare printer <name>' 'Unshare a printer of the local network.' \
    '' '' \
    'list jobs' 'List all queued print jobs.' \
    'cancel job <id>' 'Cancel a queued print job.' \
    '' '' \
    'restart' 'Restart the cups service.'
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
    'show printer') show_printer "${3}";;
    'list printers') list_printers;;
    'list jobs') list_jobs;;
    'add printer') add_printer "${3}" "${4}" "${5}";;
    'remove printer') remove_printer "${3}";;
    'share printer') share_printer "${3}";;
    'unshare printer') unshare_printer "${3}";;
    'set default') set_default "${3}";;
    'set option') set_option "${3}" "${4}" "${5}";;
    'cancel job') cancel_job "${3}";;
    'restart') restart;;
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
     's') set_script_mode 'on';;
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
      prompt printers

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

