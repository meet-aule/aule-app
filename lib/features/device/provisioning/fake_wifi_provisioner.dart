import 'dart:async';

import 'package:aule/core/api/fake/demo_data.dart';

import 'wifi_provisioner.dart';

/// The demo's provisioner. "Aule-3F2A" appears after [findAfter], it sees
/// three networks, and it joins any of them only with
/// [DemoData.wifiPassword]. It touches no radio and nothing leaves the
/// phone.
class FakeWifiProvisioner implements WifiProvisioner {
  FakeWifiProvisioner({
    this.findAfter = const Duration(seconds: 2),
    this.latency = const Duration(milliseconds: 800),
  });

  final Duration findAfter;

  /// The wait before connecting and before listing networks. Joining takes
  /// three times as long.
  final Duration latency;

  static const demoDevice = FoundDevice(
    id: 'demo-ble-3f2a',
    name: 'Aule-3F2A',
    rssi: -52,
  );

  static const demoNetworks = <WifiNetwork>[
    WifiNetwork(ssid: 'Casa', rssi: -48),
    WifiNetwork(ssid: 'Casa-5G', rssi: -57),
    WifiNetwork(ssid: 'Vecino', rssi: -81),
  ];

  StreamController<List<FoundDevice>>? _scan;
  Timer? _foundTimer;
  Timer? _endTimer;

  @override
  Stream<List<FoundDevice>> scan({
    Duration timeout = const Duration(seconds: 20),
  }) {
    unawaited(stopScan());
    late final StreamController<List<FoundDevice>> controller;
    controller = StreamController<List<FoundDevice>>(
      onListen: () {
        if (findAfter < timeout) {
          _foundTimer = Timer(findAfter, () {
            if (!controller.isClosed) {
              controller.add(const <FoundDevice>[demoDevice]);
            }
          });
        }
        _endTimer = Timer(timeout, () => unawaited(stopScan()));
      },
      onCancel: stopScan,
    );
    _scan = controller;
    return controller.stream;
  }

  @override
  Future<void> stopScan() async {
    _foundTimer?.cancel();
    _endTimer?.cancel();
    final scan = _scan;
    _scan = null;
    if (scan != null && !scan.isClosed) unawaited(scan.close());
  }

  @override
  Future<ProvisionSession> connect(FoundDevice device) async {
    await stopScan();
    await Future<void>.delayed(latency);
    return _FakeProvisionSession(latency);
  }
}

class _FakeProvisionSession implements ProvisionSession {
  _FakeProvisionSession(this._latency);

  final Duration _latency;
  bool _closed = false;

  @override
  Future<List<WifiNetwork>> networks() async {
    await Future<void>.delayed(_latency);
    _checkOpen();
    return FakeWifiProvisioner.demoNetworks;
  }

  @override
  Future<WifiResult> join(WifiCredentials credentials) async {
    await Future<void>.delayed(_latency * 3);
    _checkOpen();
    return credentials.password == DemoData.wifiPassword
        ? WifiResult.connected
        : WifiResult.failed;
  }

  @override
  Future<void> close() async {
    _closed = true;
  }

  void _checkOpen() {
    if (_closed) {
      throw const ProvisionException(ProvisionFailure.connectFailed);
    }
  }
}
