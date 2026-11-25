import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../provisioning/wifi_provisioner.dart';
import 'crc16.dart';

/// BluFi frame types: `subtype << 2 | kind`, where kind 0 is control and 1
/// is data (§8.2).
///
/// The phone never sends SET_WIFI_OPMODE (0x08), which restarts the radio,
/// STA_BSSID (0x05), DISCONNECT_BLE (0x20) or CUSTOM_DATA (0x4D).
abstract final class BlufiType {
  // Control frames.
  static const ack = 0x00;
  static const setSecurityMode = 0x04;
  static const connectToAp = 0x0C;
  static const getWifiStatus = 0x14;
  static const getVersion = 0x1C;
  static const getWifiList = 0x24;

  // Data frames.
  static const negotiate = 0x01;
  static const staSsid = 0x09;
  static const staPassword = 0x0D;
  static const wifiReport = 0x3D;
  static const replyVersion = 0x41;
  static const wifiList = 0x45;
  static const errorInfo = 0x49;

  static bool isData(int type) => (type & 0x03) == 0x01;
}

/// The frame control bits.
abstract final class BlufiFc {
  static const encrypted = 0x01;
  static const checksum = 0x02;

  /// Set on frames from the device to the phone.
  static const fromDevice = 0x04;

  /// The phone never sets it.
  static const ackRequested = 0x08;
  static const moreFragments = 0x10;
}

/// The SET_SEC_MODE byte the phone sends: the device's data frames are then
/// checksummed and encrypted, and its control frames stay as they are.
const int blufiSecurityMode = 0x03;

/// The station states of a WIFI_REP.
abstract final class BlufiStaState {
  /// Connected, with an IP address.
  static const connected = 0;

  /// It carries no reason: a wrong password and an unreachable network look
  /// the same.
  static const failed = 1;
  static const connecting = 2;
}

/// The checksum of one frame: CRC-16/GENIBUS over `seq | data_len | data`,
/// with the data in plain text and its fragment prefix included.
int blufiChecksum(int seq, List<int> plain) =>
    crc16Genibus(<int>[seq & 0xFF, plain.length & 0xFF].followedBy(plain));

/// Builds one frame: `type | fc | seq | data_len | data | checksum?`.
///
/// [plain] is the data field in plain text. When [fc] has
/// [BlufiFc.encrypted], [encrypt] turns it into the bytes that travel; the
/// checksum is computed before that, over the plain text, and is never
/// encrypted. It is stored little-endian.
Uint8List buildBlufiFrame({
  required int type,
  required int fc,
  required int seq,
  required List<int> plain,
  Uint8List Function(List<int> plain)? encrypt,
}) {
  if (plain.length > 255) {
    throw ArgumentError.value(plain.length, 'plain', 'over 255 bytes');
  }
  final encrypted = (fc & BlufiFc.encrypted) != 0;
  if (encrypted != (encrypt != null)) {
    throw ArgumentError('an encrypted frame needs a cipher, and only it');
  }
  final withChecksum = (fc & BlufiFc.checksum) != 0;
  final data = encrypt == null ? plain : encrypt(plain);
  if (data.length != plain.length) {
    throw StateError('the cipher changed the length of the data');
  }
  final frame = Uint8List(4 + data.length + (withChecksum ? 2 : 0));
  frame[0] = type & 0xFF;
  frame[1] = fc & 0xFF;
  frame[2] = seq & 0xFF;
  frame[3] = data.length;
  frame.setRange(4, 4 + data.length, data);
  if (withChecksum) {
    final crc = blufiChecksum(seq, plain);
    frame[4 + data.length] = crc & 0xFF;
    frame[5 + data.length] = (crc >> 8) & 0xFF;
  }
  return frame;
}

/// One frame as it arrived.
class BlufiFrame {
  const BlufiFrame({
    required this.type,
    required this.fc,
    required this.seq,
    required this.data,
    this.checksum,
  });

  /// Reads one notification. Throws a [FormatException] when the bytes are
  /// not a whole frame.
  factory BlufiFrame.parse(List<int> bytes) {
    if (bytes.length < 4) {
      throw const FormatException('a BluFi frame has at least 4 bytes');
    }
    final fc = bytes[1];
    final length = bytes[3];
    final hasChecksum = (fc & BlufiFc.checksum) != 0;
    if (bytes.length < 4 + length + (hasChecksum ? 2 : 0)) {
      throw const FormatException('the BluFi frame is shorter than it says');
    }
    return BlufiFrame(
      type: bytes[0],
      fc: fc,
      seq: bytes[2],
      data: Uint8List.fromList(bytes.sublist(4, 4 + length)),
      checksum: hasChecksum
          ? bytes[4 + length] | (bytes[5 + length] << 8)
          : null,
    );
  }

  final int type;
  final int fc;
  final int seq;

  /// The data field as it travelled: encrypted when [encrypted].
  final Uint8List data;

  /// The CRC the sender stored, when [hasChecksum].
  final int? checksum;

  bool get encrypted => (fc & BlufiFc.encrypted) != 0;
  bool get hasChecksum => (fc & BlufiFc.checksum) != 0;
  bool get fromDevice => (fc & BlufiFc.fromDevice) != 0;
  bool get moreFragments => (fc & BlufiFc.moreFragments) != 0;

  /// Whether [plain], this frame's data after decryption, matches its CRC.
  bool checksumMatches(List<int> plain) =>
      !hasChecksum || checksum == blufiChecksum(seq, plain);
}

/// One frame's share of a message.
class BlufiFragment {
  const BlufiFragment(this.data, {required this.more});

  /// The data field in plain text, with its 2-byte prefix when [more].
  final Uint8List data;

  /// Whether more fragments follow ([BlufiFc.moreFragments]).
  final bool more;
}

/// The largest data field one frame may carry on a link with this ATT MTU:
/// `4 + data_len + 2 <= mtu - 3`, and `data_len <= 255`.
int blufiMaxData(int mtu) => math.min(255, mtu - 3 - 4 - 2);

/// Splits a message into data fields, one per frame (§8.2).
///
/// Every fragment but the last starts with a little-endian count of the
/// message bytes still to come, its own included. The last has no prefix.
List<BlufiFragment> blufiFragments(List<int> payload, {required int mtu}) {
  final max = blufiMaxData(mtu);
  if (payload.length <= max) {
    return <BlufiFragment>[
      BlufiFragment(Uint8List.fromList(payload), more: false),
    ];
  }
  if (max < 3) {
    throw ArgumentError.value(mtu, 'mtu', 'too small to fragment');
  }
  if (payload.length > 0xFFFF) {
    throw ArgumentError.value(payload.length, 'payload', 'too long');
  }
  final fragments = <BlufiFragment>[];
  final chunk = max - 2;
  var offset = 0;
  while (payload.length - offset > max) {
    final remaining = payload.length - offset;
    final data = Uint8List(2 + chunk)
      ..[0] = remaining & 0xFF
      ..[1] = (remaining >> 8) & 0xFF
      ..setRange(2, 2 + chunk, payload, offset);
    fragments.add(BlufiFragment(data, more: true));
    offset += chunk;
  }
  fragments.add(
    BlufiFragment(Uint8List.fromList(payload.sublist(offset)), more: false),
  );
  return fragments;
}

/// One whole message, after its fragments were joined.
class BlufiMessage {
  const BlufiMessage(this.type, this.payload);

  final int type;
  final Uint8List payload;
}

/// Joins the fragments of the messages of one direction.
class BlufiReassembler {
  int? _type;
  int? _total;
  final List<int> _buffer = <int>[];

  /// Adds one frame's data in plain text. Returns the message once its last
  /// fragment arrived. Throws a [FormatException] on a broken sequence.
  BlufiMessage? add({
    required int type,
    required bool more,
    required List<int> data,
  }) {
    final pending = _type;
    if (pending != null && pending != type) {
      reset();
      throw const FormatException('a fragment of another message arrived');
    }
    if (more) {
      if (data.length < 2) {
        reset();
        throw const FormatException('a fragment without its length');
      }
      _type = type;
      _total ??= data[0] | (data[1] << 8);
      _buffer.addAll(data.skip(2));
      if (_buffer.length > _total!) {
        reset();
        throw const FormatException('the fragments are longer than announced');
      }
      return null;
    }
    if (pending == null) {
      return BlufiMessage(type, Uint8List.fromList(data));
    }
    _buffer.addAll(data);
    final total = _total;
    final payload = Uint8List.fromList(_buffer);
    reset();
    if (payload.length != total) {
      throw const FormatException('the fragments do not add up');
    }
    return BlufiMessage(type, payload);
  }

  /// Drops a message in progress.
  void reset() {
    _type = null;
    _total = null;
    _buffer.clear();
  }
}

/// The NEG parameters (§8.2): `u16be(len P) ‖ P ‖ u16be(1) ‖ 0x02 ‖
/// u16be(len A) ‖ A`. For ffdhe3072 that is 775 bytes.
Uint8List blufiNegotiationParams({
  required List<int> prime,
  required int generator,
  required List<int> publicKey,
}) {
  final out = <int>[
    (prime.length >> 8) & 0xFF,
    prime.length & 0xFF,
    ...prime,
    0x00,
    0x01,
    generator & 0xFF,
    (publicKey.length >> 8) & 0xFF,
    publicKey.length & 0xFF,
    ...publicKey,
  ];
  return Uint8List.fromList(out);
}

/// The first NEG message: its type byte 0, then the parameters' length,
/// big-endian in this one place.
Uint8List blufiNegotiationLength(int length) =>
    Uint8List.fromList(<int>[0x00, (length >> 8) & 0xFF, length & 0xFF]);

/// The second NEG message: its type byte 1, then the parameters.
Uint8List blufiNegotiationData(List<int> params) =>
    Uint8List.fromList(<int>[0x01, ...params]);

/// Reads a WIFI_LIST payload: repeated `[len][rssi:int8][ssid (len - 1)]`.
/// SSIDs are decoded as UTF-8 with replacement. A broken tail is dropped.
List<WifiNetwork> parseBlufiWifiList(List<int> payload) {
  final networks = <WifiNetwork>[];
  var i = 0;
  while (i < payload.length) {
    final length = payload[i];
    if (length < 1 || i + 1 + length > payload.length) break;
    final rssi = payload[i + 1].toSigned(8);
    final ssid = utf8.decode(
      payload.sublist(i + 2, i + 1 + length),
      allowMalformed: true,
    );
    networks.add(WifiNetwork(ssid: ssid, rssi: rssi));
    i += 1 + length;
  }
  return networks;
}

/// The station state of a WIFI_REP payload:
/// `[opmode][sta_state][softap_conn][TLVs]`. Null when it is too short.
int? blufiWifiReportState(List<int> payload) =>
    payload.length >= 2 ? payload[1] : null;
