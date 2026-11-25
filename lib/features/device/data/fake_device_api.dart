import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/fake/demo_data.dart';

import 'device_api.dart';
import 'device_models.dart';

/// The demo's devices, in memory, following the platform's rules (§8.3).
///
/// It starts with one device, [DemoData.deviceId], assigned to Mati in the
/// seeded family. Each family sees only its own devices: [familyOf] names
/// the family signed in now (the seeded one by default).
/// [DemoData.claimCodeLinked] links a new device at once, and
/// [DemoData.claimCodeWaiting] answers `waitingForDevice`, the device then
/// appearing in [devices] after [confirmAfter]. Any other code is
/// `notFound`, and the tenth wrong code within an hour is `forbidden`.
class FakeDeviceApi implements DeviceApi {
  FakeDeviceApi({
    this.latency = const Duration(milliseconds: 350),
    this.confirmAfter = const Duration(seconds: 4),
    DateTime Function()? clock,
    String Function()? familyOf,
  }) : _now = clock ?? DateTime.now,
       _familyOf = familyOf ?? _seededFamily {
    final now = _now();
    _devices.add(
      Device(
        id: DemoData.deviceId,
        serial: 'AUL02-000123',
        model: _model,
        familyId: DemoData.familyId,
        childId: DemoData.childMati,
        claimedAt: now.subtract(const Duration(days: 12)).toUtc(),
        firmwareVersion: _firmware,
        lastSeenAt: now.subtract(const Duration(minutes: 10)).toUtc(),
      ),
    );
  }

  final Duration latency;
  final Duration confirmAfter;
  final DateTime Function() _now;
  final String Function() _familyOf;

  static String _seededFamily() => DemoData.familyId;

  final _devices = <Device>[];
  final _waiting = <_WaitingDevice>[];
  final _wrongCodes = <DateTime>[];
  int _made = 0;

  static const _model = 'aule-v0.2';
  static const _firmware = '0.0.2';
  static const _maxWrongCodes = 10;

  static const _notFound = ApiException(
    ApiErrorKind.notFound,
    status: 404,
    code: 'not_found',
    message: 'a device showing that code not found',
  );

  static const _tooMany = ApiException(
    ApiErrorKind.forbidden,
    status: 403,
    code: 'forbidden',
    message: 'too many wrong codes; try again in an hour',
  );

  static const _noDevice = ApiException(
    ApiErrorKind.notFound,
    status: 404,
    code: 'not_found',
    message: 'device not found',
  );

  @override
  Future<List<Device>> devices() async {
    await _wait();
    _confirmWaiting();
    final family = _familyOf();
    return List<Device>.unmodifiable(
      _devices.where((device) => device.familyId == family),
    );
  }

  @override
  Future<ClaimResult> claim({required String code, String? childId}) async {
    await _wait();
    final now = _now();
    _wrongCodes.removeWhere(
      (at) => now.difference(at) >= const Duration(hours: 1),
    );
    if (_wrongCodes.length >= _maxWrongCodes) throw _tooMany;
    final typed = ClaimCode.normalize(code.trim());
    if (typed == DemoData.claimCodeLinked) {
      final device = _newDevice(childId, now);
      _devices.add(device);
      return ClaimResult(deviceId: device.id, status: ClaimStatus.claimed);
    }
    if (typed == DemoData.claimCodeWaiting) {
      final device = _newDevice(childId, now);
      _waiting.add(_WaitingDevice(device, now.add(confirmAfter)));
      return ClaimResult(
        deviceId: device.id,
        status: ClaimStatus.waitingForDevice,
      );
    }
    _wrongCodes.add(now);
    if (_wrongCodes.length >= _maxWrongCodes) throw _tooMany;
    throw _notFound;
  }

  @override
  Future<void> assign(String deviceId, {required String? childId}) async {
    await _wait();
    _confirmWaiting();
    final family = _familyOf();
    final index = _devices.indexWhere(
      (device) => device.id == deviceId && device.familyId == family,
    );
    if (index < 0) throw _noDevice;
    final old = _devices[index];
    _devices[index] = Device(
      id: old.id,
      serial: old.serial,
      model: old.model,
      familyId: old.familyId,
      childId: childId,
      claimedAt: old.claimedAt,
      firmwareVersion: old.firmwareVersion,
      lastSeenAt: old.lastSeenAt,
    );
  }

  @override
  Future<void> unlink(String deviceId) async {
    await _wait();
    _confirmWaiting();
    final family = _familyOf();
    final before = _devices.length;
    _devices.removeWhere(
      (device) => device.id == deviceId && device.familyId == family,
    );
    if (_devices.length == before) throw _noDevice;
  }

  Future<void> _wait() => Future<void>.delayed(latency);

  /// A device appears once both halves of the link are in.
  void _confirmWaiting() {
    final now = _now();
    for (final waiting in _waiting.toList()) {
      if (!waiting.confirmedAt.isAfter(now)) {
        _waiting.remove(waiting);
        _devices.add(waiting.device);
      }
    }
  }

  Device _newDevice(String? childId, DateTime now) {
    _made++;
    final unit = 200 + _made;
    return Device(
      id: '0193a1f0-0000-7000-8000-${unit.toString().padLeft(12, '0')}',
      serial: 'AUL02-${(123 + _made).toString().padLeft(6, '0')}',
      model: _model,
      familyId: _familyOf(),
      childId: childId,
      claimedAt: now.toUtc(),
      firmwareVersion: _firmware,
      lastSeenAt: now.toUtc(),
    );
  }
}

class _WaitingDevice {
  const _WaitingDevice(this.device, this.confirmedAt);

  final Device device;
  final DateTime confirmedAt;
}
