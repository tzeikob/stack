#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/commons/text.sh

CONFIG_HOME="${HOME}/.config/stack"
LANGS_SETTINGS="${CONFIG_HOME}/langs.json"

# Shows a menu asking the user to select a keyboard map.
# Outputs:
#  A menu of keyboard maps.
pick_keymap () {
	local maps=''

	maps="$(localectl --no-pager list-keymaps | awk '{
	  print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
	}')" || return 1

	# Remove extra comma delimiter from the last element
	maps="${maps:+${maps::-1}}"

  maps="[${maps}]"

	pick_one 'Select a key map:' "${maps}" vertical || return $?
}

# Checks if the given keyboard map is valid.
# Arguments:
#  map: a keyboard map name
# Returns:
#  0 if map is valid otherwise 1.
is_keymap () {
	local map="${1}"
  
  localectl --no-pager list-keymaps | grep -qE "^${map}$"
  
  if has_failed; then
    return 1
  fi

	return 0
}

# An inverse version of is_keymap.
is_not_keymap () {
  is_keymap "${1}" && return 1 || return 0
}

# Shows a menu asking the user to select a locale.
# Outputs:
#  A menu of locales.
pick_locale () {
  local locales=''
  locales="$(cat /etc/locale.gen | tail -n +24 | grep -E '^\s*#.*' | tr -d '#' | trim | awk '{
    print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
  }')" || return 1
  
	# Removes the last comma delimiter from the last element
  locales="${locales:+${locales::-1}}"

  locales="[${locales}]"

  pick_one 'Select a locale:' "${locales}" vertical || return $?
}

# Shows a menu asking the user to select an instaled locale.
# Outputs:
#  A menu of locales.
pick_installed_locale () {
  local query='[.locales|if length > 0 then .[]|{key: ., value: .} else empty end]'

  local locales=''
  locales="$(jq -cr "${query}" "${LANGS_SETTINGS}")" || return 1

  local len=0
  len="$(count "${locales}")" || return 1

  if is_true "${len} = 0"; then
    log 'No installed locales found.'
    return 2
  fi
  
  pick_one 'Select a locale:' "${locales}" vertical || return $?
}

# Checks if the given locale is valid.
# Arguments:
#  name: the name of a locale
# Returns:
#  0 if locale is valid otherwise 1.
is_locale () {
	local name="${1}"
  
  grep -qE "^\s*#\s*${name}\s*$" /etc/locale.gen

  if has_failed; then
    return 1
  fi

	return 0
}

# An inverse version of is_locale.
is_not_locale () {
  is_locale "${1}" && return 1 || return 0
}

# Checks if the given locale is already installed.
# Arguments:
#  name: the name of a locale
# Returns:
#  0 if locale is set otherwise 1.
is_locale_installed () {
	local name="${1}"

  local query=".locales|if length > 0 then .[]|select(. == \"${name}\" else empty end)"

  jq -cer "${query}" "${LANGS_SETTINGS}" &> /dev/null || return 1
}

# An inverse version of is_locale_installed.
is_locale_not_installed () {
  is_locale_installed "${1}" && return 1 || return 0
}

# Shows a menu asking the user to select a layout
# options value.
# Outputs:
# A menu of keyboard layout options.
pick_options_value () {
  local options=''

  options="$(localectl --no-pager list-x11-keymap-options | awk '{
    print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
  }')" || return 1

  # Remove extra comma delimiter from last element
  options="${options:+${options::-1}}"

  options="[${options}]"

  pick_one 'Select an options value:' "${options}" vertical || return $?
}

# Checks if the given layout options value
# is valid.
# Arguments:
#  value: a layout options value
# Returns:
#  0 if value is valid otherwise 1.
is_layout_options () {
  local value="${1}"
  
  localectl --no-pager list-x11-keymap-options | grep -qw "${value}"
  
  if has_failed; then
    return 1
  fi

  return 0
}

# An inverse version of is_layout_options.
is_not_layout_options () {
  is_layout_options "${1}" && return 1 || return 0
}

# Shows a menu asking the user to select a keyboard model.
# Outputs:
#  A menu of keyboard models.
pick_keyboard_model () {
  local models=''

  models="$(localectl --no-pager list-x11-keymap-models | awk '{
    print "{\"key\":\""$1"\",\"value\":\""$1"\"},"
  }')" || return 1

  # Remove the extra comma delimiter from the last element
  models="${models:+${models::-1}}"

  models="[${models}]"

  pick_one 'Select a model name:' "${models}" vertical || return $?
}

# Checks if the given keyboard model is valid.
# Arguments:
#  name: the name of a keyboard model
# Returns:
#  0 if model is valid otherwise 1.
is_keyboard_model () {
  local name="${1}"
  
  localectl --no-pager list-x11-keymap-models | grep -qw "${name}"

  if has_failed; then
    return 1
  fi

  return 0
}

# An inverse version of is_keyboard_model.
is_not_keyboard_model () {
  is_keyboard_model "${1}" && return 1 || return 0
}

# Shows a menu asking the user to select a keyboard layout.
# Outputs:
#  A menu of keyboard layouts.
pick_layout () {
  local layouts=''
  layouts="$(localectl --no-pager list-x11-keymap-layouts | awk '{
    print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
  }')" || return 1
  
  # Remove the extra comma delimiter from last element
  layouts="${layouts:+${layouts::-1}}"

  layouts="[${layouts}]"

  pick_one 'Select a layout code:' "${layouts}" vertical || return $?
}

# Shows a menu asking the user to select an installed
# keyboard layout.
# Outputs:
#  A menu of keyboard layouts.
pick_installed_layout () {
  local query=''
  query='[.layouts[]|{"key": "\(.code):\(.variant)", "value": "\(.code):\(.variant)"}]'
  
  local layouts=''
  layouts="$(jq -c "${query}" "${LANGS_SETTINGS}")"
  
  pick_one 'Select a layout:' "${layouts}" vertical || return $?
}

# Shows a menu asking the user to select all installed
# keyboard layouts in a specific order.
# Outputs:
#  A menu of keyboard layouts.
pick_installed_layouts () {
  local query=''
  query='[.layouts[]|{"key": "\(.code):\(.variant)", "value": "\(.code):\(.variant)"}]'
  
  local layouts=''
  layouts="$(jq -c "${query}" "${LANGS_SETTINGS}")"
  
  pick_many 'Select layouts in order:' "${layouts}" vertical || return $?
}

# Shows a menu asking the user to select a variant
# of the given keyboard layout code.
# Arguments:
#  code: a keyboard layout code
# Outputs:
#  A menu of keyboard layout variants.
pick_layout_variant () {
  local code="${1}"

  local variants='{"key": "default", "value": "default"},'
  variants+="$(localectl --no-pager list-x11-keymap-variants "${code}" | awk '{
    print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
  }')" || return 1
  
  # Remove the extra comma delimiter from last element
  variants="${variants:+${variants::-1}}"

  variants="[${variants}]"

  pick_one 'Select a layout variant:' "${variants}" vertical || return $?
}

# Checks if the keyboard layout with the given code is valid.
# Arguments:
#  code: a layout code
# Returns:
#  0 if layout is valid otherwise 1.
is_layout () {
  local code="${1}"

  if not_match "${code}" '^[a-z]{2,6}$'; then
    return 1
  fi

  localectl --no-pager list-x11-keymap-layouts | grep -qw "${code}"
  
  if has_failed; then
    return 1
  fi

  return 0
}

# An inverse version of is_layout.
is_not_layout () {
  is_layout "${1}" && return 1 || return 0
}

# Checks if the keyboard layout with the given code
# and variant is valid.
# Arguments:
#  code:    a layout code
#  variant: a variant of the layout
# Returns:
#  0 if layout variant is valid otherwise 1.
is_layout_variant () {
  local code="${1}"
  local variant="${2}"

  if equals "${variant}" 'default'; then
    return 0
  fi

  localectl --no-pager list-x11-keymap-variants "${code}" | grep -qw "${variant}"
  
  if has_failed; then
    return 1
  fi

  return 0
}

# An inverse version of is_layout_variant.
is_not_layout_variant () {
  is_layout_variant "${1}" "${2}" && return 1 || return 0
}

# Saves the keymap into settings.
# Arguments:
#  keymap: a keyboard map
save_keymap_to_settings () {
  local keymap="${1}"

  local settings='{}'

  if file_exists "${LANGS_SETTINGS}"; then
    settings="$(jq -e ".keymap = \"${keymap}\"" "${LANGS_SETTINGS}")" || return 1
  else
    settings="$(echo "{\"keymap\": \"${keymap}\"}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${LANGS_SETTINGS}"
}

# Saves the keyboard model into settings.
# Arguments:
#  model: a keyboard model
save_model_to_settings () {
  local model="${1}"

  local settings='{}'

  if file_exists "${LANGS_SETTINGS}"; then
    settings="$(jq -e ".model = \"${model}\"" "${LANGS_SETTINGS}")" || return 1
  else
    settings="$(echo "{\"model\": \"${model}\"}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${LANGS_SETTINGS}"
}

# Saves the keyboard options value into settings.
# Arguments:
#  options: a keyboard options value
save_options_to_settings () {
  local options="${1}"

  local settings='{}'

  if file_exists "${LANGS_SETTINGS}"; then
    settings="$(jq -e ".options = \"${options}\"" "${LANGS_SETTINGS}")" || return 1
  else
    settings="$(echo "{\"options\": \"${options}\"}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${LANGS_SETTINGS}"
}

# Saves the keyboard layout into settings.
# Arguments:
#  code:    a keyboard layout code
#  variant: a variant of the given layout code
save_layout_to_settings () {
  local code="${1}"
  local variant="${2}"

  local layout="{ \"code\": \"${code}\", \"variant\": \"${variant}\"}"

  local settings='{}'

  if file_exists "${LANGS_SETTINGS}"; then
    local layouts=''
    layouts="$(jq 'if .layouts then .layouts else empty end' "${LANGS_SETTINGS}")"

    if is_not_empty "${layouts}"; then
      local query=".[]|select(.code == \"${code}\" and .variant == \"${variant}\")"

      local match=''
      match="$(echo "${layouts}" | jq -cr "${query}")"

      # Skip and return if the layout is already saved
      if is_not_empty "${match}"; then
        return 0
      fi
      
      settings="$(jq -e ".layouts += [${layout}]" "${LANGS_SETTINGS}")" || return 1
    else
      settings="$(jq -e ".layouts = [${layout}]" "${LANGS_SETTINGS}")" || return 1
    fi
  else
    settings="$(echo "{\"layouts\": [${layout}]}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${LANGS_SETTINGS}"
}

# Replaces the keyboard layouts into settings.
# Arguments:
#  layouts: a list of <code:variant> layout pairs
save_layouts_to_settings () {
  local layouts=("$@")

  # Convert arguments to json array
  layouts="$(jq -ncer '$ARGS.positional' --args -- "${layouts[@]}")" || return 1

  # Build the layouts settings object from <code>:<variant> pairs
  local query='[.[]|split(":")|{code: .[0], variant: .[1]}]'

  layouts="$(echo "${layouts}" | jq -cer "${query}")" || return 1

  local settings='{}'

  if file_exists "${LANGS_SETTINGS}"; then
    settings="$(jq -e ".layouts = ${layouts}" "${LANGS_SETTINGS}")" || return 1
  else
    settings="$(echo "{\"layouts\": ${layouts}}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${LANGS_SETTINGS}"
}

# Deletes the keyboard layout from settings.
# Arguments:
#  code:    a keyboard layout code
#  variant: a variant of the given layout code
delete_layout_from_settings () {
  local code="${1}"
  local variant="${2}"

  if file_not_exists "${LANGS_SETTINGS}"; then
    return 0
  fi

  local query='.code == $c and .variant == $v'
  query="if .layouts then .layouts[]|select(${query}) else empty end"

  local settings=''
  settings="$(jq -e --arg c "${code}" --arg v "${variant}" "del(${query})" "${LANGS_SETTINGS}")" || return 1

  echo "${settings}" > "${LANGS_SETTINGS}"
}

# Reads the settings file and applies the keyboard
# settings via the localectl and setxkbmap.
apply_keyboard_settings () {
  local settings=''
  settings="$(jq -cr '.' "${LANGS_SETTINGS}")"
  
  # Colect layout codes in the same given order
  local query='[.layouts[].code] | join(",")'

  local codes=''
  codes="$(echo "${settings}" | jq -cr "${query}")"

  # Collect layout variants in the same order codes are given
  local query='[.layouts[].variant | if . == "default" then "" else . end] | join(",")'

  local variants=''
  variants="$(echo "${settings}" | jq -cr "${query}")"
  
  local model=''
  model="$(echo "${settings}" | jq -cr '.model')"

  local options=''
  options="$(echo "${settings}" | jq -cr '.options')"
  
  local map=''
  map="$(echo "${settings}" | jq -cr '.keymap')"

  sudo localectl set-keymap --no-convert "${map}" &&
   sudo localectl --no-convert set-x11-keymap "${codes}" "${model}" "${variants}" "${options}" &&
   setxkbmap -layout "${codes}" -variant "${variants}" -model "${model}" -option "${options}"
}

# Checks if the given layout is already installed.
# Arguments:
#  code:    a layout code
#  variant: a variant of layout
# Returns:
#  0 if layout is installed otherwise 1.
is_layout_installed () {
  local code="${1}"
  local variant="${2}"
  
  local query=''
  query+=".layouts[] | select(.code == \"${code}\" and .variant == \"${variant}\")"

  local match=''
  match="$(jq -cr "${query}" "${LANGS_SETTINGS}")"

  if is_empty "${match}"; then
    return 1
  fi

  return 0
}

# An inversed alias of is_layout_installed.
is_layout_not_installed () {
  is_layout_installed "${1}" "${2}" && return 1 || return 0
}

# Replaces the current layout's group name to the
# given alias name.
# Arguments:
#  code:    a layout code
#  variant: a variant of the layout code
#  alias:   an alias name
apply_alias_to_layout () {
  local code="${1}"
  local variant="${2}"
  local alias="${3}"
  
  local symbol_file="/usr/share/X11/xkb/symbols/${code}"

  # Backup the symbol file if no yet done
  if file_not_exists "${symbol_file}.bkp"; then
    sudo cp "${symbol_file}" "${symbol_file}.bkp"
  fi

  # Find the corresponding name line in the layout's symbol file
  local index=0
  local index="$(awk -v v="${variant}" '{
    re="^[ \t]*xkb_symbols[ \t]*\""v"\""

    if (v == "default") {
      re="^default[ \t]*(partial)?"
    }

    if ($0 ~ re) {
     while (!($0 ~ /^[ \t]*name\[Group1\][ \t]*=.*/)) {
       getline
     }

     print NR
     exit
    } else {
      next
    }
  }' "${symbol_file}")"

  if is_not_integer "${index}" || is_true "${index} < 1"; then
    return 1
  fi

  # Replace the layout name line
  sudo sed -i "${index} s;.*;   name[Group1]= \"${alias}\"\;;" "${symbol_file}" &> /dev/null
}

# Save the given locale into settings.
# Arguments:
#  name: a locale name
save_locale_to_settings () {
  local name="${1}"

  local settings='{}'

  if file_exists "${LANGS_SETTINGS}"; then
    local locales="$(jq '.locales' "${LANGS_SETTINGS}")"

    if is_not_empty "${locales}"; then
      local query=".[]|select(. == \"${name}\")"

      local match=''
      match="$(echo "${locales}" | jq -cr "${query}")"

      # Skip and return if the layout is already saved
      if is_not_empty "${match}"; then
        return 0
      fi
      
      settings="$(jq -e ".locales += [\"${name}\"]" "${LANGS_SETTINGS}")" || return 1
    else
      settings="$(jq -e ".locales = [\"${name}\"]" "${LANGS_SETTINGS}")" || return 1
    fi
  else
    settings="$(echo "{\"locales\": [\"${name}\"]}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${LANGS_SETTINGS}"
}

# Deletes the locale from settings.
# Arguments:
#  name: a locale name
delete_locale_from_settings () {
  local name="${1}"

  if file_not_exists "${LANGS_SETTINGS}"; then
    return 0
  fi

  local query=". == \"${name}\""
  query=".locales | if . and length > 0 then .[]|select(${query}) else empty end"

  local settings=''
  settings="$(jq -e "del(${query})" "${LANGS_SETTINGS}")" || return 1

  echo "${settings}" > "${LANGS_SETTINGS}"
}

# Checks if the locale with the given name
# is set in any locale env variable.
# Arguments:
#  name: a locale name
# Returns:
#  0 if locale is set otherwise 1.
is_locale_set () {
  local name="${1}"

  # Keep only the first part of locale
  name="$(echo "${name}" | cut -d ' ' -f 1)"

  local vars=(
    LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE
    LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS
    LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL
  )

  local var=''
  for var in "${vars[@]}"; do
    # Read the value of the next env variable
    local value="$(printf '%s\n' "${!var}")"

    if equals "${name}" "${value}"; then
      return 0
    fi
  done

  # Check also the locale.conf file
  if grep -wq "${name}" /etc/locale.conf; then
    return 0
  fi

  return 1
}

# An inversed alias of the is_locale_set.
is_locale_not_set () {
  is_locale_set "${1}" && return 1 || return 0
}

# Save the given system locale into settings.
# Arguments:
#  name: a locale name
save_system_locale_to_settings () {
  local name="${1}"

  local settings='{}'

  if file_exists "${LANGS_SETTINGS}"; then
    settings="$(jq -e ".locale = \"${name}\"" "${LANGS_SETTINGS}")" || return 1
  else
    settings="$(echo "{\"locale\": \"${name}\"}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${LANGS_SETTINGS}"
}

# Reads the settings and applies the system's locale
# settings into the locale.conf file.
apply_system_locale_settings () {
  local locale=''
  locale="$(jq -cr '.locale' "${LANGS_SETTINGS}")"

  # Set system locale variables
  printf '%s\n' \
    "LANG=${locale}" \
    "LANGUAGE=${locale}:en:C" \
    "LC_CTYPE=${locale}" \
    "LC_NUMERIC=${locale}" \
    "LC_TIME=${locale}" \
    "LC_COLLATE=${locale}" \
    "LC_MONETARY=${locale}" \
    "LC_MESSAGES=${locale}" \
    "LC_PAPER=${locale}" \
    "LC_NAME=${locale}" \
    "LC_ADDRESS=${locale}" \
    "LC_TELEPHONE=${locale}" \
    "LC_MEASUREMENT=${locale}" \
    "LC_IDENTIFICATION=${locale}" \
    "LC_ALL=" | sudo tee /etc/locale.conf &> /dev/null

  # Unset previous set variables
  unset LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE \
        LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS \
        LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL

  # Reload locale env variables
  source /etc/profile.d/locale.sh
}

# Reads the settings file and applies the locales
# via the locale.gen file.
apply_locale_settings () {
  # Clear any installed locales from locale.gen file
  sudo sed -i "/^\s*[a-z][a-z].*/d" /etc/locale.gen

  # Apply the locales set in the settings file
  local locales=''
  locales="$(jq -cr '.locales[]' "${LANGS_SETTINGS}")"

  local locale=''
  while read -r locale; do
    echo "${locale}" | sudo tee -a /etc/locale.gen &> /dev/null
  done <<< "${locales}"

  sudo locale-gen
}

