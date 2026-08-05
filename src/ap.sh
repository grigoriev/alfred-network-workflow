#!/bin/bash

. src/wifiCommon.sh
. src/workflowHandler.sh

# Handle action
if [ "$1" != "" ]; then
  if [ "$1" == "Null" ]; then
    exit
  fi

  # Extract password for AP, which is needed by networksetup
  PASS=$(security 2>&1 >/dev/null find-generic-password -ga "$1" \
    | awk '/ / {print $2}' | tr -d '"')
  networksetup -setairportnetwork "$INTERFACE" "$1" "$PASS"
  exit
fi

# airport was removed in macOS 14.4, so scan with system_profiler
SCAN=$(system_profiler SPAirPortDataType 2>/dev/null)
SAVED_APS=$(networksetup -listpreferredwirelessnetworks "$INTERFACE")

ACTIVE_ID=$(getActiveScanSSID "$SCAN" "$INTERFACE")
NETWORKS=$(parseScanResults "$SCAN" "$INTERFACE")

if [ "$NETWORKS" == "" ]; then
  # Handle no wifi access points found
  addResult "" "Null" "No access points found" "" "$ICON_WIFI_ERROR"
elif [ "$(echo "$NETWORKS" | grep -vc '<redacted>')" == "0" ]; then
  # macOS hides network names until the workflow is granted Location access
  addResult "" "Null" "Grant Location access to see Wi-Fi names" \
    "System Settings > Privacy & Security > Location Services > System Services" "$ICON_WIFI_ERROR"
else
  PARSED_APS=''

  # Build details from each scan tuple
  while read -r LINE; do
    PARSED_APS+=$(getScanDetails "$LINE" "$ACTIVE_ID" "$SAVED_APS")$'\n'
  done <<< "$NETWORKS"

  # Sort by priority and name, drop duplicates
  PARSED_APS=$(echo "$PARSED_APS" | sort -u)

  # Create workflow results from each line
  while read -r LINE; do
    IFS='~' read -r -a ARRAY <<< "$LINE"

    if [ "${ARRAY[0]}" != "" ]; then
      SUBTITLE="channel ${ARRAY[4]}"
      if [ "${ARRAY[3]}" != "" ]; then
        SUBTITLE="RSSI ${ARRAY[3]} dBm, $SUBTITLE"
      fi
      if [ "${ARRAY[5]}" != "" ]; then
        SUBTITLE="$SUBTITLE, ${ARRAY[5]}"
      fi
      addResult "" "${ARRAY[1]}" "${ARRAY[1]}" "$SUBTITLE" "${ARRAY[6]}"
    fi
  done <<< "$PARSED_APS"
fi

getXMLResults
