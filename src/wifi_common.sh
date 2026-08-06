#!/bin/bash

. src/helpers.sh

LIST=$(networksetup -listallhardwareports)
INTERFACE=$(get_wifi_interface "$LIST")
NAME=$(get_wifi_name "$LIST")
