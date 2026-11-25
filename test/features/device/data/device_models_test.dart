import 'package:aule/features/device/data/device_models.dart';
import 'package:aule/features/device/provisioning/wifi_provisioner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClaimCode', () {
    test('normalize upper-cases and drops spaces and hyphens', () {
      expect(ClaimCode.normalize('k7q m2-x'), 'K7QM2X');
      expect(ClaimCode.normalize(' w8pz\t3r\n'), 'W8PZ3R');
      expect(ClaimCode.normalize('K7Q-M2X'), 'K7QM2X');
    });

    test('isValid wants 6 characters of the platform alphabet', () {
      expect(ClaimCode.isValid('K7QM2X'), isTrue);
      expect(ClaimCode.isValid('W8PZ3R'), isTrue);
      expect(ClaimCode.isValid('K7QM2'), isFalse);
      expect(ClaimCode.isValid('K7QM2XY'), isFalse);
      // No 0, 1, I or O.
      expect(ClaimCode.isValid('K7QM0X'), isFalse);
      expect(ClaimCode.isValid('K7QM1X'), isFalse);
      expect(ClaimCode.isValid('K7QMIX'), isFalse);
      expect(ClaimCode.isValid('K7QMOX'), isFalse);
      // Only after normalize.
      expect(ClaimCode.isValid('k7qm2x'), isFalse);
      expect(ClaimCode.isValid('K7Q-2X'), isFalse);
      expect(ClaimCode.isValid(ClaimCode.normalize('k7q-m2x')), isTrue);
    });

    test('a code works for ten minutes', () {
      expect(ClaimCode.lifetime, const Duration(minutes: 10));
    });
  });

  test('Device.fromJson reads the platform view', () {
    final device = Device.fromJson(<String, dynamic>{
      'id': '0193a1f0-0000-7000-8000-000000000200',
      'serial': 'AUL02-000123',
      'model': 'aule-v0.2',
      'family_id': '0193a1f0-0000-7000-8000-000000000001',
      'child_id': null,
      'claimed_at': '2026-11-13T15:04:05Z',
      'firmware_version': '0.0.2',
      'last_seen_at': null,
    });
    expect(device.id, '0193a1f0-0000-7000-8000-000000000200');
    expect(device.serial, 'AUL02-000123');
    expect(device.model, 'aule-v0.2');
    expect(device.familyId, '0193a1f0-0000-7000-8000-000000000001');
    expect(device.childId, isNull);
    expect(device.claimedAt, DateTime.utc(2026, 11, 13, 15, 4, 5));
    expect(device.firmwareVersion, '0.0.2');
    expect(device.lastSeenAt, isNull);
  });

  test('Device.fromJson refuses a device without its id', () {
    expect(
      () => Device.fromJson(<String, dynamic>{'serial': 'x', 'model': 'y'}),
      throwsFormatException,
    );
  });

  test('ClaimResult.fromJson reads both statuses', () {
    final claimed = ClaimResult.fromJson(<String, dynamic>{
      'device_id': 'd1',
      'status': 'claimed',
    });
    expect(claimed.deviceId, 'd1');
    expect(claimed.status, ClaimStatus.claimed);
    final waiting = ClaimResult.fromJson(<String, dynamic>{
      'device_id': 'd2',
      'status': 'waiting_for_device',
    });
    expect(waiting.status, ClaimStatus.waitingForDevice);
  });

  test('FoundDevice.code is the end of an "Aule-" name', () {
    expect(const FoundDevice(id: 'a', name: 'Aule-3F2A').code, '3F2A');
    expect(const FoundDevice(id: 'b', name: 'Xiaozhi-Blufi').code, isNull);
    expect(const FoundDevice(id: 'c').code, isNull);
  });

  test('credentials never print their password', () {
    const credentials = WifiCredentials(ssid: 'Casa', password: 'aule1234');
    expect(credentials.toString(), isNot(contains('aule1234')));
    expect(credentials.toString(), isNot(contains('Casa')));
  });
}
