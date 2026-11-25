import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../provisioning/wifi_provisioner.dart';
import 'blufi_session.dart';

/// Wi-Fi over Bluetooth with BluFi (§8.2), through universal_ble.
///
/// BluFi is off in today's Aule firmware (§8.4), so this client is written
/// against the firmware's code and must be checked on a board before the
/// `bleWifi` flag goes on outside demo mode.
class BlufiProvisioner implements WifiProvisioner {
  BlufiProvisioner();

  static const serviceUuid = '0000ffff-0000-1000-8000-00805f9b34fb';

  /// Phone-to-device frames are written here, with a response.
  static const phoneToDeviceUuid = '0000ff01-0000-1000-8000-00805f9b34fb';

  /// Device-to-phone frames arrive here as notifications.
  static const deviceToPhoneUuid = '0000ff02-0000-1000-8000-00805f9b34fb';

  /// The name today's firmware advertises, the same for every unit.
  static const firmwareName = 'Xiaozhi-Blufi';

  /// The per-unit name proposed in §8.4(d): "Aule-" and the last two bytes
  /// of the MAC.
  static const namePrefix = 'Aule-';

  /// Whether an advertised name is an Aule waiting for its Wi-Fi.
  static bool isAuleName(String? name) =>
      name != null && (name == firmwareName || name.startsWith(namePrefix));

  _BleScan? _scan;

  @override
  Stream<List<FoundDevice>> scan({
    Duration timeout = const Duration(seconds: 20),
  }) {
    final previous = _scan;
    if (previous != null) unawaited(previous.stop());
    final scan = _BleScan(timeout);
    _scan = scan;
    return scan.results;
  }

  @override
  Future<void> stopScan() async {
    final scan = _scan;
    _scan = null;
    if (scan != null) {
      await scan.stop();
    } else {
      await _stopPlatformScan();
    }
  }

  @override
  Future<ProvisionSession> connect(FoundDevice device) async {
    await stopScan();
    final link = await _BleLink.open(device.id);
    final session = BlufiSession(link);
    try {
      await session.handshake();
      return session;
    } on ProvisionException {
      await session.close();
      rethrow;
    } on Object {
      await session.close();
      throw const ProvisionException(ProvisionFailure.handshakeFailed);
    }
  }
}

Future<void> _stopPlatformScan() async {
  try {
    await UniversalBle.stopScan();
  } on Object {
    // Nothing was scanning.
  }
}

/// One scan: the growing list of Aule devices, strongest first, until the
/// timeout or a stop.
class _BleScan {
  _BleScan(this._timeout) {
    _controller = StreamController<List<FoundDevice>>(
      onListen: () => unawaited(_start()),
      onCancel: stop,
    );
  }

  final Duration _timeout;
  late final StreamController<List<FoundDevice>> _controller;
  final _found = <String, FoundDevice>{};
  StreamSubscription<BleDevice>? _results;
  Timer? _timer;
  bool _stopped = false;

  Stream<List<FoundDevice>> get results => _controller.stream;

  Future<void> _start() async {
    _results = UniversalBle.scanStream.listen(_onDevice);
    _timer = Timer(_timeout, () => unawaited(stop()));
    try {
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [BlufiProvisioner.serviceUuid]),
        // The app asks for its permissions itself (§11.3).
        platformConfig: PlatformConfig(
          android: AndroidOptions(
            legacy: true,
            requestLocationPermission: false,
          ),
        ),
      );
    } on Object {
      if (!_stopped && !_controller.isClosed) {
        _controller.addError(
          const ProvisionException(ProvisionFailure.bluetoothOff),
        );
      }
      await stop();
    }
  }

  void _onDevice(BleDevice device) {
    if (_stopped || !BlufiProvisioner.isAuleName(device.name)) return;
    _found[device.deviceId] = FoundDevice(
      id: device.deviceId,
      name: device.name,
      rssi: device.rssi,
    );
    final list = _found.values.toList()
      ..sort((a, b) => (b.rssi ?? -127).compareTo(a.rssi ?? -127));
    _controller.add(List<FoundDevice>.unmodifiable(list));
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _timer?.cancel();
    await _results?.cancel();
    await _stopPlatformScan();
    // Not awaited: during a cancel, the done future waits for this call.
    if (!_controller.isClosed) unawaited(_controller.close());
  }
}

/// The GATT link to one device.
class _BleLink implements BlufiLink {
  _BleLink._(this._deviceId);

  /// Connects (15 s), asks for a 512-byte MTU, finds the BluFi service and
  /// subscribes to the device's frames. Throws a [ProvisionException].
  static Future<_BleLink> open(String deviceId) async {
    final link = _BleLink._(deviceId);
    try {
      await UniversalBle.connect(
        deviceId,
        timeout: const Duration(seconds: 15),
      );
      link._connected = true;
      link._connection = UniversalBle.connectionStream(deviceId).listen((up) {
        if (!up) link._drop();
      });
      link._mtu = await _negotiateMtu(deviceId);
      final services = await UniversalBle.discoverServices(deviceId);
      if (!_hasBlufi(services)) {
        throw const ProvisionException(ProvisionFailure.connectFailed);
      }
      link._values =
          UniversalBle.characteristicValueStream(
            deviceId,
            BlufiProvisioner.deviceToPhoneUuid,
          ).listen((value) {
            if (!link._notifications.isClosed) link._notifications.add(value);
          });
      await UniversalBle.subscribeNotifications(
        deviceId,
        BlufiProvisioner.serviceUuid,
        BlufiProvisioner.deviceToPhoneUuid,
      );
      return link;
    } on Object catch (error) {
      await link.close();
      if (error is ProvisionException) rethrow;
      throw const ProvisionException(ProvisionFailure.connectFailed);
    }
  }

  final String _deviceId;
  final _notifications = StreamController<Uint8List>();
  final _done = Completer<void>();
  StreamSubscription<Uint8List>? _values;
  StreamSubscription<bool>? _connection;
  int _mtu = _minimumMtu;
  bool _connected = false;
  bool _closed = false;

  static const _minimumMtu = 23;
  static const _maximumMtu = 517;

  @override
  int get mtu => _mtu;

  @override
  Stream<Uint8List> get notifications => _notifications.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> write(Uint8List frame) => UniversalBle.write(
    _deviceId,
    BlufiProvisioner.serviceUuid,
    BlufiProvisioner.phoneToDeviceUuid,
    frame,
  );

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _values?.cancel();
    await _connection?.cancel();
    if (_connected) {
      try {
        await UniversalBle.disconnect(_deviceId);
      } on Object {
        // Already gone.
      }
    }
    _drop();
    if (!_notifications.isClosed) unawaited(_notifications.close());
  }

  void _drop() {
    if (!_done.isCompleted) _done.complete();
  }

  /// The returned value is the ATT MTU. On any failure, assume 23.
  static Future<int> _negotiateMtu(String deviceId) async {
    try {
      final mtu = await UniversalBle.requestMtu(deviceId, 512);
      return math.max(_minimumMtu, math.min(_maximumMtu, mtu));
    } on Object {
      return _minimumMtu;
    }
  }

  static bool _hasBlufi(List<BleService> services) {
    for (final service in services) {
      if (!_sameUuid(service.uuid, BlufiProvisioner.serviceUuid)) continue;
      final ids = service.characteristics.map((c) => c.uuid).toList();
      return ids.any(
            (id) => _sameUuid(id, BlufiProvisioner.phoneToDeviceUuid),
          ) &&
          ids.any((id) => _sameUuid(id, BlufiProvisioner.deviceToPhoneUuid));
    }
    return false;
  }

  static bool _sameUuid(String a, String b) {
    try {
      return BleUuidParser.compareStrings(a, b);
    } on FormatException {
      return a.toLowerCase() == b.toLowerCase();
    }
  }
}
