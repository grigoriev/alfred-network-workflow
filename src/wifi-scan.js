// Scans Wi-Fi networks with CoreWLAN via osascript. Unlike a compiled helper,
// the Apple-signed osascript context can read SSIDs on macOS 14+ without a
// Location prompt or code signing. Prints a JSON array of networks:
//   [{ "section": "current"|"other", "ssid", "channel", "security", "rssi" }]
// which the caller turns into lines with jq.
// The connected network is marked "current" by matching the interface channel
// and closest signal, because its SSID is not otherwise exposed.
//
// The first argument picks the source:
//   (default)  a live scan, which takes a few seconds (net wifilist).
//   "cached"   the last scan the OS cached, which is instant and enough to
//              read the current network name (net wifi). Returns an empty list
//              when the cache is empty, so the caller can show a placeholder.
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

// Turn an NSSet of CWNetwork into [{ssid, ch, sec, rssi}].
function mapNetworks(nets) {
  var out = [];
  if (nets.isNil()) return out;
  var arr = nets.allObjects;
  for (var i = 0; i < arr.count; i++) {
    var n = arr.objectAtIndex(i);
    out.push({
      ssid: n.ssid.isNil() ? '' : n.ssid.js,
      ch: n.wlanChannel.isNil() ? 0 : Number(n.wlanChannel.channelNumber),
      sec: security(n),
      rssi: Number(n.rssiValue)
    });
  }
  return out;
}

// Read Wi-Fi state, either from the test hook or CoreWLAN.
// Returns { networks: [{ssid, ch, sec, rssi}], curChan, curRssi }.
function scan(mode) {
  var test = $.NSProcessInfo.processInfo.environment.objectForKey('WIFI_SCAN_TEST');
  if (!test.isNil()) return JSON.parse(test.js);

  var iface = $.CWWiFiClient.sharedWiFiClient.interface;
  if (iface.isNil()) return { networks: [], curChan: -1, curRssi: 0 };

  var networks;
  if (mode === 'cached') {
    networks = mapNetworks(iface.cachedScanResults);
  }
  if (!networks || networks.length === 0) {
    var err = $();
    networks = mapNetworks(iface.scanForNetworksWithNameError(undefined, err));
  }
  return {
    networks: networks,
    curChan: iface.wlanChannel.isNil() ? -1 : Number(iface.wlanChannel.channelNumber),
    curRssi: Number(iface.rssiValue)
  };
}

// Identify the connected network. Its SSID is redacted, so match on the
// interface channel. Dense areas (a hotel) put many APs on one channel, so:
//   1. never pick an empty (hidden) SSID,
//   2. prefer a saved network, because you connect to ones you have joined,
//   3. break ties by the signal closest to the interface RSSI.
// Returns the index in list, or -1 when nothing usable matches.
function pickCurrent(list, curChan, curRssi, saved) {
  if (curChan === -1) return -1;
  var cands = [];
  for (var i = 0; i < list.length; i++) {
    if (list[i].ch === curChan && list[i].ssid !== '') cands.push(i);
  }
  if (cands.length === 0) return -1;
  var pool = cands.filter(function (i) { return saved.includes(list[i].ssid); });
  if (pool.length === 0) pool = cands;
  var best = -1, bestDiff = 1e9;
  for (var idx of pool) {
    var diff = Math.abs(list[idx].rssi - curRssi);
    if (diff < bestDiff) { bestDiff = diff; best = idx; }
  }
  return best;
}

// Mark the connected network and build the JSON array.
function build(data, saved) {
  var list = data.networks;
  var current = pickCurrent(list, data.curChan, data.curRssi, saved || []);
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

// Saved (preferred) network names, passed from the shell as newline text.
function savedNetworks() {
  var v = $.NSProcessInfo.processInfo.environment.objectForKey('WIFI_SAVED');
  if (v.isNil()) return [];
  return v.js.split('\n').map(function (s) { return s.trim(); })
    .filter(function (s) { return s !== ''; });
}

function run(argv) {
  return build(scan(argv[0]), savedNetworks());
}
