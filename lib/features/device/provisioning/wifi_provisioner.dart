/// A device seen while scanning.
class FoundDevice {
  const FoundDevice({required this.id, this.name, this.rssi});

  /// The platform's BLE id (a MAC on Android, a UUID on iOS). Never shown.
  final String id;
  final String? name;
  final int? rssi;

  /// "3F2A" for a device advertising "Aule-3F2A"; null otherwise.
  String? get code => name != null && name!.startsWith('Aule-')
      ? name!.substring('Aule-'.length)
      : null;
}

class WifiNetwork {
  const WifiNetwork({required this.ssid, required this.rssi});

  final String ssid;
  final int rssi;
}

class WifiCredentials {
  const WifiCredentials({required this.ssid, required this.password});

  final String ssid;
  final String password;

  @override
  String toString() => 'WifiCredentials(<redacted>)';
}

enum WifiResult { connected, failed, probablyConnected }

enum ProvisionFailure {
  bluetoothOff,
  permissionDenied,
  connectFailed,
  handshakeFailed,
  deviceError,
  timeout,
}

class ProvisionException implements Exception {
  const ProvisionException(this.failure, {this.deviceErrorCode});

  final ProvisionFailure failure;

  /// The BluFi ERROR_INFO byte, when the device sent one.
  final int? deviceErrorCode;

  @override
  String toString() => 'ProvisionException($failure, $deviceErrorCode)';
}

abstract interface class WifiProvisioner {
  /// Emits the growing list of devices found; completes after [timeout].
  Stream<List<FoundDevice>> scan({
    Duration timeout = const Duration(seconds: 20),
  });

  Future<void> stopScan();

  /// Connects and finishes the secure handshake, or throws ProvisionException.
  Future<ProvisionSession> connect(FoundDevice device);
}

abstract interface class ProvisionSession {
  /// The networks the device can see. Empty when it found none.
  Future<List<WifiNetwork>> networks();

  /// Sends the credentials and waits for the device's report (§8.2).
  Future<WifiResult> join(WifiCredentials credentials);

  /// Drops the BLE link. Safe to call twice.
  Future<void> close();
}
