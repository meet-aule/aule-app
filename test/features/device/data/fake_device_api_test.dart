import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/fake/demo_data.dart';
import 'package:aule/features/device/data/device_models.dart';
import 'package:aule/features/device/data/fake_device_api.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher _apiError(ApiErrorKind kind) =>
    isA<ApiException>().having((e) => e.kind, 'kind', kind);

void main() {
  late DateTime now;
  late FakeDeviceApi api;

  setUp(() {
    now = DateTime.utc(2026, 11, 25, 15);
    api = FakeDeviceApi(
      latency: Duration.zero,
      confirmAfter: const Duration(seconds: 4),
      clock: () => now,
    );
  });

  test('it starts with one device, used by Mati', () async {
    final devices = await api.devices();
    expect(devices, hasLength(1));
    final device = devices.single;
    expect(device.id, DemoData.deviceId);
    expect(device.serial, 'AUL02-000123');
    expect(device.model, 'aule-v0.2');
    expect(device.firmwareVersion, '0.0.2');
    expect(device.childId, DemoData.childMati);
    expect(device.lastSeenAt, now.subtract(const Duration(minutes: 10)));
  });

  test("each demo family sees only its own devices", () async {
    var family = DemoData.familyId;
    final scoped = FakeDeviceApi(
      latency: Duration.zero,
      clock: () => now,
      familyOf: () => family,
    );
    expect(await scoped.devices(), hasLength(1));
    // A new demo family starts with none, and links its own.
    family = 'another-family';
    expect(await scoped.devices(), isEmpty);
    await expectLater(
      scoped.unlink(DemoData.deviceId),
      throwsA(_apiError(ApiErrorKind.notFound)),
    );
    final result = await scoped.claim(code: DemoData.claimCodeLinked);
    expect((await scoped.devices()).single.id, result.deviceId);
    family = DemoData.familyId;
    expect((await scoped.devices()).single.id, DemoData.deviceId);
  });

  test('the linked code links a new device at once', () async {
    final result = await api.claim(
      code: DemoData.claimCodeLinked,
      childId: DemoData.childLu,
    );
    expect(result.status, ClaimStatus.claimed);
    final device = (await api.devices()).singleWhere(
      (d) => d.id == result.deviceId,
    );
    expect(device.childId, DemoData.childLu);
  });

  test('the waiting code appears in devices() after 4 s', () async {
    final result = await api.claim(code: 'w8pz-3r');
    expect(result.status, ClaimStatus.waitingForDevice);
    expect(
      (await api.devices()).map((d) => d.id),
      isNot(contains(result.deviceId)),
    );
    now = now.add(const Duration(seconds: 4));
    expect((await api.devices()).map((d) => d.id), contains(result.deviceId));
  });

  test(
    'a wrong code is notFound; the tenth within an hour is forbidden',
    () async {
      for (var i = 1; i <= 9; i++) {
        await expectLater(
          api.claim(code: 'AAAAAA'),
          throwsA(_apiError(ApiErrorKind.notFound)),
        );
      }
      await expectLater(
        api.claim(code: 'AAAAAA'),
        throwsA(_apiError(ApiErrorKind.forbidden)),
      );
      // Locked out for the hour, even with a right code.
      await expectLater(
        api.claim(code: DemoData.claimCodeLinked),
        throwsA(_apiError(ApiErrorKind.forbidden)),
      );
      now = now.add(const Duration(hours: 1));
      final result = await api.claim(code: DemoData.claimCodeLinked);
      expect(result.status, ClaimStatus.claimed);
    },
  );

  test('assign and unlink', () async {
    await api.assign(DemoData.deviceId, childId: null);
    expect((await api.devices()).single.childId, isNull);
    await api.assign(DemoData.deviceId, childId: DemoData.childLu);
    expect((await api.devices()).single.childId, DemoData.childLu);
    await api.unlink(DemoData.deviceId);
    expect(await api.devices(), isEmpty);
    await expectLater(
      api.unlink(DemoData.deviceId),
      throwsA(_apiError(ApiErrorKind.notFound)),
    );
    await expectLater(
      api.assign(DemoData.deviceId, childId: null),
      throwsA(_apiError(ApiErrorKind.notFound)),
    );
  });
}
