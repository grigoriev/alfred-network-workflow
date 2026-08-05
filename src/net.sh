#!/bin/bash

. src/workflowHandler.sh
. src/media.sh

# Hub menu: list every command. Selecting one autocompletes to its keyword
# (press Tab), so "net" is a single entry point that discovers everything.
# addResult args: uid arg title subtitle icon valid autocomplete

addResult "" "" "Wi-Fi" "Show Wi-Fi info and toggle it on or off" "$ICON_WIFI" "no" "wifi "
addResult "" "" "Ethernet" "Show Ethernet info" "$ICON_ETH" "no" "eth "
addResult "" "" "Wi-Fi List" "Scan for nearby Wi-Fi networks" "$ICON_WIFI" "no" "wifilist "
addResult "" "" "VPN" "List configured VPNs and connect" "$ICON_VPN" "no" "vpn "
addResult "" "" "DNS" "List and change DNS for the primary connection" "$ICON_DNS" "no" "dns "
addResult "" "" "Update" "Check for and install workflow updates" "icon.png" "no" "update "

getJSONResults
