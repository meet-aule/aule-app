import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../provisioning/wifi_provisioner.dart';
import 'blufi_crypto.dart';
import 'blufi_frame.dart';
import 'ffdhe3072.dart';

/// The BLE side of one BluFi connection: each GATT write carries exactly
/// one phone frame, and each notification exactly one device frame.
abstract interface class BlufiLink {
  /// The ATT MTU of the link; 23 when it is unknown.
  int get mtu;

  /// The device's notifications, one frame each.
  Stream<Uint8List> get notifications;

  /// Completes when the link drops, for any reason.
  Future<void> get done;

  /// Writes one frame, with a response.
  Future<void> write(Uint8List frame);

  /// Drops the link. Safe to call twice.
  Future<void> close();
}

/// How long a session waits for the device.
class BlufiTimeouts {
  const BlufiTimeouts({
    this.negotiation = const Duration(seconds: 30),
    this.networks = const Duration(seconds: 15),
    this.report = const Duration(seconds: 25),
  });

  /// The device creates its key while the phone waits for its NEG answer.
  final Duration negotiation;
  final Duration networks;

  /// The wait for WIFI_REP after CONN_TO_AP.
  final Duration report;
}

/// One provisioning session over BluFi, the ESP-IDF 6 PSA variant (§8.2).
///
/// Call [handshake] once before anything else. It never logs or keeps an
/// SSID, a password, the exponent, the shared secret, a key or the contents
/// of a frame, and it zeroes the buffers that held the password once they
/// are sent (best effort).
class BlufiSession implements ProvisionSession {
  BlufiSession(
    this._link, {
    Random? random,
    this.timeouts = const BlufiTimeouts(),
  }) : _random = random {
    _subscription = _link.notifications.listen(
      _onNotification,
      onError: (Object _) => _lose(),
      onDone: _lose,
    );
    _link.done.then<void>((_) => _lose(), onError: (Object _) => _lose());
  }

  final BlufiLink _link;
  final Random? _random;
  final BlufiTimeouts timeouts;

  late final StreamSubscription<Uint8List> _subscription;
  final _reassembler = BlufiReassembler();
  final _inbox = <BlufiMessage>[];
  Completer<void>? _signal;
  Future<void> _queue = Future<void>.value();

  int _sendSeq = 0;
  BlufiCipher? _toDevice;
  BlufiCipher? _fromDevice;
  bool _secured = false;
  bool _lost = false;
  bool _broken = false;
  bool _closed = false;

  /// Whether the BLE link is still up and the session usable.
  bool get isOpen => !_lost && !_closed && !_broken;

  /// Runs the key exchange, then turns on checksums and encryption. Throws
  /// a [ProvisionException]: `handshakeFailed` (with the device's error
  /// code when it sent one), `connectFailed` when the link drops, or
  /// `timeout`.
  Future<void> handshake() => _serial(_handshake);

  Future<void> _handshake() async {
    if (_secured) return;
    final pair = BlufiKeyPair.generate(_random);
    try {
      final params = blufiNegotiationParams(
        prime: Ffdhe3072.primeBytes(),
        generator: Ffdhe3072.generator,
        publicKey: pair.publicKey,
      );
      _clear(BlufiType.negotiate);
      await _send(BlufiType.negotiate, blufiNegotiationLength(params.length));
      await _send(BlufiType.negotiate, blufiNegotiationData(params));
      final answer = await _next(BlufiType.negotiate, timeouts.negotiation);
      final Uint8List shared;
      try {
        shared = pair.sharedSecret(answer.payload);
      } on FormatException {
        throw const ProvisionException(ProvisionFailure.handshakeFailed);
      }
      final keys = BlufiKeys.derive(shared);
      _toDevice = keys.phoneToDevice();
      _fromDevice = keys.deviceToPhone();
      keys.destroy();
      await _send(BlufiType.setSecurityMode, const <int>[blufiSecurityMode]);
      _secured = true;
    } finally {
      pair.destroy();
    }
  }

  @override
  Future<List<WifiNetwork>> networks() => _serial(() async {
    _requireSecured();
    _clear(BlufiType.wifiList);
    await _send(BlufiType.getWifiList, const <int>[]);
    try {
      final message = await _next(BlufiType.wifiList, timeouts.networks);
      return parseBlufiWifiList(message.payload);
    } on ProvisionException catch (error) {
      // ERROR_INFO 11: the device's Wi-Fi scan failed, so it saw nothing.
      if (error.deviceErrorCode == _wifiScanError) {
        return const <WifiNetwork>[];
      }
      rethrow;
    }
  });

  @override
  Future<WifiResult> join(WifiCredentials credentials) => _serial(() async {
    _requireSecured();
    _clear(BlufiType.wifiReport);
    final ssid = utf8.encode(credentials.ssid);
    final password = utf8.encode(credentials.password);
    try {
      await _send(BlufiType.staSsid, ssid, wipe: true);
      await _send(BlufiType.staPassword, password, wipe: true);
    } finally {
      ssid.fillRange(0, ssid.length, 0);
      password.fillRange(0, password.length, 0);
    }
    await _send(BlufiType.connectToAp, const <int>[]);
    final clock = Stopwatch()..start();
    while (true) {
      final BlufiMessage report;
      try {
        report = await _next(
          BlufiType.wifiReport,
          timeouts.report - clock.elapsed,
        );
      } on ProvisionException catch (error) {
        // The device tears BluFi down once it is on the network, so the
        // link can drop before its report arrives (§8.4 a).
        if (error.failure == ProvisionFailure.connectFailed && _lost) {
          return WifiResult.probablyConnected;
        }
        rethrow;
      }
      switch (blufiWifiReportState(report.payload)) {
        case BlufiStaState.connected:
          return WifiResult.connected;
        case BlufiStaState.failed:
          return WifiResult.failed;
        default:
          // Still connecting, or a report this client does not read.
          continue;
      }
    }
  });

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _wake();
    await _subscription.cancel();
    _toDevice?.destroy();
    _fromDevice?.destroy();
    _toDevice = null;
    _fromDevice = null;
    _inbox.clear();
    _reassembler.reset();
    await _link.close();
  }

  static const _wifiScanError = 11;

  void _requireSecured() {
    if (!_secured) throw StateError('the BluFi handshake has not run');
  }

  /// Runs [action] after every earlier one, so frames never interleave.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Sends one message, split into as many frames as the MTU needs. Every
  /// phone frame has a checksum; data frames are encrypted once the
  /// handshake is done.
  Future<void> _send(int type, List<int> payload, {bool wipe = false}) async {
    final encrypt = _secured && BlufiType.isData(type);
    final fragments = blufiFragments(payload, mtu: _link.mtu);
    try {
      for (final fragment in fragments) {
        if (!isOpen) {
          throw const ProvisionException(ProvisionFailure.connectFailed);
        }
        var fc = BlufiFc.checksum;
        if (encrypt) fc |= BlufiFc.encrypted;
        if (fragment.more) fc |= BlufiFc.moreFragments;
        final frame = buildBlufiFrame(
          type: type,
          fc: fc,
          seq: _sendSeq,
          plain: fragment.data,
          encrypt: encrypt ? _toDevice!.apply : null,
        );
        _sendSeq = (_sendSeq + 1) & 0xFF;
        try {
          await _link.write(frame);
        } on Object {
          _lose();
          throw const ProvisionException(ProvisionFailure.connectFailed);
        }
      }
    } finally {
      if (wipe) {
        for (final fragment in fragments) {
          fragment.data.fillRange(0, fragment.data.length, 0);
        }
      }
    }
  }

  /// Waits for the next message of [type]. An ERROR_INFO from the device
  /// ends the wait with its code.
  Future<BlufiMessage> _next(int type, Duration timeout) async {
    final clock = Stopwatch()..start();
    while (true) {
      final index = _inbox.indexWhere(
        (message) =>
            message.type == type || message.type == BlufiType.errorInfo,
      );
      if (index >= 0) {
        final message = _inbox.removeAt(index);
        if (message.type == BlufiType.errorInfo) {
          throw ProvisionException(
            _failure,
            deviceErrorCode: message.payload.isEmpty
                ? null
                : message.payload[0],
          );
        }
        return message;
      }
      if (_broken) throw ProvisionException(_failure);
      if (_lost || _closed) {
        throw const ProvisionException(ProvisionFailure.connectFailed);
      }
      final left = timeout - clock.elapsed;
      if (left <= Duration.zero) {
        throw const ProvisionException(ProvisionFailure.timeout);
      }
      final signal = _signal ??= Completer<void>();
      await signal.future.timeout(left, onTimeout: () {});
    }
  }

  ProvisionFailure get _failure => _secured
      ? ProvisionFailure.deviceError
      : ProvisionFailure.handshakeFailed;

  /// Forgets stale answers of [type] and stale device errors before a new
  /// request.
  void _clear(int type) => _inbox.removeWhere(
    (message) => message.type == type || message.type == BlufiType.errorInfo,
  );

  void _onNotification(Uint8List bytes) {
    if (_closed || _broken) return;
    try {
      final frame = BlufiFrame.parse(bytes);
      // The device counts its frames from 0 on every connection. Its count
      // is not enforced: a lost encrypted frame fails the next checksum,
      // because the CTR offsets then differ, and a lost fragment breaks the
      // reassembly.
      var data = frame.data;
      if (frame.encrypted) {
        final cipher = _fromDevice;
        if (cipher == null) {
          throw const FormatException('an encrypted frame before the keys');
        }
        data = cipher.apply(data);
      }
      if (!frame.checksumMatches(data)) {
        throw const FormatException('a frame with a wrong checksum');
      }
      final message = _reassembler.add(
        type: frame.type,
        more: frame.moreFragments,
        data: data,
      );
      if (message != null) {
        _inbox.add(message);
        _wake();
      }
    } on FormatException {
      // The stream cannot be trusted after this: the CTR offsets may differ.
      _broken = true;
      _wake();
    }
  }

  void _lose() {
    if (_lost) return;
    _lost = true;
    _wake();
  }

  void _wake() {
    final signal = _signal;
    _signal = null;
    if (signal != null && !signal.isCompleted) signal.complete();
  }
}
