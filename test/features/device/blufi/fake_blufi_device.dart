import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:aule/features/device/blufi/blufi_crypto.dart';
import 'package:aule/features/device/blufi/blufi_frame.dart';
import 'package:aule/features/device/blufi/blufi_session.dart';

/// The device's side of BluFi for tests, written from the behaviour of
/// aule-fw's blufi.cpp and the ESP-IDF BluFi layer (§8.2). It is not a
/// capture from a real board: golden values from one are still to come.
///
/// It checks the phone's sequence numbers and checksums, joins fragments,
/// answers NEG with its own public value, decrypts with the "blufi_dec" IV
/// and encrypts with "blufi_enc", and checksums and encrypts its own data
/// frames once SET_SEC_MODE is 0x03, except NEG and ERROR_INFO.
class FakeBlufiDevice implements BlufiLink {
  FakeBlufiDevice({
    this.mtu = 23,
    this.password = 'aule1234',
    this.networks = const <(String, int)>[('Casa', -48), ('Vecino', -80)],
    this.dropAfterConnect = false,
    this.negotiationError,
    this.silent = false,
    Random? random,
  }) : _random = random ?? Random(42);

  @override
  final int mtu;

  /// The only password that joins.
  final String password;

  /// What the device's Wi-Fi scan sees. Empty gives ERROR_INFO 11.
  final List<(String, int)> networks;

  /// Drops the link on success before the report goes out (§8.4 a).
  final bool dropAfterConnect;

  /// An ERROR_INFO code sent in answer to NEG.
  final int? negotiationError;

  /// Never answers anything.
  final bool silent;

  final Random _random;
  final _notifications = StreamController<Uint8List>();
  final _done = Completer<void>();
  final _reassembler = BlufiReassembler();
  int _sendSeq = 0;
  int _expectedSeq = 0;
  int _securityMode = 0;
  int? _negotiationLength;
  BlufiCipher? _decrypt;
  BlufiCipher? _encrypt;
  Uint8List? _ssid;
  Uint8List? _password;

  /// Every frame the phone wrote, as it travelled.
  final List<Uint8List> written = <Uint8List>[];

  /// What the device received, in plain text, for the tests to check.
  String? get receivedSsid => _ssid == null ? null : utf8.decode(_ssid!);
  String? get receivedPassword =>
      _password == null ? null : utf8.decode(_password!);

  bool get connected => !_done.isCompleted;

  @override
  Stream<Uint8List> get notifications => _notifications.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> write(Uint8List frame) async {
    if (!connected) throw StateError('the link is down');
    written.add(Uint8List.fromList(frame));
    // The device handles the frame after the write's response.
    scheduleMicrotask(() => _receive(frame));
  }

  @override
  Future<void> close() async => drop();

  /// The link drops, as when the device restarts or provisioning ends.
  void drop() {
    if (_done.isCompleted) return;
    _done.complete();
    unawaited(_notifications.close());
  }

  void _receive(Uint8List bytes) {
    if (!connected || silent) return;
    final frame = BlufiFrame.parse(bytes);
    if (frame.seq != _expectedSeq) return _sendError(0);
    _expectedSeq = (_expectedSeq + 1) & 0xFF;
    var data = frame.data;
    if (frame.encrypted) {
      final cipher = _decrypt;
      if (cipher == null) return _sendError(2);
      data = cipher.apply(data);
    }
    if (!frame.checksumMatches(data)) return _sendError(1);
    final message = _reassembler.add(
      type: frame.type,
      more: frame.moreFragments,
      data: data,
    );
    if (message != null) _handle(message);
  }

  void _handle(BlufiMessage message) {
    switch (message.type) {
      case BlufiType.negotiate:
        _negotiate(message.payload);
      case BlufiType.setSecurityMode:
        _securityMode = message.payload.isEmpty ? 0 : message.payload[0];
      case BlufiType.getWifiList:
        _sendWifiList();
      case BlufiType.staSsid:
        _ssid = message.payload;
      case BlufiType.staPassword:
        _password = message.payload;
      case BlufiType.connectToAp:
        _connectToAp();
      default:
        break;
    }
  }

  void _negotiate(Uint8List data) {
    final error = negotiationError;
    if (error != null) return _sendError(error);
    if (data.length < 3) return _sendError(9);
    if (data[0] == 0x00) {
      _negotiationLength = (data[1] << 8) | data[2];
      return;
    }
    if (data[0] != 0x01 || data.length != (_negotiationLength ?? -1) + 1) {
      return _sendError(6);
    }
    final params = data.sublist(1);
    final primeLength = (params[0] << 8) | params[1];
    final g = 2 + primeLength;
    final generatorLength = (params[g] << 8) | params[g + 1];
    final generator = params[g + 2];
    final a = g + 2 + generatorLength;
    final publicLength = (params[a] << 8) | params[a + 1];
    if (primeLength != 384 ||
        generatorLength != 1 ||
        generator != 2 ||
        publicLength != 384 ||
        a + 2 + publicLength != params.length) {
      return _sendError(6);
    }
    final pair = BlufiKeyPair.generate(_random);
    final keys = BlufiKeys.derive(
      pair.sharedSecret(params.sublist(a + 2, a + 2 + publicLength)),
    );
    _decrypt = AesCtrBlufiCipher(key: keys.key, iv: keys.ivPhoneToDevice);
    _encrypt = AesCtrBlufiCipher(key: keys.key, iv: keys.ivDeviceToPhone);
    _send(BlufiType.negotiate, pair.publicKey);
  }

  void _sendWifiList() {
    if (networks.isEmpty) return _sendError(11);
    final payload = <int>[];
    for (final (ssid, rssi) in networks) {
      final bytes = utf8.encode(ssid);
      payload
        ..add(bytes.length + 1)
        ..add(rssi & 0xFF)
        ..addAll(bytes);
    }
    _send(BlufiType.wifiList, payload);
  }

  void _connectToAp() {
    final joined = receivedPassword == password;
    if (joined && dropAfterConnect) return drop();
    final ssid = _ssid ?? Uint8List(0);
    _send(BlufiType.wifiReport, <int>[
      0x01, // station mode
      if (joined) 0x00 else 0x01,
      0x00,
      0x02, // TLV: the SSID
      ssid.length,
      ...ssid,
    ]);
    // On success the device drops the link itself.
    if (joined) Timer.run(drop);
  }

  void _sendError(int code) => _send(BlufiType.errorInfo, <int>[code]);

  void _send(int type, List<int> payload) {
    final secured =
        BlufiType.isData(type) &&
        type != BlufiType.negotiate &&
        type != BlufiType.errorInfo;
    final checksum = secured && (_securityMode & 0x01) != 0;
    final encrypt = secured && (_securityMode & 0x02) != 0;
    for (final fragment in blufiFragments(payload, mtu: mtu)) {
      var fc = BlufiFc.fromDevice;
      if (checksum) fc |= BlufiFc.checksum;
      if (encrypt) fc |= BlufiFc.encrypted;
      if (fragment.more) fc |= BlufiFc.moreFragments;
      final frame = buildBlufiFrame(
        type: type,
        fc: fc,
        seq: _sendSeq,
        plain: fragment.data,
        encrypt: encrypt ? _encrypt!.apply : null,
      );
      _sendSeq = (_sendSeq + 1) & 0xFF;
      if (!_notifications.isClosed) _notifications.add(frame);
    }
  }
}
