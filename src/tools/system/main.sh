#!/bin/bash

set -o pipefail

source src/commons/process.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/system/commands.sh

LOGS='/var/log/stack/tools/system.log'

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: system [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-6s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
  
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-42s %s\n' \
      'help' 'Show this help message.'
  fi

  printf ' %-42s %s\n' \
    'show status' 'Show the system overall status.' \
    '' '' \
    'set mirrors <age> <latest> <countries>' 'Set the mirrors of package databases.' \
    'list packages pacman|aur' 'Show the list of installed packages.' \
    '' '' \
    'check updates' 'Check for available updates.' \
    'list updates' 'Show the list of available updates.' \
    'apply updates' 'Apply any available updates.' \
    '' '' \
    'upgrade stack' 'Upgrade the stack tools and modules.'
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
    'set mirrors') set_mirrors "${3}" "${4}" "${@:5}";;
    'list packages') list_packages "${3}";;
    'check updates')
      flock -x ${UPDATES_FILE} \
        -c "source /opt/stack/tools/system/commands.sh; ON_SCRIPT_MODE=${ON_SCRIPT_MODE} check_updates";;
    'list updates')
      flock -s ${UPDATES_FILE} \
        -c "source /opt/stack/tools/system/commands.sh; list_updates";;
    'apply updates')
      flock -x ${UPDATES_FILE} \
        -c "source /opt/stack/tools/system/commands.sh; ON_SCRIPT_MODE=${ON_SCRIPT_MODE} apply_updates";;
    'upgrade stack')
      flock -x ${UPDATES_FILE} \
        -c "source /opt/stack/tools/system/commands.sh; upgrade_stack";;
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
      prompt system

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
