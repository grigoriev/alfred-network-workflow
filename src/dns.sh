#!/bin/bash

. src/helpers.sh

# Copy defaults to alfred cache dir if they do not exist
FILE=$alfred_workflow_cache/dns.conf
if [[ ! -f "$FILE" ]]; then
  mkdir -p "$alfred_workflow_cache"
  cp src/default-dns.conf "$FILE"
fi

NAME="$(get_primary_interface_name)"

# Handle action
if [[ "$1" != "" ]]; then
  if [[ "$1" == "EDIT" ]]; then
  	open -a TextEdit "$FILE"
    exit
  elif [[ "$1" == "DEFAULT" ]]; then
    DNS="empty"
  else
    DNS=$(echo "$1" | sed 's/ \/ / /g')
  fi

  networksetup -setdnsservers "${NAME%,*}" $DNS
  dscacheutil -flushcache
  exit
fi

DNSSTRING=$(get_dns "$(networksetup -getdnsservers "$NAME")")

# Parse dns config file
while read -r LINE; do
  DNSCONFIG=$(parse_dns_line "$LINE" "$DNSSTRING")
  IFS='~' read -r -a ARRAY <<< "$DNSCONFIG"

  if [[ "${ARRAY[0]}" != "" ]]; then
    add_result "" "${ARRAY[1]}" "${ARRAY[0]}" "${ARRAY[1]}" "${ARRAY[2]}"
  fi
done < "$FILE"

add_result "" "EDIT" "Edit DNS List" "" "$ICON_DNS"

if [[ "$DNSSTRING" == "" ]]; then
  add_result "" "DEFAULT" "Default DNS (used)" "Default" "$ICON_DNS_USED"
else
  add_result "" "DEFAULT" "Default DNS" "Default" "$ICON_DNS"
fi

get_json_results
