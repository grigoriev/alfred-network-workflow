#!/usr/bin/env bats

. src/helpers.sh
load variables

@test "get_ethernet_state: get ethernet state" {
  run get_ethernet_state en4
  [ "$status" -eq 0 ]
  [ "$output" = 1 -o "$output" = 0 ]
}

@test "get_ethernet_name: get name" {
  run get_ethernet_name "$LIST"
  [ "$status" -eq 0 ]
  [ "$output" = "Thunderbolt Ethernet" ]
}

@test "get_ethernet_name: get ax name" {
  run get_ethernet_name "$LIST3"
  [ "$status" -eq 0 ]
  [ "$output" = "AX88179A" ]
}

@test "get_ethernet_interface: get interface Thunderbolt" {
  run get_ethernet_interface "$LIST"
  [ "$status" -eq 0 ]
  [ "$output" = "en4" ]
}

@test "get_ethernet_interface: get interface USB" {
  run get_ethernet_interface "$LIST2"
  [ "$status" -eq 0 ]
  [ "$output" = "en7" ]
}

@test "get_ethernet_mac: get mac address" {
  run get_ethernet_mac "$LIST"
  [ "$status" -eq 0 ]
  [ "$output" = "40:0c:8d:00:ef:8c" ]
}
