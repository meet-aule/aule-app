import 'dart:async';

import 'package:aule/core/api/fake/demo_data.dart';
import 'package:aule/features/device/data/device_models.dart';
import 'package:aule/features/device/data/fake_device_api.dart';
import 'package:aule/features/device/provisioning/ble_permissions.dart';
import 'package:aule/features/device/provisioning/fake_wifi_provisioner.dart';
import 'package:aule/features/device/provisioning/wifi_provisioner.dart';
import 'package:aule/features/device/ui/device_setup_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Waits until [condition] holds, re-checked on every notification.
Future<void> until(
  ChangeNotifier notifier,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  if (condition()) return;
  final done = Completer<void>();
  void check() {
    if (!done.isCompleted && condition()) done.complete();
  }

  notifier.addListener(check);
  try {
    await done.future.timeout(timeout);
  } finally {
    notifier.removeListener(check);
  }
}

/// Counts what the flow closes behind it.
class _SpyProvisioner implements WifiProvisioner {
  _SpyProvisioner(this._inner);

  final WifiProvisioner _inner;
  int stopScans = 0;
  final sessions = <_SpySession>[];

  @override
  Stream<List<FoundDevice>> scan({
    Duration timeout = const Duration(seconds: 20),
  }) => _inner.scan(timeout: timeout);

  @override
  Future<void> stopScan() {
    stopScans++;
    return _inner.stopScan();
  }

  @override
  Future<ProvisionSession> connect(FoundDevice device) async {
    final session = _SpySession(await _inner.connect(device));
    sessions.add(session);
    return session;
  }
}

class _SpySession implements ProvisionSession {
  _SpySession(this._inner);

  final ProvisionSession _inner;
  int closes = 0;
  final joined = <String>[];

  @override
  Future<List<WifiNetwork>> networks() => _inner.networks();

  @override
  Future<WifiResult> join(WifiCredentials credentials) {
    joined.add(credentials.ssid);
    return _inner.join(credentials);
  }

  @override
  Future<void> close() {
    closes++;
    return _inner.close();
  }
}

const _fast = SetupTimings(
  scan: Duration(milliseconds: 300),
  connect: Duration(seconds: 2),
  networks: Duration(seconds: 2),
  join: Duration(seconds: 2),
  poll: Duration(milliseconds: 10),
  claimLifetime: Duration(seconds: 2),
);

void main() {
  late _SpyProvisioner provisioner;
  late FakeDeviceApi devices;

  DeviceSetupController setupFor({
    String? childId,
    bool bleWifi = true,
    SetupTimings timings = _fast,
    BleReadiness check = BleReadiness.ready,
    BleReadiness request = BleReadiness.ready,
    bool asksForLocation = false,
  }) {
    final setup = DeviceSetupController(
      devices: devices,
      provisioner: provisioner,
      bleWifi: bleWifi,
      childId: childId,
      timings: timings,
      checkBluetooth: () async => check,
      requestBluetooth: () async => request,
      asksForLocation: () async => asksForLocation,
    );
    addTearDown(setup.dispose);
    return setup;
  }

  /// From intro to the password step of "Casa".
  Future<void> toPassword(DeviceSetupController setup) async {
    await setup.start();
    await until(setup, () => setup.step == SetupStep.pick);
    await setup.pick(setup.found.single);
    expect(setup.step, SetupStep.networks);
    setup.chooseNetwork('Casa');
    expect(setup.step, SetupStep.password);
  }

  setUp(() {
    provisioner = _SpyProvisioner(
      FakeWifiProvisioner(
        findAfter: const Duration(milliseconds: 20),
        latency: const Duration(milliseconds: 5),
      ),
    );
    devices = FakeDeviceApi(
      latency: Duration.zero,
      confirmAfter: const Duration(milliseconds: 50),
    );
  });

  test('Bluetooth is explained before the OS asks, then refused', () async {
    final setup = setupFor(
      check: BleReadiness.denied,
      request: BleReadiness.denied,
      asksForLocation: true,
    );
    await setup.start();
    // Never asked yet: the step explains, and says the OS calls it location.
    expect(setup.step, SetupStep.permissions);
    expect(setup.readiness, BleReadiness.denied);
    expect(setup.bluetoothAsked, isFalse);
    expect(setup.asksForLocation, isTrue);
    await setup.allowBluetooth();
    expect(setup.bluetoothAsked, isTrue);
    expect(setup.step, SetupStep.permissions);
  });

  test('demo mode is ready without asking the phone', () async {
    expect(await BleAccess.demo.check(), BleReadiness.ready);
    expect(await BleAccess.demo.request(), BleReadiness.ready);
    expect(await BleAccess.demo.asksForLocation(), isFalse);
  });

  test('Wi-Fi over Bluetooth, then a code that links at once', () async {
    final setup = setupFor(childId: DemoData.childMati);
    final steps = <SetupStep>[setup.step];
    setup.addListener(() {
      if (steps.last != setup.step) steps.add(setup.step);
    });

    await setup.start();
    await until(setup, () => setup.step == SetupStep.pick);
    expect(setup.found.single.code, '3F2A');

    await setup.pick(setup.found.single);
    expect(setup.step, SetupStep.networks);
    expect(setup.networksLoading, isFalse);
    // Strongest first.
    expect(setup.networks.map((n) => n.ssid), <String>[
      'Casa',
      'Casa-5G',
      'Vecino',
    ]);

    setup.chooseNetwork('Casa');
    setup.passwordField.text = DemoData.wifiPassword;
    await setup.connectWifi();
    expect(setup.step, SetupStep.wifiDone);
    expect(setup.probably, isFalse);
    expect(setup.passwordField.text, isEmpty, reason: 'it is never kept');
    // Reaching wifiDone closes Bluetooth behind it.
    expect(provisioner.sessions.single.closes, greaterThanOrEqualTo(1));
    expect(provisioner.stopScans, greaterThanOrEqualTo(1));

    setup.continueToCode();
    expect(setup.step, SetupStep.code);
    setup.setCode('k7qm-2x');
    expect(setup.code, DemoData.claimCodeLinked);
    expect(setup.canLink, isTrue);
    await setup.link();
    expect(setup.step, SetupStep.linked);
    expect(setup.childId, DemoData.childMati);
    expect(
      (await devices.devices()).map((d) => d.id),
      contains(setup.linkedDeviceId),
    );

    expect(steps, <SetupStep>[
      SetupStep.intro,
      SetupStep.scanning,
      SetupStep.pick,
      SetupStep.connecting,
      SetupStep.networks,
      SetupStep.password,
      SetupStep.joining,
      SetupStep.wifiDone,
      SetupStep.code,
      SetupStep.linked,
    ]);
  });

  test('a wrong Wi-Fi password fails, and trying again starts empty', () async {
    final setup = setupFor();
    await toPassword(setup);
    setup.passwordField.text = 'otra-clave';
    await setup.connectWifi();
    expect(setup.step, SetupStep.wifiFailed);
    expect(setup.passwordField.text, isEmpty);
    setup.tryAgain();
    expect(setup.step, SetupStep.password);
    setup.chooseAnotherNetwork();
    expect(setup.step, SetupStep.networks);
  });

  test('the password is 0, or 8 to 64 bytes in UTF-8', () async {
    final setup = setupFor();
    await toPassword(setup);

    setup.passwordField.text = 'corta';
    await setup.connectWifi();
    expect(setup.step, SetupStep.password);
    expect(setup.passwordProblem, PasswordProblem.tooShort);

    setup.passwordField.text = 'x' * 65;
    await setup.connectWifi();
    expect(setup.passwordProblem, PasswordProblem.tooLong);

    // 33 characters, but 66 bytes.
    setup.passwordField.text = 'ñ' * 33;
    await setup.connectWifi();
    expect(setup.passwordProblem, PasswordProblem.tooLong);
    expect(provisioner.sessions.single.joined, isEmpty);

    // An open network: no password at all.
    setup.passwordField.clear();
    await setup.connectWifi();
    expect(setup.passwordProblem, isNull);
    expect(provisioner.sessions.single.joined, <String>['Casa']);
  });

  test('a network typed by hand is 1 to 32 bytes', () async {
    final setup = setupFor();
    await toPassword(setup);
    expect(setup.back(), isTrue);
    expect(setup.step, SetupStep.networks);

    setup.showOtherNetwork();
    expect(setup.otherNetwork, isTrue);
    setup.ssidField.text = 'ñ' * 17;
    setup.submitOtherNetwork();
    expect(setup.ssidProblem, SsidProblem.tooLong);
    expect(setup.step, SetupStep.networks);

    setup.ssidField.text = 'Mi red';
    setup.submitOtherNetwork();
    expect(setup.step, SetupStep.password);
    expect(setup.ssid, 'Mi red');
  });

  test('Bluetooth refused shows the permissions step', () async {
    final setup = setupFor(
      check: BleReadiness.denied,
      request: BleReadiness.permanentlyDenied,
    );
    await setup.start();
    expect(setup.step, SetupStep.permissions);
    expect(setup.readiness, BleReadiness.denied);
    await setup.allowBluetooth();
    expect(setup.step, SetupStep.permissions);
    expect(setup.readiness, BleReadiness.permanentlyDenied);
    expect(setup.back(), isTrue);
    expect(setup.step, SetupStep.intro);
  });

  test('nothing found within the scan time', () async {
    provisioner = _SpyProvisioner(
      FakeWifiProvisioner(findAfter: const Duration(seconds: 5)),
    );
    final setup = setupFor(
      timings: const SetupTimings(scan: Duration(milliseconds: 40)),
    );
    await setup.start();
    await until(setup, () => setup.step == SetupStep.pick);
    expect(setup.found, isEmpty);
    expect(setup.scanFinished, isTrue);
  });

  test('a code the device confirms later, then choosing the child', () async {
    final setup = setupFor();
    setup.skipToCode();
    expect(setup.step, SetupStep.code);
    setup.setCode(DemoData.claimCodeWaiting);
    await setup.link();
    expect(setup.step, SetupStep.waiting);
    await until(setup, () => setup.step == SetupStep.linked);
    expect(setup.childId, isNull);
    await setup.assignLinked(DemoData.childLu);
    expect(setup.childId, DemoData.childLu);
    final linked = (await devices.devices()).singleWhere(
      (d) => d.id == setup.linkedDeviceId,
    );
    expect(linked.childId, DemoData.childLu);
  });

  test('a device that never confirms times out', () async {
    devices = FakeDeviceApi(
      latency: Duration.zero,
      confirmAfter: const Duration(minutes: 5),
    );
    final setup = setupFor(
      timings: const SetupTimings(
        poll: Duration(milliseconds: 10),
        claimLifetime: Duration(milliseconds: 60),
      ),
    );
    setup.skipToCode();
    setup.setCode(DemoData.claimCodeWaiting);
    await setup.link();
    await until(setup, () => setup.timedOut);
    expect(setup.step, SetupStep.waiting);
    setup.typeAgain();
    expect(setup.step, SetupStep.code);
    expect(setup.code, isEmpty);
  });

  test('wrong codes, then too many', () async {
    final setup = setupFor();
    setup.skipToCode();
    for (var i = 1; i <= 9; i++) {
      setup.setCode('AAAAAA');
      await setup.link();
      expect(setup.claimProblem, ClaimProblem.wrong);
      expect(setup.step, SetupStep.code);
    }
    setup.setCode('AAAAAA');
    await setup.link();
    expect(setup.claimProblem, ClaimProblem.tooMany);
  });

  test('an incomplete code cannot be sent', () async {
    final setup = setupFor();
    setup.skipToCode();
    setup.setCode('K7Q');
    expect(setup.canLink, isFalse);
    await setup.link();
    expect(setup.step, SetupStep.code);
  });

  test('without bleWifi the flow is the code only', () async {
    final setup = setupFor(bleWifi: false);
    expect(setup.bleWifi, isFalse);
    setup.skipToCode();
    expect(setup.step, SetupStep.code);
    expect(setup.back(), isTrue);
    expect(setup.step, SetupStep.intro);
    expect(setup.back(), isFalse);
  });

  test('leaving the flow closes the Bluetooth session and the scan', () async {
    final setup = DeviceSetupController(
      devices: devices,
      provisioner: provisioner,
      bleWifi: true,
      timings: _fast,
      checkBluetooth: () async => BleReadiness.ready,
      requestBluetooth: () async => BleReadiness.ready,
    );
    await toPassword(setup);
    final stops = provisioner.stopScans;
    setup.dispose();
    expect(provisioner.sessions.single.closes, 1);
    expect(provisioner.stopScans, stops + 1);
  });
}
