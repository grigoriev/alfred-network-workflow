#!/usr/bin/env bats

. src/helpers.sh
load variables

@test "get_wifi_state: get wifi state" {
  run get_wifi_state en0
  [ "$status" -eq 0 ]
  [ "$output" = 1 -o "$output" = 0 ]
}

@test "get_wifi_name: get name" {
  run get_wifi_name "$LIST"
  [ "$status" -eq 0 ]
  [ "$output" = "Wi-Fi" ]
}

@test "get_wifi_interface: get interface" {
  run get_wifi_interface "$LIST"
  [ "$status" -eq 0 ]
  [ "$output" = "en0" ]
}

@test "get_wifi_mac: get mac address" {
  run get_wifi_mac "$LIST"
  [ "$status" -eq 0 ]
  [ "$output" = "f8:06:c1:00:a3:cc" ]
}

@test "get_connection_config: get connection config" {
  run get_connection_config "$NETINFO"
  [ "$output" = "DHCP Configuration" ]
}

@test "get_ipv4: get IPv4" {
  run get_ipv4 "$NETINFO"
  [ "$output" = "192.168.1.100" ]
}

@test "get_ipv6: get non-existing IPv6" {
  run get_ipv6 "$NETINFO"
  [ "$output" = "" ]
}

@test "get_ipv6: get existing IPv6" {
  run get_ipv6 "IPv6 IP address: fe80::1"
  [ "$output" = "fe80::1" ]
}

@test "get_summary_value: get SSID" {
  run get_summary_value "$SUMMARY" "SSID"
  [ "$output" = "Test-Network" ]
}

@test "get_summary_value: get BSSID" {
  run get_summary_value "$SUMMARY" "BSSID"
  [ "$output" = "c8:07:19:2c:00:6f" ]
}

@test "get_summary_value: get security" {
  run get_summary_value "$SUMMARY" "Security"
  [ "$output" = "WPA2" ]
}

@test "get_summary_value: missing key is empty" {
  run get_summary_value "$SUMMARY" "Channel"
  [ "$output" = "" ]
}

@test "get_summary_value: read redacted values" {
  run get_summary_value "$SUMMARY_REDACTED" "SSID"
  [ "$output" = "<redacted>" ]
}

# get_global_ip runs the dig mock from tests/mocks/bin, not a live query.

@test "get_global_ip: get global IP" {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export MOCK_DIG_ARGS="$BATS_TEST_TMPDIR/dig-args"
  run get_global_ip
  [ "$status" -eq 0 ]
  [ "$output" = "203.0.113.5" ]
  [ "$(cat "$MOCK_DIG_ARGS")" = "-4 +time=2 +tries=1 +short myip.opendns.com @resolver1.opendns.com" ]
}

@test "get_global_ip: pass a custom resolver to dig" {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export MOCK_DIG_ARGS="$BATS_TEST_TMPDIR/dig-args"
  export MOCK_DIG_OUTPUT="198.51.100.7"
  run get_global_ip "whoami.example @ns.example"
  [ "$output" = "198.51.100.7" ]
  [ "$(cat "$MOCK_DIG_ARGS")" = "-4 +time=2 +tries=1 +short whoami.example @ns.example" ]
}

@test "get_global_ip: handle invalid resolver" {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export MOCK_DIG_OUTPUT=";; communications error: no servers could be reached"
  run get_global_ip "non-existing"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "get_global_ip: handle an empty answer" {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export MOCK_DIG_OUTPUT=""
  run get_global_ip
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "get_global_ip: reject an answer that is not an IPv4 address" {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export MOCK_DIG_OUTPUT="myip.example."
  run get_global_ip
  [ "$output" = "" ]
}

@test "get_global_ip: live query to OpenDNS (LIVE_DNS_TEST=1)" {
  [[ "$LIVE_DNS_TEST" = "1" ]] || skip "set LIVE_DNS_TEST=1 to query OpenDNS"
  run get_global_ip
  [[ "$output" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

@test "get_vpn: get connected VPN" {
  run get_vpn "$SCUTIL"
  [ "$output" = "Test-VPN" ]
}
