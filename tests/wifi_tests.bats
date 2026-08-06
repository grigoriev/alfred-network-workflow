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

@test "getIPv4: get IPv4" {
  run getIPv4 "$NETINFO"
  [ "$output" = "192.168.1.100" ]
}

@test "getIPv6: get non-existing IPv6" {
  run getIPv6 "$NETINFO"
  [ "$output" = "" ]
}

@test "getIPv6: get existing IPv6" {
  run getIPv6 "IPv6 IP address: fe80::1"
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

@test "get_global_ip: get global IP" {
  run get_global_ip
  [[ "$output" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

@test "get_global_ip: handle invalid resolver" {
  run get_global_ip "non-existing"
  [[ "$output" = "" ]]
}

@test "get_vpn: get connected VPN" {
  run get_vpn "$SCUTIL"
  [ "$output" = "Test-VPN" ]
}
