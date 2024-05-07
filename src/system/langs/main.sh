#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/system/langs/commands.sh

# Shows the help message.
# Arguments:
#  mode: loop or once
# Outputs:
#  A long help message.
show_help () {
  local mode="${1}"

  if equals "${mode}" 'once'; then
    printf 'Usage: langs [OPTIONS] COMMAND [OBJECT] [ARGUMENTS]...\n'
    
    printf '\nOPTIONS\n'
    printf ' %-10s %s\n' \
      '-h' 'Show this help message.' \
      '-q' 'Do not play beep sounds.' \
      '-s' 'Run on script mode.'
  
    printf '\nCOMMANDS\n'
  else
    printf 'Usage: COMMAND [OBJECT] [ARGUMENTS]...\n'

    printf '\nCOMMANDS\n'
    printf ' %-39s %s\n' \
      'help' 'Show this help message.'
  fi

  printf ' %-39s %s\n' \
    'show status' 'Show the system locale and keyboard status.' \
    '' '' \
    'add locale <name>' 'Add a locale to the system locales.' \
    'remove locale <name>' 'Remove a locale from the system locales.' \
    'set locale <name>' 'Set the locale of the system.' \
    '' '' \
    'add layout <code> <variant> <alias>' 'Add a keyboard layout.' \
    'remove layout <code> <variant>' 'Remove a keyboard layout.' \
    'name layout <code> <variant> <alias>' 'Give an alias display name to a layout.' \
    'order layouts <code:variant>...' 'Set the order of keyboard layouts.' \
    '' '' \
    'set keymap <map>' 'Set the keyboard virtual console keymap.' \
    'set options <value>' 'Set a keyboard layout options.' \
    'set model <name>' 'Set the model of the keyboard.'
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
    'add locale') add_locale "${3}";;
    'remove locale') remove_locale "${3}";;
    'set locale') set_locale "${3}";;
    'add layout') add_layout "${3}" "${4}" "${5}";;
    'remove layout') remove_layout "${3}" "${4}";;
    'name layout') name_layout "${3}" "${4}" "${5}";;
    'order layouts') order_layouts "${@:3}";;
    'set keymap') set_keymap "${3}";;
    'set options') set_options "${3}";;
    'set model') set_model "${3}";;
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
      prompt langs

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

