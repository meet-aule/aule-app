import 'package:aule/core/api/json.dart';

class Device {
  const Device({
    required this.id,
    required this.serial,
    required this.model,
    this.familyId,
    this.childId,
    this.claimedAt,
    this.firmwareVersion,
    this.lastSeenAt,
  });

  factory Device.fromJson(Json json) => Device(
    id: jString(json, 'id'),
    serial: jString(json, 'serial'),
    model: jString(json, 'model'),
    familyId: jStringOrNull(json, 'family_id'),
    childId: jStringOrNull(json, 'child_id'),
    claimedAt: jTimeOrNull(json, 'claimed_at'),
    firmwareVersion: jStringOrNull(json, 'firmware_version'),
    lastSeenAt: jTimeOrNull(json, 'last_seen_at'),
  );

  final String id;
  final String serial;
  final String model;
  final String? familyId;
  final String? childId;
  final DateTime? claimedAt;
  final String? firmwareVersion;
  final DateTime? lastSeenAt;
}

enum ClaimStatus { claimed, waitingForDevice }

class ClaimResult {
  const ClaimResult({required this.deviceId, required this.status});

  factory ClaimResult.fromJson(Json json) => ClaimResult(
    deviceId: jString(json, 'device_id'),
    status: jString(json, 'status') == 'claimed'
        ? ClaimStatus.claimed
        : ClaimStatus.waitingForDevice,
  );

  final String deviceId;
  final ClaimStatus status;
}

abstract final class ClaimCode {
  /// The platform's alphabet: no 0, 1, I or O.
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const length = 6;

  /// How long one code works, and so how long to wait for the device.
  static const lifetime = Duration(minutes: 10);

  /// Upper case, with spaces and hyphens dropped.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  static bool isValid(String code) =>
      code.length == length && code.split('').every(alphabet.contains);
}
