// Scans Wi-Fi networks with CoreWLAN via osascript. Unlike a compiled helper,
// the Apple-signed osascript context can read SSIDs on macOS 14+ without a
// Location prompt or code signing. Prints a JSON array of networks:
//   [{ "section": "current"|"other", "ssid", "channel", "security", "rssi" }]
// which the caller turns into lines with jq.
// The connected network is marked "current" by matching the interface channel
// and closest signal, because its SSID is not otherwise exposed.
//
// Set WIFI_SCAN_TEST to a JSON {networks, curChan, curRssi} to feed test data
// instead of scanning, so the selection and formatting logic stays testable.
ObjC.import('CoreWLAN');
ObjC.import('Foundation');

function security(n) {
  if (n.supportsSecurity(0)) return 'None';                       // CWSecurityNone
  if (n.supportsSecurity(11) || n.supportsSecurity(13)) return 'WPA3 Personal';
  if (n.supportsSecurity(4)) return 'WPA2 Personal';
  if (n.supportsSecurity(2)) return 'WPA Personal';
  if (n.supportsSecurity(1)) return 'WEP';
  return 'Secured';
}

// Read Wi-Fi state, either from the test hook or CoreWLAN.
// Returns { networks: [{ssid, ch, sec, rssi}], curChan, curRssi }.
function scan() {
  var test = $.NSProcessInfo.processInfo.environment.objectForKey('WIFI_SCAN_TEST');
  if (!test.isNil()) return JSON.parse(test.js);

  var iface = $.CWWiFiClient.sharedWiFiClient.interface;
  if (iface.isNil()) return { networks: [], curChan: -1, curRssi: 0 };

  var networks = [];
  var err = $();
  var nets = iface.scanForNetworksWithNameError(undefined, err);
  if (!nets.isNil()) {
    var arr = nets.allObjects;
    for (var i = 0; i < arr.count; i++) {
      var n = arr.objectAtIndex(i);
      networks.push({
        ssid: n.ssid.isNil() ? '' : n.ssid.js,
        ch: n.wlanChannel.isNil() ? 0 : n.wlanChannel.channelNumber,
        sec: security(n),
        rssi: n.rssiValue
      });
    }
  }
  return {
    networks: networks,
    curChan: iface.wlanChannel.isNil() ? -1 : iface.wlanChannel.channelNumber,
    curRssi: iface.rssiValue
  };
}

// Mark the connected network (same channel, closest signal) and build JSON.
function build(data) {
  var list = data.networks;
  var current = -1, bestDiff = 1e9;
  if (data.curChan !== -1) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].ch === data.curChan) {
        var diff = Math.abs(list[i].rssi - data.curRssi);
        if (diff < bestDiff) { bestDiff = diff; current = i; }
      }
    }
  }
  var out = list.map(function (e, i) {
    return {
      section: (i === current) ? 'current' : 'other',
      ssid: e.ssid,
      channel: e.ch,
      security: e.sec,
      rssi: e.rssi
    };
  });
  return JSON.stringify(out);
}

function run() {
  return build(scan());
}
