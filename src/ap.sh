#!/bin/bash

. src/wifi_common.sh
. src/workflow_handler.sh

# Handle action
if [[ "$1" != "" ]]; then
  if [[ "$1" == "Null" ]]; then
    exit
  fi

  if [[ "$1" == "LOCATION" ]]; then
    open_location_settings
    exit
  fi

  # Extract password for AP, which is needed by networksetup.
  # security prints the password to stderr, so send stderr down the pipe
  # and discard stdout. The redirect order is intentional.
  # shellcheck disable=SC2069
  PASS=$(security 2>&1 >/dev/null find-generic-password -ga "$1" \
    | awk '/ / {print $2}' | tr -d '"')
  networksetup -setairportnetwork "$INTERFACE" "$1" "$PASS"
  exit
fi

# Guard against a Mac without Wi-Fi hardware
if [[ -z "$INTERFACE" ]]; then
  add_result "" "" "No Wi-Fi interface found" "This Mac has no Wi-Fi hardware" "$ICON_WIFI_ERROR" "no"
  get_json_results
  exit
fi

# The scan takes a few seconds. On the first pass show a placeholder and
# ask Alfred to re-run, so the scan runs while "Scanning" is on screen.
if [[ -z "$ap_scanning" ]]; then
  add_result "" "" "Scanning for Wi-Fi networks…" "This can take a few seconds" "$ICON_WIFI" "no"
  set_rerun 0.1
  add_variable ap_scanning 1
  get_json_results
  exit
fi

# Scan with the CoreWLAN helper (real names) or system_profiler (redacted).
# NETWORKS is a JSON array of { section, ssid, channel, security, rssi }.
# Export the saved networks so the scanner can pick the connected one.
SAVED_APS=$(networksetup -listpreferredwirelessnetworks "$INTERFACE")
export WIFI_SAVED="$SAVED_APS"
NETWORKS=$(scan_networks "$INTERFACE")

if [ "$(jq 'length' <<< "$NETWORKS")" == "0" ]; then
  # Handle no wifi access points found
  add_result "" "Null" "No access points found" "" "$ICON_WIFI_ERROR"
  get_json_results
  exit
fi

# macOS hides network names unless the app reading Wi-Fi has Location access.
# Channel, security and signal still show for each network. Add a hint row.
HINT="[]"
if jq -e 'any(.[]; .ssid == "<redacted>")' >/dev/null <<< "$NETWORKS"; then
  HINT=$(jq -nc --arg prefix "$ARG_PREFIX" --arg icon "$ICON_WIFI_ERROR" \
    '[{title: "Wi-Fi names hidden by macOS",
       subtitle: "Press ⏎ to open Location Services, then enable it for Alfred",
       arg: ($prefix + "LOCATION"), valid: true, icon: {path: $icon}}]')
fi

# Build every network row in a single jq pass, then append it to the hint.
ITEMS=$(build_wifi_items "$NETWORKS" "$SAVED_APS")
jq -cn --argjson hint "$HINT" --argjson items "$ITEMS" '{items: ($hint + $items)}'
