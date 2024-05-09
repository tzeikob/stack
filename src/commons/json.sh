#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/validators.sh

# Saves the value to the property with the given key to the
# given json file.
# Arguments:
#  file:  the path to the json file
#  key:   the key name of the property
#  value: any json valid value
write_property () {
  local file="${1}"
  local key="${2}"
  local value="${3}"

  if is_empty "${value}" || match "${value}" '^ *$'; then
    value='""'
  fi

  jq -cr ".${key} = ${value}" "${file}" > "${file}"
}

# Reads the value of the property with the given key
# from the given jsoon file.
# Arguments:
#  file: the path to the json file
#  key:  the key name of a property
# Outputs:
#  The value of the given property otherwise none.
read_property () {
  local file="${1}"
  local key="${2}"

  jq -cer ".${key}" "${file}"
}

# Checks if the property with the given key is equal
# to the given value in the given json file.
# Arguments:
#  file: the path to the json file
#  key:   the key of a property
#  value: any json valid value
# Returns:
#  0 if the property is equal to the value otherwise 1.
is_property () {
  local file="${1}"
  local key="${2}"
  local value="${3}"

  # Check if the given value is of invalid type
  echo "${value}" | jq -cer 'type' &> /dev/null

  # Consider any value of invalid type as string
  if [[ $? -ne 0 ]]; then
    value="\"${value}\""
  fi

  local query="select(.${key} == ${value})"

  jq -cer "${query}" "${file}" &> /dev/null
}

# Gets the value of the property matched by the
# given query, where query could be any valid jq query.
# Arguments:
#  object: any valid JSON object
#  query:  a jq query
# Outputs:
#  The value of the matched property.
get_value () {
  local object="${1}"
  local query="${2:-"."}|if . then . else \"\" end"

  local result=''
  result="$(echo "${object}" | jq -cr "${query}")" || return 1

  echo "${result}"
}

# Counts the number of elements in the given JSON array.
# Arguments:
#  array: a JSON array object
# Outputs:
#  The number of array elements.
get_len () {
  local array="${1}"

  local result=0
  result="$(echo "${array}" | jq -cer 'length')" || return 1

  echo "${result}"
}
