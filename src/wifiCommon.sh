#!/bin/bash

. src/helpers.sh

LIST=$(networksetup -listallhardwareports)
INTERFACE=$(getWifiInterface "$LIST")
NAME=$(getWifiName "$LIST")
