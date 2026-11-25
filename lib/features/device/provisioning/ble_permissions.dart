import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_ble/universal_ble.dart';

enum BleReadiness {
  ready,
  denied,
  permanentlyDenied,
  bluetoothOff,
  locationOff,
  unsupported,
}

/// What the setup flow asks the phone about Bluetooth. Demo mode answers
/// "ready" at once, so it shows no OS prompt and needs no radio, and the
/// simulators can walk the whole flow (§2.1).
class BleAccess {
  const BleAccess({
    required this.check,
    required this.request,
    required this.asksForLocation,
  });

  /// The phone's own checks and prompts.
  static const BleAccess phone = BleAccess(
    check: BlePermissions.check,
    request: BlePermissions.request,
    asksForLocation: BlePermissions.asksForLocation,
  );

  /// Demo mode: ready, and nothing is asked.
  static const BleAccess demo = BleAccess(
    check: _ready,
    request: _ready,
    asksForLocation: _never,
  );

  /// Where things stand, without asking.
  final Future<BleReadiness> Function() check;

  /// Asks for what is missing, then reports.
  final Future<BleReadiness> Function() request;

  /// Whether the OS asks for location to scan (Android 7 to 11).
  final Future<bool> Function() asksForLocation;

  static Future<BleReadiness> _ready() async => BleReadiness.ready;

  static Future<bool> _never() async => false;
}

/// What BLE setup needs from the phone (§8.1, §11.3):
/// - Android 12 and later: BLUETOOTH_SCAN and BLUETOOTH_CONNECT;
/// - Android 7 to 11: ACCESS_FINE_LOCATION, plus the location service on;
/// - iOS: Bluetooth.
///
/// Then the Bluetooth adapter has to be on. Bluetooth is asked for only on
/// the setup screen, never before.
abstract final class BlePermissions {
  /// Where things stand, without asking.
  static Future<BleReadiness> check() => _readiness(ask: false);

  /// Asks for what is missing (§11.3), then reports.
  static Future<BleReadiness> request() => _readiness(ask: true);

  /// Android 7 to 11 grant the Bluetooth scan as "location", so the screen
  /// says so before the OS asks.
  static Future<bool> asksForLocation() async {
    if (!Platform.isAndroid) return false;
    try {
      return (await DeviceInfoPlugin().androidInfo).version.sdkInt < 31;
    } on Object {
      return false;
    }
  }

  static Future<BleReadiness> _readiness({required bool ask}) async {
    try {
      final BleReadiness? refused;
      if (Platform.isAndroid) {
        final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        if (sdk >= 31) {
          refused = await _permissions([
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          ], ask: ask);
        } else {
          refused = await _permissions([
            Permission.locationWhenInUse,
          ], ask: ask);
          if (refused == null &&
              !await Permission.locationWhenInUse.serviceStatus.isEnabled) {
            return BleReadiness.locationOff;
          }
        }
      } else if (Platform.isIOS) {
        refused = await _permissions([Permission.bluetooth], ask: ask);
      } else {
        return BleReadiness.unsupported;
      }
      return refused ?? await _adapter();
    } on Object {
      return BleReadiness.unsupported;
    }
  }

  /// Null when everything is granted.
  static Future<BleReadiness?> _permissions(
    List<Permission> permissions, {
    required bool ask,
  }) async {
    final statuses = ask
        ? (await permissions.request()).values.toList()
        : <PermissionStatus>[
            for (final permission in permissions) await permission.status,
          ];
    if (statuses.any((s) => s.isPermanentlyDenied || s.isRestricted)) {
      return BleReadiness.permanentlyDenied;
    }
    if (statuses.any((s) => !(s.isGranted || s.isLimited))) {
      return BleReadiness.denied;
    }
    return null;
  }

  /// Whether the adapter is on. Right after start, iOS reports `unknown`
  /// for a moment, so an unsettled state gets a short wait.
  static Future<BleReadiness> _adapter() async {
    var state = await UniversalBle.getBluetoothAvailabilityState();
    if (state == AvailabilityState.unknown ||
        state == AvailabilityState.resetting) {
      state = await UniversalBle.availabilityStream
          .firstWhere(
            (s) =>
                s != AvailabilityState.unknown &&
                s != AvailabilityState.resetting,
          )
          .timeout(const Duration(seconds: 3), onTimeout: () => state);
    }
    return switch (state) {
      AvailabilityState.poweredOn => BleReadiness.ready,
      AvailabilityState.poweredOff => BleReadiness.bluetoothOff,
      AvailabilityState.unauthorized => BleReadiness.permanentlyDenied,
      AvailabilityState.unsupported => BleReadiness.unsupported,
      // Still unknown or resetting: let the scan find out.
      _ => BleReadiness.ready,
    };
  }
}
