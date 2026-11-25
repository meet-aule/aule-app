import 'package:flutter/foundation.dart';

import '../data/device_api.dart';
import '../data/device_models.dart';

/// The view model of /devices/:deviceId. There is no GET for one device, so
/// it finds it in the family's list.
class DeviceController extends ChangeNotifier {
  DeviceController({required DeviceApi api, required this.deviceId})
    : _api = api;

  final DeviceApi _api;
  final String deviceId;

  Device? _device;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;

  Device? get device => _device;
  Object? get error => _error;
  bool get loading => _loading;

  /// An assignment or the unlinking is running.
  bool get busy => _busy;

  /// Loaded, and the family has no such device (any more).
  bool get missing => !_loading && _error == null && _device == null;

  /// Loads the device. It notifies only after its first await, so it is
  /// safe to call from a provider's create.
  Future<void> load() async {
    try {
      final devices = await _api.devices();
      _device = _find(devices);
      _error = null;
    } on Object catch (error) {
      _error = error;
    }
    _loading = false;
    _emit();
  }

  Future<void> retry() {
    _loading = true;
    _error = null;
    _emit();
    return load();
  }

  /// Who uses the device; null for nobody. Throws on failure.
  Future<void> assign(String? childId) async {
    final old = _device;
    if (old == null || _busy) return;
    _busy = true;
    _emit();
    try {
      await _api.assign(deviceId, childId: childId);
      _device = Device(
        id: old.id,
        serial: old.serial,
        model: old.model,
        familyId: old.familyId,
        childId: childId,
        claimedAt: old.claimedAt,
        firmwareVersion: old.firmwareVersion,
        lastSeenAt: old.lastSeenAt,
      );
    } finally {
      _busy = false;
      _emit();
    }
  }

  /// Takes the device out of the family. Throws on failure.
  Future<void> unlink() async {
    if (_busy) return;
    _busy = true;
    _emit();
    try {
      await _api.unlink(deviceId);
    } finally {
      _busy = false;
      _emit();
    }
  }

  Device? _find(List<Device> devices) {
    for (final device in devices) {
      if (device.id == deviceId) return device;
    }
    return null;
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
