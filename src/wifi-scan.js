// Scans Wi-Fi networks with CoreWLAN via osascript. Unlike a compiled helper,
// the Apple-signed osascript context can read SSIDs on macOS 14+ without a
// Location prompt or code signing. Prints one line per network:
//   SECTION~SSID~CHANNEL~SECURITY~RSSI
ObjC.import('CoreWLAN');

function security(n) {
  if (n.supportsSecurity(0)) return 'None';                       // CWSecurityNone
  if (n.supportsSecurity(11) || n.supportsSecurity(13)) return 'WPA3 Personal';
  if (n.supportsSecurity(4)) return 'WPA2 Personal';
  if (n.supportsSecurity(2)) return 'WPA Personal';
  if (n.supportsSecurity(1)) return 'WEP';
  return 'Secured';
}

function run() {
  var iface = $.CWWiFiClient.sharedWiFiClient.interface;
  if (iface.isNil()) return '';
  var cur = iface.ssid;
  var currentSSID = cur.isNil() ? null : cur.js;
  var err = $();
  var nets = iface.scanForNetworksWithNameError(undefined, err);
  var out = [];
  if (!nets.isNil()) {
    var arr = nets.allObjects;
    for (var i = 0; i < arr.count; i++) {
      var n = arr.objectAtIndex(i);
      var ssid = n.ssid.isNil() ? '' : n.ssid.js;
      var ch = n.wlanChannel.isNil() ? 0 : n.wlanChannel.channelNumber;
      var section = (ssid && ssid === currentSSID) ? 'current' : 'other';
      out.push([section, ssid, ch, security(n), n.rssiValue].join('~'));
    }
  }
  return out.join('\n');
}
