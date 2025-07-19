#!/bin/bash

# Downloads the files with the given URL to the
# the given directory.
# Arguments:
#  output: the output directory
#  files:  a list of urls
download () {
  local output="${1}" && shift
  local urls="${@}"

  echo ${urls} | awk '{
    for (i=1; i<=NF; i++) {
      print " "$i
    }
  }'

  local url=''
  
  for url in ${urls}; do
    wget -P "${output}" "${url}" -q --show-progress || return 1
  done
}

# Returns the list of any detected hosts in the
# local network.
# Outputs:
#  A json array list of host objects.
find_hosts () {
  local route=''
  route="$(ip route get 1.1.1.1)" || return 1

  local cidr=''
  cidr="$(echo "${route}" | awk '/via/{print $3}' |
    head -n 1 | sed -r 's/(\.[0-9]{1,3}$)/.0\/24/')" || return 1

  local map=''
  map="$(nmap -n -sn "${cidr}" -oG -)" || return 1

  local ips=''
  ips="$(echo "${map}" | awk '/Up$/{print $2}')" || return 1

  local ip='' hosts=''

  while read -r ip; do
    local host_map=''
    host_map="$(nmap --host-timeout 5 "${ip}" -oG -)" || continue

    hosts+="$(echo "${host_map}" | awk '/Host.*Up/{
      gsub(/(\(|\))/,"",$3);
      print "{\"ip\":\""$2"\",\"name\":\""$3"\"},"
    }')"
  done <<< "${ips}"

  # Remove the extra comma after the last element
  hosts="${hosts:+${hosts::-1}}"

  echo "[${hosts}]"
}
