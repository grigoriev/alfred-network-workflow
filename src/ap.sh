#!/bin/bash

. src/wifiCommon.sh
. src/workflowHandler.sh

# Handle action
if [ "$1" != "" ]; then
  if [ "$1" == "Null" ]; then
    exit
  fi

  if [ "$1" == "LOCATION" ]; then
    openLocationSettings
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
if [ -z "$INTERFACE" ]; then
  addResult "" "" "No Wi-Fi interface found" "This Mac has no Wi-Fi hardware" "$ICON_WIFI_ERROR" "no"
  getJSONResults
  exit
fi

# The scan takes a few seconds. On the first pass show a placeholder and
# ask Alfred to re-run, so the scan runs while "Scanning" is on screen.
if [ -z "$ap_scanning" ]; then
  addResult "" "" "Scanning for Wi-Fi networks…" "This can take a few seconds" "$ICON_WIFI" "no"
  setRerun 0.1
  addVariable ap_scanning 1
  getJSONResults
  exit
fi

# Scan with the CoreWLAN helper (real names) or system_profiler (redacted).
# NETWORKS is a JSON array of { section, ssid, channel, security, rssi }.
# Export the saved networks so the scanner can pick the connected one.
SAVED_APS=$(networksetup -listpreferredwirelessnetworks "$INTERFACE")
export WIFI_SAVED="$SAVED_APS"
NETWORKS=$(scanNetworks "$INTERFACE")

if [ "$(jq 'length' <<< "$NETWORKS")" == "0" ]; then
  # Handle no wifi access points found
  addResult "" "Null" "No access points found" "" "$ICON_WIFI_ERROR"
else
  # macOS hides network names unless the app reading Wi-Fi has Location
  # access. Channel, security and signal still show for each network.
  if jq -e 'any(.[]; .ssid == "<redacted>")' >/dev/null <<< "$NETWORKS"; then
    addResult "" "LOCATION" "Wi-Fi names hidden by macOS" \
      "Press ⏎ to open Location Services, then enable it for Alfred" "$ICON_WIFI_ERROR"
  fi

  # Annotate each network with a priority and icon, then sort by priority
  ANNOTATED=$(
    while IFS= read -r NET; do
      getScanDetails "$NET" "$SAVED_APS"
    done <<< "$(jq -c '.[]' <<< "$NETWORKS")" | jq -sc 'sort_by(.priority)'
  )

  while IFS= read -r ITEM; do
    [ -z "$ITEM" ] && continue
    SSID=$(jq -r '.ssid' <<< "$ITEM")
    CHANNEL=$(jq -r '.channel' <<< "$ITEM")
    SECURITY=$(jq -r '.security' <<< "$ITEM")
    RSSI=$(jq -r '.rssi' <<< "$ITEM")
    ICON=$(jq -r '.icon' <<< "$ITEM")

    SUBTITLE="channel $CHANNEL"
    if [ "$RSSI" != "0" ]; then
      SUBTITLE="RSSI $RSSI dBm, $SUBTITLE"
    fi
    if [ "$SECURITY" != "" ]; then
      SUBTITLE="$SUBTITLE, $SECURITY"
    fi

    if [ "$SSID" == "<redacted>" ]; then
      # No usable name to connect with, so make it a non-actionable row
      addResult "" "" "Hidden network" "$SUBTITLE" "$ICON" "no"
    else
      addResult "" "$SSID" "$SSID" "$SUBTITLE" "$ICON"
    fi
  done <<< "$(jq -c '.[]' <<< "$ANNOTATED")"
fi

getJSONResults
