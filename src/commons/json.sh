#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/validators.sh

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

  if is_empty "${value}" || match "${value}" '^ *$'; then
    value='""'
  fi

  local query="${key_path} = ${value}"

  if file_exists "${subject}"; then
    local tmp_file=$(mktemp)
    
    jq -cer "${query}" "${subject}" 2> /dev/null > "${tmp_file}" &&
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

  # Check if the given value is of invalid type
  echo "${value}" | jq -cer 'type' &> /dev/null

  # Consider any value of invalid type as string
  if [[ $? -ne 0 ]]; then
    value="\"${value}\""
  fi

  local query="select(${key_path} == ${value})"

  if file_exists "${subject}"; then
    jq -cer "${query}" "${subject}" &> /dev/null
  else
    echo "${subject}" | jq -cer "${query}" &> /dev/null
  fi
}
