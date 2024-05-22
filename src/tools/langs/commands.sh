#!/bin/bash

set -o pipefail

source /opt/stack/commons/process.sh
source /opt/stack/commons/input.sh
source /opt/stack/commons/auth.sh
source /opt/stack/commons/error.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/validators.sh
source /opt/stack/tools/langs/helpers.sh

# Shows the current status of languages and locales.
# Outputs:
#  A verbose list of text data.
show_status () {
  local current_layout=''
  current_layout="$(xkblayout-state print "%s:%v [%n]")" || return 1

  localectl status | awk -v layout="${current_layout}" '{
    label=""
    
    if ($0 ~ /^.* VC Keymap/) {
      label="Keymap"
    } else if ($0 ~ /^.* X11 Layout/) {
      printf "%-10s %s\n", "Layout", layout
      label="Layouts"
    } else if ($0 ~ /^.* X11 Variant/) {
      label="Variants"
    } else if ($0 ~ /^.* X11 Options/) {
      label="Options"
    } else if ($0 ~ /^.* X11 Model/) {
      label="Model"
    } else {
      next
    }

    printf "%-10s %s\n", label":", $3
  }' || return 1

  local locales=''
  locales="$(locale -a | awk '{ORS=", ";} {print $0}')" || return 1

  # Remove extra comma after the last locale element
  if is_not_empty "${locales}"; then
    locales="${locales::-2}"
  fi

  echo "Locales:   ${locales}"

  echo ''
  locale | awk -F'=' '{
    if ($2 == "") {
      next
    }

    gsub(/"/, "", $2)

    switch ($1) {
      case "LANG": $1="Lang"; break;
      case "LC_CTYPE": $1="Type"; break;
      case "LC_NUMERIC": $1="Numeric"; break;
      case "LC_TIME": $1="Time"; break;
      case "LC_COLLATE": $1="Collate"; break;
      case "LC_MONETARY": $1="Money"; break;
      case "LC_MESSAGES": $1="Message"; break;
      case "LC_PAPER": $1="Paper"; break;
      case "LC_NAME": $1="Name"; break;
      case "LC_ADDRESS": $1="Address"; break;
      case "LC_TELEPHONE": $1="Telephone"; break;
      case "LC_MEASUREMENT": $1="Measures"; break;
      case "LC_IDENTIFICATION": $1="Ids"; break;
      default: next;
    }
    
    printf "%-10s %s\n", $1":", $2
  }' || return 1
}

# Sets the keymap of the console keyboard to the
# given keymap.
# Arguments:
#  map: the name of a keyboard map
set_keymap () {
  authenticate_user || return $?

  local map="${1}"

  if is_not_given "${map}"; then
    on_script_mode &&
      log 'Missing the keyboard map.' && return 2

    pick_keymap || return $?
    is_empty "${REPLY}" && log 'Keyboard map is required.' && return 2
    map="${REPLY}"
  fi

  if is_not_keymap "${map}"; then
    log 'Invalid or unknown keyboard map.'
    return 2
  fi

  save_keymap_to_settings "${map}" &&
   apply_keyboard_settings
  
  if has_failed; then
    log "Failed to set keyboard map ${map}."
    return 2
  fi

  log "Keyboard map set to ${map}."
}

# Sets the language and all locale variables to
# the given locale.
# Arguments:
#  name: the name of a locale
set_locale () {
  authenticate_user || return $?

  local name="${1}"
  
  if is_not_given "${name}"; then
    on_script_mode &&
     log 'Missing the locale name.' && return 2

    pick_installed_locale || return $?
    is_empty "${REPLY}" && log 'Locale name is required.' && return 2
    name="${REPLY}"
  fi

  if is_not_locale "${name}"; then
    log 'Invalid or unknown locale.'
    return 2
  elif is_locale_not_installed "${name}"; then
    log "Locale ${name} is not installed."
    return 2
  fi

  # Keep only the first part of locale
  name="$(echo "${name}" | cut -d ' ' -f 1)"

  save_system_locale_to_settings "${name}" &&
    apply_system_locale_settings
  
  if has_failed; then
    log "Failed to set system locale."
    return 2
  fi

  log "System locale set to ${name}."
  log 'Please restart so changes take effect!'
}

# Sets a keyboard layout options.
# Arguments:
#  value: a layout options value
set_options () {
  authenticate_user || return $?

  local value="${1}"

  if is_not_given "${value}"; then
    on_script_mode &&
      log 'Missing the options value.' && return 2

    pick_options_value || return $?
    is_empty "${REPLY}" && log 'Options value is required.' && return 2
    value="${REPLY}"
  fi

  if is_not_layout_options "${value}"; then
    log 'Invalid or unknown options value.'
    return 2
  fi

  save_options_to_settings "${value}" &&
   apply_keyboard_settings
  
  if has_failed; then
    log 'Failed to set keyboard layout options.'
    return 2
  fi

  log "Keyboard layout options ${value} set."
}

# Sets the keyboard model to the given model.
# Arguments:
#  name: the name of the model
set_model () {
  authenticate_user || return $?

  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the keyboard model name.' && return 2

    pick_keyboard_model || return $?
    is_empty "${REPLY}" && log 'Keyboard model name is required.' && return 2
    name="${REPLY}"
  fi

  if is_not_keyboard_model "${name}"; then
    log 'Invalid or unknown keyboard model name.'
    return 2
  fi

  save_model_to_settings "${name}" &&
   apply_keyboard_settings
  
  if has_failed; then
    log 'Failed to set keyboard model.'
    return 2
  fi

  log "Keyboard model set to ${name}."
}

# Adds a locale to the system locales.
# Arguments:
#  name: the name of a locale
add_locale () {
  authenticate_user || return $?

  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the locale name.' && return 2

    pick_locale || return $?
    is_empty "${REPLY}" && log 'Locale name is required.' && return 2
    name="${REPLY}"
  fi

  if is_not_locale "${name}"; then
    log 'Invalid or unknown locale.'
    return 2
  elif is_locale_installed "${name}"; then
    log "Locale ${name} is already installed."
    return 2
  fi
  
  save_locale_to_settings "${name}" &&
   apply_locale_settings

  if has_failed; then
    log 'Failed to add locale.'
    return 2
  fi

  log "Locale ${name} has been added."
}

# Removes the given locale from the system locales.
# Arguments:
#  name: a locale name
remove_locale () {
  authenticate_user || return $?

  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the locale name.' && return 2

    pick_installed_locale || return $?
    is_empty "${REPLY}" && log 'Locale name is required.' && return 2
    name="${REPLY}"
  fi

  if is_not_locale "${name}"; then
    log 'Invalid or unknown locale.'
    return 2
  elif is_locale_not_installed "${name}"; then
    log "Locale ${name} is not installed."
    return 2
  elif is_locale_set "${name}"; then
    log 'Cannot remove a locale which is currently set.'
    return 2
  fi

  delete_locale_from_settings "${name}" &&
    apply_locale_settings

  if has_failed; then
    log 'Failed to remove locale.'
    return 2
  fi

  log "Locale ${name} has been removed."
}

# Adds a new layout to keyboard layouts with
# the optionally given alias.
# Arguments:
#  code:    a layout code
#  variant: a variant of the layout or default
#  alias:   an alias name of the layout
add_layout () {
  authenticate_user || return $?

  local code="${1}"
  local variant="${2}"
  local alias="${3}"

  if is_not_given "${code}"; then
    on_script_mode &&
      log 'Missing the layout code.' && return 2

    pick_layout || return $?
    is_empty "${REPLY}" && log 'Layout code is required.' && return 2
    code="${REPLY}"
  fi

  if is_not_layout "${code}"; then
    log 'Invalid or unknown layout code.'
    return 2
  fi
  
  if is_not_given "${variant}"; then
    on_script_mode &&
      log 'Missing the layout variant.' && return 2

    pick_layout_variant "${code}" || return $?
    is_empty "${REPLY}" && log 'Layout variant is required.' && return 2
    variant="${REPLY}"
  fi

  if is_not_layout_variant "${code}" "${variant}"; then
    log 'Invalid or unknown layout variant.'
    return 2
  fi

  if is_layout_installed "${code}" "${variant}"; then
    log "Layout ${code}${variant:+ ${variant}} is already added."
    return 2
  fi

  if not_on_script_mode && is_not_given "${alias}"; then
    ask 'Enter an alias name (blank to skip):' || return $?
    alias="${REPLY}"
  fi

  local count=''
  count="$(jq -cer ".layouts|length" "${LANGS_SETTINGS}")"

  if has_failed; then
    log 'Failed to read the number of installed layouts.'
    return 2
  fi

  if is_true "${count} = 4"; then
    log 'Maximum only 4 layouts could be installed.'
    return 2
  fi

  save_layout_to_settings "${code}" "${variant}" &&
   apply_keyboard_settings

  if has_failed; then
    log "Failed to add layout ${code}${variant:+ ${variant}}."
    return 2
  fi

  if is_given "${alias}"; then
    apply_alias_to_layout "${code}" "${variant}" "${alias}" ||
     log 'Failed to apply layout alias.'
  fi

  log "Layout ${code}${variant:+ ${variant}} has been added."
  log 'Please restart so changes take effect!'
}

# Removes a layout from the installed keyboard layouts.
# Arguments:
#  code:    a layout code
#  variant: a variant of the layout
remove_layout () {
  authenticate_user || return $?

  local code="${1}"
  local variant="${2}"

  if is_not_given "${code}"; then
    on_script_mode &&
     log 'Missing the layout code.' && return 2
    
    pick_installed_layout || return $?
    is_empty "${REPLY}" && log 'Layout is required.' && return 2
    code="$(echo ${REPLY} | cut -d ':' -f 1)"
    variant="$(echo ${REPLY} | cut -d ':' -f 2)"
  fi

  if is_not_layout "${code}"; then
    log 'Invalid or unknown layout code.'
    return 2
  fi
  
  if is_not_given "${variant}"; then
    log 'Missing the layout variant.'
    return 2
  fi

  if is_layout_not_installed "${code}" "${variant}"; then
    log "Layout ${code}${variant:+ ${variant}} is not installed."
    return 2
  fi
  
  local count=''
  count="$(jq -cer ".layouts|length" "${LANGS_SETTINGS}")"

  if has_failed; then
    log 'Failed to read the number of installed layouts.'
    return 2
  fi

  if is_true "${count} = 1"; then
    log 'At least one layout should be always installed.'
    return 2
  fi

  delete_layout_from_settings "${code}" "${variant}" &&
   apply_keyboard_settings

  if has_failed; then
    log "Failed to remove layout ${code}${variant:+ ${variant}}."
    return 2
  fi

  log "Layout ${code}${variant:+ ${variant}} has been removed."
}

# Sets the order of the currently installed layouts to the
# given layouts.
# Arguments:
#  layouts: a list of layout <code:variant> pairs
order_layouts () {
  authenticate_user || return $?

  local layouts=("$@")

  if is_true "${#layouts[@]} = 0"; then
    on_script_mode &&
      log 'Missing layouts pairs.' && return 2

    pick_installed_layouts || return $?
    is_empty "${REPLY}" && log 'Layouts are required.' && return 2
    layouts="${REPLY}"
  else
    # Convert given layouts args to json array
    layouts="$(jq -ncer '$ARGS.positional' --args -- "${layouts[@]}")" || return 1
  fi
  
  # Check for duplicated values in given layouts
  local query='(.|unique|length) as $len'
  query+=' | if $len != (.|length) then true else false end'

  local has_dups='false'
  has_dups="$(echo "${layouts}" | jq -cr "${query}")"

  if is_true "${has_dups}"; then
    log 'Layouts should not have duplicated values.'
    return 2
  fi
  
  # Check if given layouts match the currently installed ones
  local query='[.layouts[]|"\(.code):\(.variant)"] as $cl'
  query+=' | ($cl - $l | length) as $len1'
  query+=' | ($l - $cl | length) as $len2'
  query+=' | if $len1 == 0 and $len2 == 0 then $l|join(" ") else empty end'

  layouts="$(jq -cr --argjson l "${layouts}" "${query}" "${LANGS_SETTINGS}")" || return 1

  if is_empty "${layouts}"; then
    log 'Layouts do not match with current layouts.'
    return 2
  fi

  save_layouts_to_settings ${layouts} &&
   apply_keyboard_settings

  if has_failed; then
    log 'Failed to set layouts order.'
    return 2
  fi

  log "Layouts order set to ${layouts}."
}

# Gives an alias name to the layout with the
# given code and variant.
# Arguments:
#  code:    a layout code
#  variant: a layout variant
#  alias:   an alias name
name_layout () {
  authenticate_user || return $?

  local code="$1"
  local variant="$2"
  local alias="$3"

  if is_not_given "${code}"; then
    on_script_mode &&
     log 'Missing the layout code.' && return 2
    
    pick_installed_layout || return $?
    is_empty "${REPLY}" && log 'Layout is required.' && return 2
    code="$(echo ${REPLY} | cut -d ':' -f 1)"
    variant="$(echo ${REPLY} | cut -d ':' -f 2)"
  fi

  if is_not_layout "${code}"; then
    log 'Invalid or unknown layout code.'
    return 2
  fi

  if is_not_given "${variant}"; then
    log 'Missing the layout variant.'
    return 2
  fi

  if is_layout_not_installed "${code}" "${variant}"; then
    log "Layout ${code}${variant:+ ${variant}} is not installed."
    return 2
  fi

  if is_not_given "${alias}"; then
    on_script_mode &&
     log 'Missing the alias name.' && return 2
    
    ask 'Enter an alias name:' || return $?
    is_empty "${REPLY}" && log 'Alias name is required.' && return 2
    alias="${REPLY}"
  fi

  apply_alias_to_layout "${code}" "${variant}" "${alias}"
  
  if has_failed; then
    log "Failed to name layout ${code}${variant:+ ${variant}}."
    return 2
  fi

  log "Layout ${code}${variant:+ ${variant}} name to ${alias}."
  log 'Please restart so changes take effect!'
}

