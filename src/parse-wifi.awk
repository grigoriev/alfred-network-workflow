# Parse `system_profiler SPAirPortDataType` output into tab-separated rows:
# section, ssid, channel, security, rssi. Scoped to the Wi-Fi interface (-v iface).
function flush() {
  if (ssid != "") { printf "%s\t%s\t%s\t%s\t%s\n", section, ssid, channel, security, rssi }
  ssid=""; channel=""; security=""; rssi=""
}
# Interface header (8 spaces): scope parsing to the Wi-Fi interface
/^        [A-Za-z0-9]+:$/ {
  flush(); cur = $1; sub(/:$/, "", cur); inIface = (cur == iface); section=""; next
}
!inIface { next }
# Section headers (10 spaces)
/^          Current Network Information:/ { flush(); section="current"; next }
/^          Other Local Wi-Fi Networks:/ { flush(); section="other"; next }
/^          [A-Za-z].*:$/ { flush(); section=""; next }
section=="" { next }
# Network fields (14 spaces)
/^              Channel:/ { l=$0; sub(/^ *Channel: */,"",l); split(l,a," "); channel=a[1]; next }
/^              Security:/ { l=$0; sub(/^ *Security: */,"",l); security=l; next }
/^              Signal . Noise:/ { l=$0; sub(/^ *Signal \/ Noise: */,"",l); split(l,a," "); rssi=a[1]; next }
/^              / { next }
# Network name header (12 spaces, ends with a colon)
/^            .*:$/ { flush(); s=$0; sub(/^ */,"",s); sub(/:$/,"",s); ssid=s; next }
END { flush() }
