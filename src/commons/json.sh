#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/validators.sh

# Outputs back the json type of the given value, which
# could be any of string, number, boolean, array, object
# null or none.
# Arguments:
#  value: any value
# Outputs:
#  The type of the given value.
get_type () {
  local value="${1}"

  if is_empty "${value}" || match "${value}" '^ *$' || match "${value}" '^" *"$'; then
    echo 'none'
    return 0
  fi

  local type=''
  type="$(echo "${value}" | jq -cer 'type' 2> /dev/null)"

  # Consider any value of invalid type as string
  if [[ $? -ne 0 ]]; then
    echo 'string'
    return 0
  fi

  echo "${type}"
}

# Saves or sets the value of the property matching the given jq key
# path to the given json file or json object. If the property doesn't
# exist it will be added under the given key path.
# Arguments:
#  subject:  path of a json file or a json object
#  key_path: the jq key path of the property
#  value:    any json valid value
# Ouputs:
#  If subject is a json object outputs the new object back.
set_property () {
  local subject="${1}"
  local key_path="${2}"
  local value="${3}"

  local type=''
  type="$(get_type "${value}")"

  if equals "${type}" 'none'; then
    value='""'
  elif equals "${type}" 'string' && not_match "${value}" '^".*"$'; then
    value="\"${value}\""
  fi

  local query="${key_path} = ${value}"

  if file_exists "${subject}"; then
    local tmp_file=$(mktemp)
    
    jq -er "${query}" "${subject}" 2> /dev/null > "${tmp_file}" &&
      mv "${tmp_file}" "${subject}"
  else
    echo "${subject}" | jq -cer "${query}" 2> /dev/null
  fi
}

# Reads or gets the value of the property selected by the given
# jq query from the given json file or json object.
# Arguments:
#  subject: path of a json file or a json object
#  query:   the query path of a property
# Outputs:
#  The value of the given property otherwise none.
get_property () {
  local subject="${1}"
  local query="${2:-"."}"

  query="${query}|if . then . else \"\" end"

  if file_exists "${subject}"; then
    jq -cer "${query}" "${subject}" 2> /dev/null
  else
    echo "${subject}" | jq -cer "${query}" 2> /dev/null
  fi
}

# Checks if the property matching the given jq key path is equal
# to the given value in the given json file or json object.
# Arguments:
#  subject:  path of a json file or a json object
#  key_path: the jq key path of a property
#  value:    any json valid value
# Returns:
#  0 if the property is equal to the value otherwise 1.
is_property () {
  local subject="${1}"
  local key_path="${2}"
  local value="${3}"

  local type=''
  type="$(get_type "${value}")"

  if equals "${type}" 'none'; then
    value='""'
  elif equals "${type}" 'string' && not_match "${value}" '^".*"$'; then
    value="\"${value}\""
  fi

  local query="select(${key_path} == ${value})"

  if file_exists "${subject}"; then
    jq -cer "${query}" "${subject}" &> /dev/null
  else
    echo "${subject}" | jq -cer "${query}" &> /dev/null
  fi
}
