#!/usr/bin/env bats

# Integration tests for the action scripts. Real system commands are
# replaced by the mocks under tests/mocks/bin (added to PATH), so the
# scripts run deterministically off canned fixtures.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
}

# --- wifi.sh ---------------------------------------------------------------

@test "wifi.sh: show connected info" {
  run bash -c '. src/wifi.sh'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "192.168.1.100" ]]
  [[ "$output" =~ "HomeNet" ]]
  [[ "$output" =~ "203.0.113.5" ]]
  [[ "$output" =~ "Turn Wi-Fi Off" ]]
}

@test "wifi.sh: wifi off shows turn on" {
  export MOCK_WIFI_POWER=Off
  run bash -c '. src/wifi.sh'
  [[ "$output" =~ "Turn Wi-Fi on" ]]
}

@test "wifi.sh: action toggles power" {
  run bash -c '. src/wifi.sh Off'
  [ "$status" -eq 0 ]
}

@test "wifi.sh: action echoes other arg" {
  run bash -c '. src/wifi.sh 10.0.0.1'
  [ "$output" == "10.0.0.1" ]
}

@test "wifi.sh: redacted ssid shows a non-actionable hint" {
  export MOCK_IP=redacted
  run bash -c '. src/wifi.sh'
  [[ "$output" =~ "hidden by macOS" ]]
  [[ ! "$output" =~ "LOCATION" ]]
}

@test "wifi.sh: shows IPv6 when present" {
  export MOCK_IPV6=yes
  run bash -c '. src/wifi.sh'
  [[ "$output" =~ "fe80::abcd" ]]
}

@test "wifi.sh: no wifi hardware" {
  export MOCK_WIFI=none
  run bash -c '. src/wifi.sh'
  [[ "$output" =~ "No Wi-Fi interface found" ]]
}

# --- ethernet.sh -----------------------------------------------------------

@test "ethernet.sh: show connected info" {
  run bash -c '. src/ethernet.sh'
  [[ "$output" =~ "192.168.1.100" ]]
  [[ "$output" =~ "Thunderbolt Ethernet connected" ]]
}

@test "ethernet.sh: not connected" {
  export MOCK_ETH=none
  run bash -c '. src/ethernet.sh'
  [[ "$output" =~ "Not Connected" ]]
}

@test "ethernet.sh: shows IPv6 when present" {
  export MOCK_IPV6=yes
  run bash -c '. src/ethernet.sh'
  [[ "$output" =~ "fe80::abcd" ]]
}

@test "ethernet.sh: action echoes arg" {
  run bash -c '. src/ethernet.sh 1.2.3.4'
  [ "$output" == "1.2.3.4" ]
}

# --- ap.sh (wifilist) ------------------------------------------------------

@test "ap.sh: first pass shows scanning and reruns" {
  run bash -c '. src/ap.sh'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Scanning for Wi-Fi networks" ]]
  [[ "$output" =~ '"rerun":' ]]
  [[ "$output" =~ '"ap_scanning":"1"' ]]
}

@test "ap.sh: list scanned networks" {
  export ap_scanning=1
  run bash -c '. src/ap.sh'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "HomeNet" ]]
  [[ "$output" =~ "CoffeeShop" ]]
}

@test "ap.sh: connect action reads keychain" {
  run bash -c '. src/ap.sh HomeNet'
  [ "$status" -eq 0 ]
}

@test "ap.sh: null action exits" {
  run bash -c '. src/ap.sh Null'
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
}

@test "ap.sh: redacted names show a hint and hidden networks" {
  export ap_scanning=1
  export MOCK_SPA=redacted
  run bash -c '. src/ap.sh'
  [[ "$output" =~ "hidden by macOS" ]]
  [[ "$output" =~ "Hidden network" ]]
  [[ ! "$output" =~ "LOCATION" ]]
}

@test "ap.sh: no networks found" {
  export ap_scanning=1
  export MOCK_SPA=empty
  run bash -c '. src/ap.sh'
  [[ "$output" =~ "No access points found" ]]
}

@test "ap.sh: no wifi hardware" {
  export MOCK_WIFI=none
  run bash -c '. src/ap.sh'
  [[ "$output" =~ "No Wi-Fi interface found" ]]
  [[ ! "$output" =~ "Scanning" ]]
}

# --- vpn.sh ----------------------------------------------------------------

@test "vpn.sh: list configured vpns" {
  run bash -c '. src/vpn.sh'
  [[ "$output" =~ "Test-VPN" ]]
  [[ "$output" =~ "Connected" ]]
}

@test "vpn.sh: disconnect a connected vpn" {
  export MOCK_VPN_STATUS=Connected
  run bash -c '. src/vpn.sh Test-VPN'
  [ "$status" -eq 0 ]
}

@test "vpn.sh: connect a disconnected l2tp vpn" {
  export MOCK_VPN_STATUS=Disconnected
  run bash -c '. src/vpn.sh Test-VPN'
  [ "$status" -eq 0 ]
}

@test "vpn.sh: start a disconnected non-l2tp vpn" {
  export MOCK_VPN_STATUS=Disconnected
  export MOCK_VPN_TYPE=other
  run bash -c '. src/vpn.sh Test-VPN'
  [ "$status" -eq 0 ]
}

# --- dns.sh ----------------------------------------------------------------

@test "dns.sh: list dns presets" {
  run bash -c '. src/dns.sh'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Google DNS" ]]
  [[ "$output" =~ "Cloudflare DNS" ]]
  [[ "$output" =~ "Default DNS" ]]
}

@test "dns.sh: edit action opens the config" {
  run bash -c '. src/dns.sh EDIT'
  [ "$status" -eq 0 ]
}

@test "dns.sh: default action resets dns" {
  run bash -c '. src/dns.sh DEFAULT'
  [ "$status" -eq 0 ]
}

@test "dns.sh: set a custom dns list" {
  run bash -c '. src/dns.sh "8.8.8.8 / 8.8.4.4"'
  [ "$status" -eq 0 ]
}

@test "dns.sh: primary interface falls back to wifi" {
  export MOCK_ETH=none
  run bash -c '. src/dns.sh'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Google DNS" ]]
}
