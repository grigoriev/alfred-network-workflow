#!/usr/bin/env bats

# Tests for the CoreWLAN scanner (src/wifi-scan.js). WIFI_SCAN_TEST feeds the
# script fixed input instead of scanning, so its current-network selection and
# JSON output are tested without real Wi-Fi hardware. Uses the real osascript
# and jq (no mocks).

@test "wifi-scan.js: outputs valid json" {
  export WIFI_SCAN_TEST='{"networks":[{"ssid":"A","ch":6,"sec":"None","rssi":-60}],"curChan":-1,"curRssi":0}'
  run osascript -l JavaScript src/wifi-scan.js
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
}

@test "wifi-scan.js: passes network fields through" {
  export WIFI_SCAN_TEST='{"networks":[{"ssid":"Cafe","ch":40,"sec":"WPA2 Personal","rssi":-70}],"curChan":-1,"curRssi":0}'
  run osascript -l JavaScript src/wifi-scan.js
  echo "$output" | jq -e '.[0] | .section=="other" and .ssid=="Cafe" and .channel==40 and .security=="WPA2 Personal" and .rssi==-70' >/dev/null
}

@test "wifi-scan.js: marks the current network by channel and closest signal" {
  export WIFI_SCAN_TEST='{"networks":[{"ssid":"Home","ch":6,"sec":"WPA2 Personal","rssi":-55},{"ssid":"Cafe","ch":40,"sec":"None","rssi":-70},{"ssid":"Other6","ch":6,"sec":"None","rssi":-85}],"curChan":6,"curRssi":-54}'
  run osascript -l JavaScript src/wifi-scan.js
  echo "$output" | jq -e '.[0].section=="current" and .[0].ssid=="Home"' >/dev/null
  echo "$output" | jq -e '[.[] | select(.section=="current")] | length == 1' >/dev/null
}

@test "wifi-scan.js: no current network when the channel does not match" {
  export WIFI_SCAN_TEST='{"networks":[{"ssid":"A","ch":11,"sec":"None","rssi":-60}],"curChan":36,"curRssi":-50}'
  run osascript -l JavaScript src/wifi-scan.js
  echo "$output" | jq -e 'all(.section=="other")' >/dev/null
}

@test "wifi-scan.js: empty scan yields an empty array" {
  export WIFI_SCAN_TEST='{"networks":[],"curChan":-1,"curRssi":0}'
  run osascript -l JavaScript src/wifi-scan.js
  [ "$output" == "[]" ]
}