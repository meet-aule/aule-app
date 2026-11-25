import 'dart:async';
import 'dart:convert';

import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/log/app_log.dart';
import 'package:flutter/widgets.dart';

import '../data/device_api.dart';
import '../data/device_models.dart';
import '../provisioning/ble_permissions.dart';
import '../provisioning/wifi_provisioner.dart';

/// The steps of /devices/setup (§4.8, §8.1).
enum SetupStep {
  intro,
  permissions,
  scanning,
  pick,
  connecting,
  networks,
  password,
  joining,
  wifiFailed,
  wifiDone,
  code,
  waiting,
  linked,
}

enum SsidProblem { tooLong }

enum PasswordProblem { tooShort, tooLong }

enum ClaimProblem { wrong, tooMany, other }

/// How long each step waits (§8.1). Tests pass shorter ones.
class SetupTimings {
  const SetupTimings({
    this.scan = const Duration(seconds: 20),
    this.connect = const Duration(seconds: 45),
    this.networks = const Duration(seconds: 15),
    this.join = const Duration(seconds: 25),
    this.poll = const Duration(seconds: 3),
    this.claimLifetime = ClaimCode.lifetime,
  });

  final Duration scan;

  /// The connection and the secure handshake together.
  final Duration connect;
  final Duration networks;
  final Duration join;

  /// How often GET /devices is asked while the device confirms the link.
  final Duration poll;

  /// How long the device has to confirm after the claim.
  final Duration claimLifetime;
}

/// The view model of the device setup flow. It lives as long as the route.
///
/// The Wi-Fi password lives only in [passwordField], which is cleared as
/// soon as it was sent, and it is never logged. SSIDs, codes and ids are
/// never logged either.
class DeviceSetupController extends ChangeNotifier {
  DeviceSetupController({
    required DeviceApi devices,
    required WifiProvisioner provisioner,
    required this.bleWifi,
    String? childId,
    this.timings = const SetupTimings(),
    Future<BleReadiness> Function() checkBluetooth = BlePermissions.check,
    Future<BleReadiness> Function() requestBluetooth = BlePermissions.request,
    Future<bool> Function() asksForLocation = BlePermissions.asksForLocation,
  }) : _devices = devices,
       _provisioner = provisioner,
       _childId = childId,
       _checkBluetooth = checkBluetooth,
       _requestBluetooth = requestBluetooth,
       _asksForLocationOf = asksForLocation;

  final DeviceApi _devices;
  final WifiProvisioner _provisioner;
  final Future<BleReadiness> Function() _checkBluetooth;
  final Future<BleReadiness> Function() _requestBluetooth;
  final Future<bool> Function() _asksForLocationOf;

  /// Whether Wi-Fi over Bluetooth is offered (flag `bleWifi`).
  final bool bleWifi;
  final SetupTimings timings;

  /// The typed name of a network that is not in the list.
  final TextEditingController ssidField = TextEditingController();

  /// The Wi-Fi password. Cleared after every join.
  final TextEditingController passwordField = TextEditingController();

  static const _maxSsidBytes = 32;
  static const _minPasswordBytes = 8;
  static const _maxPasswordBytes = 64;

  SetupStep _step = SetupStep.intro;
  bool _busy = false;
  bool _disposed = false;

  BleReadiness? _readiness;
  bool? _asksForLocation;
  bool _bluetoothAsked = false;

  StreamSubscription<List<FoundDevice>>? _scanSubscription;
  List<FoundDevice> _found = const <FoundDevice>[];
  bool _scanFinished = false;
  FoundDevice? _picked;

  int _attempt = 0;
  bool _connectFailed = false;
  ProvisionSession? _session;

  List<WifiNetwork> _networks = const <WifiNetwork>[];
  bool _networksLoading = false;
  bool _otherNetwork = false;
  SsidProblem? _ssidProblem;
  String? _ssid;
  bool _showPassword = false;
  PasswordProblem? _passwordProblem;
  bool _probably = false;

  SetupStep _codeFrom = SetupStep.intro;
  int _codeAttempt = 0;
  String _code = '';
  String? _childId;
  ClaimProblem? _claimProblem;
  Object? _claimError;

  String? _waitingFor;
  Timer? _pollTimer;
  final Stopwatch _waitClock = Stopwatch();
  bool _polling = false;
  bool _timedOut = false;
  String? _linkedDeviceId;

  SetupStep get step => _step;

  /// A request is running: its button shows a spinner.
  bool get busy => _busy;

  /// The permissions step's state; null before the first check.
  BleReadiness? get readiness => _readiness;

  /// The OS will ask for location to scan (Android 7 to 11), so the
  /// permissions step explains it first.
  bool get asksForLocation => _asksForLocation ?? false;

  /// "Permitir Bluetooth" was pressed in this flow. Until then a permission
  /// not granted is one never asked for, and the step explains it first.
  bool get bluetoothAsked => _bluetoothAsked;

  /// The devices found so far, strongest first.
  List<FoundDevice> get found => _found;

  /// The scan is over; with nothing [found], the "none found" copy shows.
  bool get scanFinished => _scanFinished;
  bool get connectFailed => _connectFailed;

  /// Strongest first, each name once, empty names hidden.
  List<WifiNetwork> get networks => _networks;
  bool get networksLoading => _networksLoading;

  /// Whether the field for a network that is not listed shows.
  bool get otherNetwork => _otherNetwork || _networks.isEmpty;
  SsidProblem? get ssidProblem => _ssidProblem;

  /// The network being joined. Shown, never logged.
  String get ssid => _ssid ?? '';
  bool get showPassword => _showPassword;
  PasswordProblem? get passwordProblem => _passwordProblem;

  /// The link dropped right after connecting, with no report (§8.4 a).
  bool get probably => _probably;

  /// Changes whenever the code boxes must start empty again.
  int get codeAttempt => _codeAttempt;
  String get code => _code;
  bool get canLink => !_busy && ClaimCode.isValid(_code);

  /// The child who will use the device; null for "choose later".
  String? get childId => _childId;
  ClaimProblem? get claimProblem => _claimProblem;

  /// The error behind [ClaimProblem.other], for `errorText`.
  Object? get claimError => _claimError;

  /// The device did not confirm within the code's lifetime.
  bool get timedOut => _timedOut;
  String? get linkedDeviceId => _linkedDeviceId;

  /// intro, "Empezar": straight to the scan when Bluetooth is ready, else
  /// the permissions step.
  Future<void> start() async {
    if (_busy) return;
    await _withReadiness(_checkBluetooth);
  }

  /// permissions, "Permitir Bluetooth".
  Future<void> allowBluetooth() async {
    if (_busy) return;
    _bluetoothAsked = true;
    await _withReadiness(_requestBluetooth);
  }

  /// permissions, after the parent turned Bluetooth or location on.
  Future<void> checkAgain() async {
    if (_busy) return;
    await _withReadiness(_checkBluetooth);
  }

  Future<void> _withReadiness(Future<BleReadiness> Function() ask) async {
    _busy = true;
    _emit();
    if (_asksForLocation == null) {
      try {
        _asksForLocation = await _asksForLocationOf();
      } on Object {
        _asksForLocation = false;
      }
    }
    BleReadiness readiness;
    try {
      readiness = await ask();
    } on Object {
      readiness = BleReadiness.unsupported;
    }
    _busy = false;
    if (_disposed) return;
    _readiness = readiness;
    if (readiness == BleReadiness.ready) {
      _startScan();
    } else {
      _step = SetupStep.permissions;
      _emit();
    }
  }

  /// "Mi Aule ya tiene Wi-Fi", or "Enlazar con un código" without bleWifi.
  void skipToCode() {
    _codeFrom = SetupStep.intro;
    _toCode();
  }

  /// pick with nothing found, "Buscar otra vez".
  void scanAgain() => _startScan();

  void _startScan() {
    unawaited(_scanSubscription?.cancel());
    _found = const <FoundDevice>[];
    _scanFinished = false;
    _step = SetupStep.scanning;
    _emit();
    _scanSubscription = _provisioner
        .scan(timeout: timings.scan)
        .listen(
          (devices) {
            _found = devices;
            if (_step == SetupStep.scanning && devices.isNotEmpty) {
              _step = SetupStep.pick;
            }
            _emit();
          },
          onError: (Object error) => unawaited(_scanFailed()),
          onDone: () {
            _scanFinished = true;
            if (_step == SetupStep.scanning) _step = SetupStep.pick;
            _emit();
          },
          cancelOnError: true,
        );
  }

  Future<void> _scanFailed() async {
    _scanSubscription = null;
    await _provisioner.stopScan();
    BleReadiness readiness;
    try {
      readiness = await _checkBluetooth();
    } on Object {
      readiness = BleReadiness.unsupported;
    }
    if (_disposed) return;
    _readiness = readiness;
    if (readiness == BleReadiness.ready) {
      _scanFinished = true;
      _step = SetupStep.pick;
    } else {
      _step = SetupStep.permissions;
    }
    _emit();
  }

  /// pick: connects to [device] and runs the secure handshake.
  Future<void> pick(FoundDevice device) async {
    await _stopScan();
    _picked = device;
    await _connect();
  }

  /// connecting after a failure, "Reintentar".
  Future<void> retryConnect() => _connect();

  Future<void> _connect() async {
    final device = _picked;
    if (device == null) return;
    final attempt = ++_attempt;
    _step = SetupStep.connecting;
    _connectFailed = false;
    _emit();
    final pending = _provisioner.connect(device);
    final ProvisionSession session;
    try {
      session = await pending.timeout(timings.connect);
    } on Object catch (error) {
      if (error is TimeoutException) {
        // A session that arrives late is closed as soon as it lands.
        unawaited(
          pending.then<void>(
            (arrived) => arrived.close(),
            onError: (Object _) {},
          ),
        );
      }
      AppLog.warn('device.connect_failed', <String, Object>{
        'reason': _reasonOf(error),
      });
      if (_disposed || attempt != _attempt) return;
      _connectFailed = true;
      _emit();
      return;
    }
    if (_disposed || attempt != _attempt) {
      unawaited(session.close());
      return;
    }
    _session = session;
    AppLog.info('device.connected');
    await _loadNetworks();
  }

  /// networks, "Buscar redes otra vez".
  Future<void> refreshNetworks() => _loadNetworks();

  Future<void> _loadNetworks() async {
    final session = _session;
    if (session == null) return;
    _step = SetupStep.networks;
    _networksLoading = true;
    _emit();
    List<WifiNetwork> seen;
    try {
      seen = await session.networks().timeout(timings.networks);
    } on Object {
      // A failure still offers the field for the network's name.
      seen = const <WifiNetwork>[];
    }
    if (_disposed) return;
    _networks = _tidy(seen);
    _networksLoading = false;
    _emit();
  }

  static List<WifiNetwork> _tidy(List<WifiNetwork> networks) {
    final best = <String, WifiNetwork>{};
    for (final network in networks) {
      if (network.ssid.trim().isEmpty) continue;
      final seen = best[network.ssid];
      if (seen == null || network.rssi > seen.rssi) {
        best[network.ssid] = network;
      }
    }
    return best.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  /// networks, one listed network.
  void chooseNetwork(String ssid) {
    _ssid = ssid;
    _ssidProblem = null;
    _passwordProblem = null;
    _showPassword = false;
    passwordField.clear();
    _step = SetupStep.password;
    _emit();
  }

  /// networks, "Otra red".
  void showOtherNetwork() {
    _otherNetwork = true;
    _emit();
  }

  /// networks, the typed name: 1 to 32 bytes in UTF-8, because the
  /// firmware does not check it.
  void submitOtherNetwork() {
    final ssid = ssidField.text;
    if (ssid.isEmpty) return;
    if (utf8.encode(ssid).length > _maxSsidBytes) {
      _ssidProblem = SsidProblem.tooLong;
      _emit();
      return;
    }
    chooseNetwork(ssid);
  }

  /// password, the trailing "Mostrar" or "Ocultar".
  void toggleShowPassword() {
    _showPassword = !_showPassword;
    _emit();
  }

  /// password, "Conectar": 0 bytes for an open network, or 8 to 64 bytes
  /// in UTF-8. Then the device's report decides the next step.
  Future<void> connectWifi() async {
    final session = _session;
    final ssid = _ssid;
    if (session == null || ssid == null || _step != SetupStep.password) {
      return;
    }
    final bytes = utf8.encode(passwordField.text);
    final length = bytes.length;
    bytes.fillRange(0, length, 0);
    if (length > _maxPasswordBytes) {
      _passwordProblem = PasswordProblem.tooLong;
      _emit();
      return;
    }
    if (length > 0 && length < _minPasswordBytes) {
      _passwordProblem = PasswordProblem.tooShort;
      _emit();
      return;
    }
    _passwordProblem = null;
    _step = SetupStep.joining;
    _emit();
    WifiResult? result;
    Object? failure;
    try {
      result = await session
          .join(WifiCredentials(ssid: ssid, password: passwordField.text))
          .timeout(timings.join);
    } on Object catch (error) {
      failure = error;
    } finally {
      // The password is sent once and never kept (§12.7).
      passwordField.clear();
      _showPassword = false;
    }
    if (_disposed) return;
    AppLog.info('device.wifi', <String, Object>{
      'result': result?.name ?? _reasonOf(failure),
    });
    switch (result) {
      case WifiResult.connected:
        await _finishWifi(probably: false);
      case WifiResult.probablyConnected:
        await _finishWifi(probably: true);
      case WifiResult.failed:
        _step = SetupStep.wifiFailed;
        _emit();
      case null:
        if (failure is ProvisionException &&
            failure.failure == ProvisionFailure.connectFailed) {
          // The Bluetooth link is gone: connect again before retrying.
          _session = null;
          unawaited(session.close());
          _step = SetupStep.connecting;
          _connectFailed = true;
        } else {
          _step = SetupStep.wifiFailed;
        }
        _emit();
    }
  }

  Future<void> _finishWifi({required bool probably}) async {
    _probably = probably;
    _step = SetupStep.wifiDone;
    _emit();
    await _closeBluetooth();
  }

  /// wifiFailed, "Intentar otra vez".
  void tryAgain() {
    passwordField.clear();
    _passwordProblem = null;
    _step = SetupStep.password;
    _emit();
  }

  /// wifiFailed, "Elegir otra red".
  void chooseAnotherNetwork() {
    _step = SetupStep.networks;
    _emit();
  }

  /// wifiDone, "Continuar".
  void continueToCode() {
    _codeFrom = SetupStep.wifiDone;
    _toCode();
  }

  void _toCode() {
    _code = '';
    _claimProblem = null;
    _claimError = null;
    _codeAttempt++;
    _step = SetupStep.code;
    _emit();
  }

  /// code, what the boxes hold.
  void setCode(String text) {
    _code = ClaimCode.normalize(text);
    _claimProblem = null;
    _claimError = null;
    _emit();
  }

  /// code and linked, the child picker; null is "Elegir después".
  void chooseChild(String? childId) {
    _childId = childId;
    _emit();
  }

  /// code, "Enlazar".
  Future<void> link() async {
    if (!canLink) return;
    _busy = true;
    _claimProblem = null;
    _claimError = null;
    _emit();
    try {
      final result = await _devices.claim(code: _code, childId: _childId);
      if (_disposed) return;
      AppLog.info('device.claim', <String, Object>{
        'status': result.status.name,
      });
      switch (result.status) {
        case ClaimStatus.claimed:
          _linked(result.deviceId);
        case ClaimStatus.waitingForDevice:
          _waitFor(result.deviceId);
      }
    } on ApiException catch (error) {
      AppLog.warn('device.claim_failed', <String, Object>{
        'kind': error.kind.name,
      });
      _claimProblem = switch (error.kind) {
        ApiErrorKind.notFound => ClaimProblem.wrong,
        ApiErrorKind.forbidden => ClaimProblem.tooMany,
        _ => ClaimProblem.other,
      };
      _claimError = error;
    } on Object catch (error) {
      _claimProblem = ClaimProblem.other;
      _claimError = error;
    } finally {
      _busy = false;
      _emit();
    }
  }

  void _waitFor(String deviceId) {
    _waitingFor = deviceId;
    _timedOut = false;
    _step = SetupStep.waiting;
    _waitClock
      ..reset()
      ..start();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(timings.poll, (_) => unawaited(_poll()));
  }

  Future<void> _poll() async {
    final deviceId = _waitingFor;
    if (deviceId == null || _polling || _disposed) return;
    if (_waitClock.elapsed >= timings.claimLifetime) {
      _pollTimer?.cancel();
      _timedOut = true;
      _emit();
      return;
    }
    _polling = true;
    try {
      final devices = await _devices.devices();
      if (_disposed || _waitingFor != deviceId) return;
      if (devices.any((device) => device.id == deviceId)) _linked(deviceId);
    } on Object {
      // Asked again at the next tick.
    } finally {
      _polling = false;
    }
  }

  /// waiting after the timeout, "Escribir el código otra vez".
  void typeAgain() {
    _stopWaiting();
    _toCode();
  }

  void _stopWaiting() {
    _waitingFor = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _waitClock.stop();
  }

  void _linked(String deviceId) {
    _stopWaiting();
    _linkedDeviceId = deviceId;
    _step = SetupStep.linked;
    _emit();
  }

  /// linked with no child chosen: assigns the new device. Throws on failure.
  Future<void> assignLinked(String childId) async {
    final deviceId = _linkedDeviceId;
    if (deviceId == null || _busy) return;
    _busy = true;
    _emit();
    try {
      await _devices.assign(deviceId, childId: childId);
      _childId = childId;
    } finally {
      _busy = false;
      _emit();
    }
  }

  /// One step back inside the flow. False when the route should close.
  bool back() {
    switch (_step) {
      case SetupStep.intro || SetupStep.wifiDone || SetupStep.linked:
        return false;
      case SetupStep.joining:
        // The device answers within 25 s; the flow waits for it.
        return true;
      case SetupStep.permissions ||
          SetupStep.scanning ||
          SetupStep.pick ||
          SetupStep.connecting ||
          SetupStep.networks:
        _attempt++;
        unawaited(_closeBluetooth());
        _step = SetupStep.intro;
      case SetupStep.password || SetupStep.wifiFailed:
        passwordField.clear();
        _step = SetupStep.networks;
      case SetupStep.code:
        if (_codeFrom == SetupStep.wifiDone) {
          _step = SetupStep.wifiDone;
        } else {
          _step = SetupStep.intro;
        }
      case SetupStep.waiting:
        _stopWaiting();
        _toCode();
    }
    _emit();
    return true;
  }

  Future<void> _stopScan() async {
    final subscription = _scanSubscription;
    _scanSubscription = null;
    await subscription?.cancel();
    await _provisioner.stopScan();
  }

  /// Leaving Bluetooth behind: the scan stops and the link drops (§8.1).
  Future<void> _closeBluetooth() async {
    final session = _session;
    _session = null;
    await _stopScan();
    if (session != null) await session.close();
  }

  static String _reasonOf(Object? error) => switch (error) {
    ProvisionException(:final failure) => failure.name,
    TimeoutException() => 'timeout',
    _ => 'other',
  };

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _attempt++;
    _stopWaiting();
    unawaited(_scanSubscription?.cancel());
    _scanSubscription = null;
    unawaited(_provisioner.stopScan());
    final session = _session;
    _session = null;
    if (session != null) unawaited(session.close());
    passwordField.clear();
    passwordField.dispose();
    ssidField.dispose();
    super.dispose();
  }
}
