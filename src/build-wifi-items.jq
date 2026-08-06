def strength(r):
  if r == null then 4
  elif r < -80 then 1
  elif r < -70 then 2
  elif r < -60 then 3
  else 4 end;
[ .[]
  | select(.ssid != "")
  | . as $n
  | (if $n.section == "current" then {p: $high, base: $active}
     elif ($saved | index($n.ssid)) then {p: $medium, base: $star}
     elif ($n.security == "None" or $n.security == "") then {p: $low, base: $open}
     else {p: $low, base: $lock} end) as $c
  | {p: $c.p, n: $n, icon: ($c.base + (strength($n.rssi) | tostring) + $end)} ]
| sort_by(.p)
| [ .[]
    | .n as $n
    | {title: (if $n.ssid == "<redacted>" then "Hidden network" else $n.ssid end),
       subtitle: (
         (if ($n.rssi != 0 and $n.rssi != null) then "RSSI " + ($n.rssi | tostring) + " dBm, " else "" end)
         + "channel " + ($n.channel | tostring)
         + (if ($n.security != "" and $n.security != null) then ", " + $n.security else "" end)),
       arg: (if $n.ssid == "<redacted>" then "" else $prefix + $n.ssid end),
       valid: ($n.ssid != "<redacted>"),
       icon: {path: .icon}} ]
