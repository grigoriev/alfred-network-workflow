#!/bin/bash

. src/workflow_handler.sh
. src/helpers.sh

# Handle action
if [[ "$1" != "" ]]; then
  is_connected=$([[ -z "$(scutil --nc status "$1" | head -n 1 | grep Connected)" ]] && echo 0 || echo 1)
  if [[ "$is_connected" -eq 1 ]]; then
    scutil --nc stop "$1"
  else
    if scutil --nc show "$1" | head -1 | grep -q PPP:L2TP; then
      networksetup -connectpppoeservice "$1"
    else
      scutil --nc start "$1"
    fi
  fi

  exit
fi

while read -r LINE; do
  OUTPUT="$(get_vpn_info "$LINE")"
  IFS='~' read -r -a ARRAY <<< "$OUTPUT"

  add_result "" "${ARRAY[1]}" "${ARRAY[1]}" "${ARRAY[2]} (${ARRAY[0]})" "${ARRAY[3]}"
done <<< "$(echo "$(scutil --nc list)" | awk 'NR>1')"

get_json_results
