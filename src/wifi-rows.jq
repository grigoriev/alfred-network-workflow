# Turn tab-separated scan rows on stdin into a JSON array of network objects.
[inputs | split("\t")
  | {section:.[0], ssid:.[1], channel:(.[2]|tonumber? // 0),
     security:.[3], rssi:(.[4]|tonumber? // 0)}]
