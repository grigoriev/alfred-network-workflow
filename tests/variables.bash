#!/bin/bash

LIST="
Hardware Port: Thunderbolt Ethernet
Device: en4
Ethernet Address: 40:0c:8d:00:ef:8c

Hardware Port: Wi-Fi
Device: en0
Ethernet Address: f8:06:c1:00:a3:cc

Hardware Port: Bluetooth PAN
Device: en3
Ethernet Address: b7:06:b1:01:a2:ce

Hardware Port: Thunderbolt 1
Device: en1
Ethernet Address: f2:00:11:48:00:20

Hardware Port: Thunderbolt 2
Device: en2
Ethernet Address: f2:00:12:48:50:22

Hardware Port: Thunderbolt Bridge
Device: bridge0
Ethernet Address: cc:f6:b1:77:f7:02

VLAN Configurations
==================="

LIST2="
Hardware Port: USB 10/100/1000 LAN
Device: en7
Ethernet Address: de:ad:be:ef:fe:ed

Hardware Port: Wi-Fi
Device: en0
Ethernet Address: f8:06:c1:00:a3:cc

VLAN Configurations
==================="

LIST3="
Hardware Port: Wi-Fi
Device: en1
Ethernet Address: f8:06:c1:00:a3:cc

Hardware Port: AX88179A
Device: en3
Ethernet Address: de:ad:be:ef:fe:ed

Hardware Port: Ethernet Adapter (en4)
Device: en4
Ethernet Address: de:ad:be:ef:fe:ee

VLAN Configurations
==================="

NETINFO='DHCP Configuration
IP address: 192.168.1.100
Subnet mask: 255.255.255.0
Router: 192.168.1.1
Client ID:
IPv6: Automatic
IPv6 IP address: none
IPv6 Router: none
Wi-Fi ID: f8:06:c1:00:a3:cc'

SUMMARY='<dictionary> {
  BSSID : c8:07:19:2c:00:6f
  ConnectionID : 29
  InterfaceType : WiFi
  LinkStatusActive : TRUE
  NetworkID : ABCD1234
  SSID : Test-Network
  Security : WPA2
}'

SUMMARY_REDACTED='<dictionary> {
  BSSID : <redacted>
  InterfaceType : WiFi
  NetworkID : <redacted>
  SSID : <redacted>
  Security : NONE
}'

SCUTIL='Available network connection services in the current set (*=enabled):
* (Disconnected)   9798DAED-21C7-44A1-B382-EFCE7E1373F1 PPP --> Modem (usbmodem1411) "Arduino Uno"                    [PPP:Modem]
* (Disconnected)   CBA1BCD8-D18D-4241-9EF4-5656AF89F09B PPP --> Modem (usbserial) "USB-Serial Controller D"        [PPP:Modem]
* (Disconnected)   F9BABC6E-649F-4113-95BC-94E1467FCBE8 PPP --> Modem (usbmodem1d112) "SAMSUNG_Android"                [PPP:Modem]
* (Connected)   65F5A798-4B98-4DA1-87D8-9D605FFF6188 PPP --> L2TP       "Test-VPN"                      [PPP:L2TP]'

DNS="8.8.8.8
8.8.4.4
192.168.1.1"

SAVED_APS="	Test-Network
	Test-Network2
	Martins iPhone"

AP_LIST="foo
  bar baz
  qux"

SCAN='Wi-Fi:

      Interfaces:
        en0:
          Status: Connected
          Current Network Information:
            HomeNet:
              PHY Mode: 802.11ax
              Channel: 36 (5GHz, 80MHz)
              Security: WPA2 Personal
              Signal / Noise: -45 dBm / -90 dBm
          Other Local Wi-Fi Networks:
            CoffeeShop:
              PHY Mode: 802.11ac
              Channel: 40 (5GHz, 40MHz)
              Security: None
            Neighbor 5G:
              PHY Mode: 802.11ac
              Channel: 132 (5GHz, 40MHz)
              Security: WPA2 Personal
              Signal / Noise: -72 dBm / -95 dBm
        awdl0:
          Current Network Information:
              Network Type: Infrastructure'

SCAN_REDACTED='Wi-Fi:

      Interfaces:
        en0:
          Current Network Information:
            <redacted>:
              PHY Mode: 802.11n
              Channel: 6 (2GHz, 20MHz)
              Security: None
          Other Local Wi-Fi Networks:
            <redacted>:
              PHY Mode: 802.11ac
              Channel: 40 (5GHz, 40MHz)
              Security: WPA2 Personal'
