#!/bin/bash

. src/helpers.sh

LIST=$(networksetup -listallhardwareports)
INTERFACE=$(get_ethernet_interface "$LIST")
NAME=$(get_ethernet_name "$LIST")
