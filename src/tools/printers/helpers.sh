#!/bin/bash

source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/network.sh
source src/commons/validators.sh

# Returns the list of all printing destinations,
# which have been installed into the system.
# Outputs:
#  A json array of print destination objects.
find_destinations () {
  local destinations=''
  destinations="$(lpstat -v 2>&1)"

  local exit_code=$?

  if match "${destinations}" 'No destinations added'; then
    echo '[]'
    return 0
  elif has_failed "${exit_code}"; then
    return 1
  fi
  
  destinations="$(echo "${destinations}" | awk '/device for.*/{
    match($0, /device for (.*): (.*):(.*)/, a)

    schema="\"name\": \"%s\","
    schema=schema"\"protocol\": \"%s\","
    schema=schema"\"uri\": \"%s\""
    schema="{"schema"},"

    printf schema, a[1], a[2], a[2]":"a[3]
  }')"

  # Remove the extra comma after the last element
  destinations="${destinations:+${destinations::-1}}"

  echo "[${destinations}]"
}

# Returns the print destination with the given name.
# Outputs:
#  A json object of print destination.
find_destination () {
  local name="${1}"

  local query=".[] | select(.name == \"${name}\")"

  local destination=''
  destination="$(find_destinations | jq -cer "${query}")" || return 1

  local options=''
  options="$(lpoptions -p "${name}" -l | awk '{
    match($0, /(.*)\/(.*):.*\*([^ ]*).*/, a)

    schema="\"%s\": \"%s\","
    printf schema, a[1], a[3]
  }')" || return 1

  # Remove the extra comma after the last pair
  options="${options:+${options::-1}}"

  options="{${options}}"

  local props=''
  props="$(lpoptions -p "${name}" | awk '{
    re=""
    re=re "copies=.+\\sdevice-uri=.+\\sfinishings=.+\\s"
    re=re "job-cancel-after=.+\\sjob-hold-until=.+\\sjob-priority=.+\\s"
    re=re "job-sheets=.+\\smarker-change-time=.+\\snumber-up=.+\\s"
    re=re "print-color-mode=(.+)\\sprinter-commands=.+\\sprinter-info='\''(.+)'\''\\s"
    re=re "printer-is-accepting-jobs=(.+)\\sprinter-is-shared=(.+)\\s"
    re=re "printer-is-temporary=(.+)\\sprinter-location=(.+)\\s"
    re=re "printer-make-and-model='\''(.+)'\''\\sprinter-state=(.+)\\s"
    re=re "printer-state-change-time=.+\\sprinter-state-reasons=.+\\s"
    re=re "printer-type=(.+)\\sprinter-uri-supported=.+"
    
    match($0, re, a)
    out=""
    out=out "\"color\":\"" a[1] "\","
    out=out "\"description\":\"" a[2] "\","
    out=out "\"accepting_jobs\":\"" a[3] "\","
    out=out "\"is_shared\":\"" a[4] "\","
    out=out "\"is_temp\":\"" a[5] "\","
    out=out "\"location\":\"" a[6] "\","
    out=out "\"model\":\"" a[7] "\","
    out=out "\"state\":\"" a[8] "\","
    out=out "\"type\":\"" a[9] "\""
    out="{" out "}"

    print out
  }')" || return 1

  echo "${destination}" |
    jq -cer --argjson o "${options}" --argjson p "${props}" '. + $o + $p' || return 1
}

# Checks if a destination with the given name exists.
# Arguments:
#  name: the name of a print destination
# Returns:
#  0 if exists otherwise 1.
destination_exists () {
  local name="${1}"

  local query=".[] | select(.name == \"${name}\")"

  find_destinations | jq -cer "${query}" &> /dev/null
}

# An inverse version of destination_exists.
destination_not_exists () {
  ! destination_exists "${1}"
}

# Discovers any direct or network print destinations.
# Outputs:
#  A json array of print destination objects.
discover_destinations () {
  local destinations=''

  # Search in local network for snmp destinations
  local hosts=''
  hosts="$(find_hosts | jq -cer '.[] | .ip')"

  if has_not_failed && is_not_empty "${hosts}"; then
    local host=''
    
    while read -r host; do
      destinations+="$(/usr/lib/cups/backend/snmp "${host}" 2>&1 |
        awk '/^network\s.*:\/\//{
          match($0, /^network\s.*:\/\/.*\s"(.*)"\s".*"\s".*".*/, a)

          schema="\"type\": \"%s\","
          schema=schema"\"uri\": \"%s\","
          schema=schema"\"name\": \"%s\""
          schema="{"schema"},"

          printf schema, $1, $2, a[1]
        }')" || continue
    done <<< "${hosts}"
  fi

  # Search for extra direct and network destinations
  destinations+="$(lpinfo -v 2>&1 | awk '/^(direct|network)\s.*:\/\//{
    match($0, /^(direct|network)\s.*:\/\/.*\s"(.*)"\s".*"\s".*".*/, a)

    schema="\"type\": \"%s\","
    schema=schema"\"uri\": \"%s\","
    schema=schema"\"name\": \"%s\""
    schema="{"schema"},"

    printf schema, $1, $2, a[1]
  }')" || return 1

  # Remove the extra comma after the last element
  destinations="${destinations:+${destinations::-1}}"

  echo "[${destinations}]"
}

# Returns all the active queued print jobs.
# Outputs:
#  A json array list of print job objects.
find_jobs () {
  local jobs=''

  jobs="$(lpq -a | awk '{
    if (NR==1) next

    match($0, /.*\s+([0-9]{1,3})\s+(.*)\s+([0-9]+)\sbytes$/, a)

    schema="\"id\": \"%s\","
    schema=schema"\"rank\": \"%s\","
    schema=schema"\"file\": \"%s\","
    schema=schema"\"size\": \"%s\""
    schema="{"schema"},"

    printf schema, a[1], $1, a[2], a[3]
  }')" || return 1

  # Remove the extra comma after the last element
  jobs="${jobs:+${jobs::-1}}"

  echo "[${jobs}]"
}

# Checks if a print job with the given id exists.
# Arguments:
#  id: the id of a print job
# Returns:
#  0 if exists otherwise 1.
job_exists () {
  local id="${1}"

  local query=".[] | select(.id == \"${id}\")"

  find_jobs | jq -cer "${query}" &> /dev/null
}

# An inverse version of job_exists.
job_not_exists () {
  ! job_exists "${1}"
}

# Shows a menu asking the user to select one printer.
# Outputs:
#  A menu of printers.
pick_printer () {
  local option='{key: .name, value: "\(.name) [\(.uri | dft("..."))]"}'

  local query="[.[] | ${option}]"

  local destinations=''
  destinations="$(find_destinations | jq -cer "${query}")" || return 1

  local len=0
  len="$(echo "${destinations}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No printers have found.'
    return 2
  fi

  pick_one 'Select a printer:' "${destinations}" vertical || return $?
}

# Shows a menu asking the user to select a uri
# print destination.
# Outputs:
#  A menu of uri print destinations.
pick_uri () {
  local option='{key: .uri, value: "\(.uri) [\(.name | dft("..."))]"}'
  
  local query="[.[] | ${option}]"

  local destinations=''
  destinations="$(discover_destinations | jq -cer "${query}")"

  if has_failed; then
    log 'Unable to discover print destinations.'
    return 2
  fi

  local len=0
  len="$(echo "${destinations}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No print uri destinations discovered.'
    return 2
  fi

  pick_one 'Select print uri destination:' "${destinations}" vertical || return $?
}

# Returns the list of available printer drivers.
# Outputs:
#  A json array list of drivers.
find_drivers () {
  local drivers=''

  drivers="$(lpinfo -m 2>&1 | awk '{
    desc=""
    for (i=2; i<=NF; i++) {
      if (i>2) desc=desc" " 
      desc=desc$i
    }

    schema="\"key\": \"%s\","
    schema=schema"\"value\": \"%s\""
    schema="{"schema"},"

    printf schema, $1, desc
  }')" || return 1
  
  # Remove the extra comma after the last element
  drivers="${drivers:+${drivers::-1}}"

  echo "[${drivers}]"
}

# Checks if the given driver is available in the system.
# Arguments:
#  name: the key name of the driver
# Returns:
#  0 if it's available otherwise 1.
is_driver_available () {
  local name="${1}"

  local query=".[] | select(.key == \"${name}\")"

  find_drivers | jq -cer "${query}" &> /dev/null
}

# An inverse version of is_driver_available.
is_driver_not_available () {
  ! is_driver_available "${1}"
}

# Shows a menu asking the user to select one driver.
# Outputs:
#  A menu of printer drivers.
pick_driver () {
  local drivers=''
  drivers="$(find_drivers)" || return 1
  
  local len=0
  len="$(echo "${drivers}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No drivers have found.'
    return 2
  fi

  pick_one 'Select a print driver:' "${drivers}" vertical || return $?
}

# Shows a menu asking the user to select one print job.
# Outputs:
#  A menu of print jobs.
pick_job () {
  local option='{key: .id, value: "\(.id) [\(.file | dft("..."))]"}'

  local query="[.[] | ${option}]"

  local jobs=''
  jobs="$(find_jobs | jq -cer "${query}")" || return 1

  local len=0
  len="$(echo "${jobs}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No print jobs have found.'
    return 2
  fi

  pick_one 'Select a print job:' "${jobs}" vertical || return $?
}

# Shows a menu asking the user to select a print option.
# Outputs:
#  A menu of print options.
pick_print_option () {
  local options=''
  options+='{"key": "Quality", "value": "Quality"},'
  options+='{"key": "PageSize", "value": "Page Size"},'
  options+='{"key": "MediaType", "value": "Paper Size"},'
  options+='{"key": "TonerSaveMode", "value": "Toner Mode"},'
  options+='{"key": "printer-error-policy", "value": "Error Policy"}'
  options="[${options}]"

  pick_one 'Select a print option:' "${options}" vertical || return $?
}

# Checks if the given key is a valid print option.
# Arguments:
#  key: the key of a print option
# Returns:
#  0 if key is valid otherwise 1.
is_print_option () {
  local key="${1}"

  local options='Quality|PageSize|MediaType|TonerSaveMode|printer-error-policy'

  match "${key}" "^(${options})$"
}

# An inverse version of is_print_option.
is_not_print_option () {
  ! is_print_option "${1}"
}

# Shows a menu asking the user to select a print quality
# option.
# Outputs:
#  A menu of quality options.
pick_print_quality () {
  local values=''
  values+='{"key": "600dpi", "value": "Standard [600dpi]"},'
  values+='{"key": "1200dpi", "value": "High Resolution [1200dpi]"}'
  values="[${values}]"

  pick_one 'Select a print quality:' "${values}" vertical || return $?
}

# Checks if the given print quality value is valid.
# Arguments:
#  value: a print quality value
# Returns:
#  0 if value is valid otherwise 1.
is_valid_quality () {
  local value="${1}"

  match "${value}" '^(600dpi|1200dpi)$'
}

# An inverse version of is_valid_quality.
is_not_valid_quality () {
  ! is_valid_quality "${1}"
}

# Shows a menu asking the user to select a page size option.
# Outputs:
#  A menu of page size options.
pick_page_size () {
  local values=''
  values+='{"key": "Letter", "value": "Letter [Letter]"},'
  values+='{"key": "Legal", "value": "Legal [Legal]"},'
  values+='{"key": "A4", "value": "A4 [A4]"},'
  values+='{"key": "A5", "value": "A5 [A5]"},'
  values+='{"key": "Executive", "value": "Executive [Executive]"},'
  values+='{"key": "Folio", "value": "US Folio [Folio]"},'
  values+='{"key": "JB5", "value": "JIS B5 [JB5]"},'
  values+='{"key": "B5-ISO", "value": "ISO B5 [B5-ISO]"},'
  values+='{"key": "COM10", "value": "No.10 Env. [COM10]"},'
  values+='{"key": "Monarch", "value": "Monarch Env. [Monarch]"},'
  values+='{"key": "DL", "value": "DL Env. [DL]"},'
  values+='{"key": "C5", "value": "C5 Env. [C5]"},'
  values+='{"key": "Oficio_S", "value": "Oficio [Oficio_S]"},'
  values+='{"key": "PCard4x6", "value": "Post Card 4x6 [PCard4x6]"}'
  values="[${values}]"

  pick_one 'Select a page size:' "${values}" vertical || return $?
}

# Checks if the given print page size value is valid.
# Arguments:
#  value: a print page size value
# Returns:
#  0 if value is valid otherwise 1.
is_valid_page_size () {
  local value="${1}"

  local sizes='Letter|Legal|A4|A5|Executive|Folio|JB5'
  sizes+='|B5-ISO|COM10|Monarch|DL|C5|Oficio_S|PCard4x6'

  match "${value}" "^(${sizes})$"
}

# An inverse version of is_valid_page_size.
is_not_valid_page_size () {
  ! is_valid_page_size "${1}"
}

# Shows a menu asking the user to select a media type option.
# Outputs:
#  A menu of media type options.
pick_media_type () {
  local values=''
  values+='{"key": "None", "value": "Printer Default [None]"},'
  values+='{"key": "Plain", "value": "Plain [Plain]"},'
  values+='{"key": "Thick", "value": "Thick [Thick]"},'
  values+='{"key": "Thin", "value": "Thin [Thin]"},'
  values+='{"key": "Bond", "value": "Bond [Bond]"},'
  values+='{"key": "Color", "value": "Color [Color]"},'
  values+='{"key": "Card", "value": "CardStock [Card]"},'
  values+='{"key": "Labels", "value": "Labels [Labels]"},'
  values+='{"key": "Preprinted", "value": "Preprinted [Preprinted]"},'
  values+='{"key": "Cotton", "value": "Cotton [Cotton]"},'
  values+='{"key": "Archive", "value": "Archive [Archive]"},'
  values+='{"key": "Recycled", "value": "Recycled [Recycled]"},'
  values+='{"key": "Envelope", "value": "Envelope [Envelope]"}'
  values="[${values}]"

  pick_one 'Select a media type:' "${values}" vertical || return $?
}

# Checks if the given print media type value is valid.
# Arguments:
#  value: a print media type value
# Returns:
#  0 if value is valid otherwise 1.
is_valid_media_type () {
  local value="${1}"

  local types='None|Plain|Thick|Thin|Bond|Color|Card|Labels'
  types+='|Preprinted|Cotton|Archive|Recycled|Envelope'

  match "${value}" "^(${types})$"
}

# An inverse version of is_valid_media_type.
is_not_valid_media_type () {
  ! is_valid_media_type "${1}"
}

# Shows a menu asking the user to select a toner mode option.
# Outputs:
#  A menu of toner mode options.
pick_toner_mode () {
  local values=''
  values+='{"key": "Save", "value": "Save"},'
  values+='{"key": "Standard", "value": "Standard"}'
  values="[${values}]"

  pick_one 'Select a toner mode:' "${values}" vertical || return $?
}

# Checks if the given print toner mode value is valid.
# Arguments:
#  value: a print toner mode value
# Returns:
#  0 if value is valid otherwise 1.
is_valid_toner_mode () {
  local value="${1}"

  match "${value}" '^(Save|Standard)$'
}

# An inverse version of is_valid_toner_mode.
is_not_valid_toner_mode () {
  ! is_valid_toner_mode "${1}"
}

# Shows a menu asking the user to select a error policy option.
# Outputs:
#  A menu of error policy options.
pick_error_policy () {
  local values=''
  values+='{"key": "abort-job", "value": "Abort Job [abort-job]"},'
  values+='{"key": "retry-current-job", "value": "Retry Current Job [retry-current-job]"},'
  values+='{"key": "retry-job", "value": "Retry Job [retry-job]"},'
  values+='{"key": "stop-printer", "value": "Stop Printer [stop-printer]"}'
  values="[${values}]"

  pick_one 'Select an error policy:' "${values}" vertical || return $?
}

# Checks if the given print error policy value is valid.
# Arguments:
#  value: a print error policy value
# Returns:
#  0 if value is valid otherwise 1.
is_valid_error_policy () {
  local value="${1}"

  local policies='abort-job|retry-current-job|retry-job|stop-printer'

  match "${value}" "^(${policies})$"
}

# An inverse version of is_valid_error_policy.
is_not_valid_error_policy () {
  ! is_valid_error_policy "${1}"
}
