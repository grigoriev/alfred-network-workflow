#!/bin/bash

. src/ethernet_common.sh
. src/workflow_handler.sh

# Handle action
if [[ "$1" != "" ]]; then
  echo "$1" | tr -d '\n'
  exit
fi

# Handle ethernet unconnected state
if [[ "$(get_ethernet_state "$INTERFACE")" == 0 ]]; then
  add_result "" "" "Not Connected" "Ethernet is not connected" "$ICON_ETH"
  get_json_results
  return
fi

# Get network configuration
NETINFO=$(networksetup -getinfo "$NAME")
NETCONFIG=$(get_connection_config "$NETINFO")

MAC=$(get_ethernet_mac)
NAME=$(get_ethernet_name)

# Output IPv4
IPv4=$(get_ipv4 "$NETINFO")
if [[ ! -z "$IPv4" ]]; then
  add_result "" "$IPv4" "$IPv4" "IPv4 address ($NETCONFIG)" "$ICON_ETH"
fi

# Output IPv6
IPv6=$(get_ipv6 "$NETINFO")
if [[ "$IPv6" != "" ]]; then
  add_result "" "$IPv6" "$IPv6" "IPv6 address ($NETCONFIG)" "$ICON_ETH"
fi

# Output global IP
GLOBALIP=$(get_global_ip)
if [[ "$GLOBALIP" != "" ]]; then
  add_result "" "$GLOBALIP" "$GLOBALIP" "Global IP" "$ICON_ETH"
fi

# Output VPN
SCUTIL=$(scutil --nc list)
VPN=$(get_vpn "$SCUTIL")
if [[ "$VPN" != "" ]]; then
  add_result "" "$VPN" "$VPN" "VPN connection" "$ICON_ETH"
fi

# Output DNS list
DNSSTRING=$(get_dns "$(networksetup -getdnsservers "$NAME")")
if [[ "$DNSSTRING" != "" ]]; then
  add_result "" "$DNSSTRING" "$DNSSTRING" "DNS list" "$ICON_ETH"
fi

add_result "" "" "$NAME connected" "$INTERFACE ($MAC)" "$ICON_ETH"

get_json_results
