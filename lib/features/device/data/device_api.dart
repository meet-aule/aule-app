import 'device_models.dart';

abstract interface class DeviceApi {
  /// GET /devices: only the family's linked devices.
  Future<List<Device>> devices();

  /// POST /devices/claim {code, child_id?}. A 404 (wrong or expired code)
  /// and a 403 (too many wrong codes) reach the caller as ApiException.
  Future<ClaimResult> claim({required String code, String? childId});

  /// PUT /devices/{id} {child_id}, with null for nobody.
  Future<void> assign(String deviceId, {required String? childId});

  /// DELETE /devices/{id}.
  Future<void> unlink(String deviceId);
}
