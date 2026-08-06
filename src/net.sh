#!/bin/bash

. src/workflow_handler.sh
. src/media.sh

# Single entry point. Every command lives under the "net" keyword:
#   net            -> catalog of commands
#   net vpn        -> the VPN command, and so on
# Called two ways from Alfred:
#   list mode (Script Filter): . src/net.sh list "{query}"
#   run mode  (Run Script):    . src/net.sh run  "{query}"

MODE="$1"
QUERY="$2"
CMD="${QUERY%% *}"
REST="${QUERY#"$CMD"}"
REST="${REST# }"

SUBCOMMANDS="wifi eth wifilist vpn dns update"

is_subcommand() {
  local s
  for s in $SUBCOMMANDS; do
    [[ "$s" == "$1" ]] && return 0
  done
  return 1
}

# Add a catalog entry when its subcommand matches the filter prefix
# $1 subcommand  $2 filter  $3 title  $4 subtitle  $5 icon  $6 autocomplete
cat_item() {
  case "$1" in
    "$2"*) add_result "" "" "$3" "$4" "$5" "no" "$6" ;;
  esac
}

# Catalog of commands, optionally filtered by a subcommand prefix
# $1 = filter (may be empty)
catalog() {
  local f="$1"
  cat_item wifi     "$f" "Wi-Fi"      "Show Wi-Fi info and toggle it on or off"        "$ICON_WIFI" "wifi "
  cat_item eth      "$f" "Ethernet"   "Show Ethernet info"                             "$ICON_ETH"  "eth "
  cat_item wifilist "$f" "Wi-Fi List" "Scan for nearby Wi-Fi networks"                 "$ICON_WIFI" "wifilist "
  cat_item vpn      "$f" "VPN"        "List configured VPNs and connect"               "$ICON_VPN"  "vpn "
  cat_item dns      "$f" "DNS"        "List and change DNS for the primary connection" "$ICON_DNS"  "dns "
  cat_item update   "$f" "Update"     "Check for and install workflow updates"         "icon.png"   "update "
  get_json_results
}

# Run the action for a selected item
if [[ "$MODE" == "run" ]]; then
  case "$CMD" in
    wifi)     . src/wifi.sh "$REST" ;;
    eth)      . src/ethernet.sh "$REST" ;;
    wifilist) . src/ap.sh "$REST" ;;
    vpn)      . src/vpn.sh "$REST" ;;
    dns)      . src/dns.sh "$REST" ;;
    http://*|https://*) . src/update.sh "$QUERY" ;;
  esac
  exit
fi

# List mode
if [[ -z "$CMD" ]]; then
  catalog ""
elif is_subcommand "$CMD"; then
  if [[ "$CMD" == "update" ]]; then
    # The shared updater builds its own arg (a download URL), so no prefix
    . src/update.sh "$REST"
  else
    ARG_PREFIX="$CMD "
    case "$CMD" in
      wifi)     . src/wifi.sh "$REST" ;;
      eth)      . src/ethernet.sh "$REST" ;;
      wifilist) . src/ap.sh "$REST" ;;
      vpn)      . src/vpn.sh "$REST" ;;
      dns)      . src/dns.sh "$REST" ;;
    esac
  fi
else
  catalog "$CMD"
fi
