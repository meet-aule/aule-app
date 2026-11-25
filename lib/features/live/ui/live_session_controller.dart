import 'dart:async';

import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/aule_api.dart';
import 'package:aule/core/log/app_log.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../connection/live_connection.dart';
import '../data/live_api.dart';
import '../data/live_models.dart';

/// Where the live screen stands (§4.9).
enum LivePhase {
  /// Flag `liveJoin` off: reached only by a stale link.
  soon,
  connecting,
  listening,
  talking,
  ended,

  /// The join was refused, or the room failed.
  failed,

  /// Removed from the room, or replaced by the same adult on another phone.
  removed,

  /// The adult left.
  left,
}

enum LiveFailure { notActive, busy, noVoice, notFound, error }

enum StepInResult { talking, micDenied, failed, ignored }

/// The phone's side of a live session that is not LiveKit: keeping the
/// screen on, and the microphone prompt. Tests swap it.
class LivePlatform {
  const LivePlatform();

  Future<void> keepScreenOn(bool on) async {
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } on Object {
      // The session works with the screen's own timeout too.
    }
  }

  /// Asks the OS for the microphone, only when the parent steps in.
  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted || status.isLimited;
  }
}

/// Demo mode: no OS microphone prompt, because the demo room hears nothing.
/// The screen is still kept on.
class DemoLivePlatform extends LivePlatform {
  const DemoLivePlatform();

  @override
  Future<bool> requestMicrophone() async => true;
}

/// The view model of /live/:sessionId (§9.3).
///
/// It always joins listening first, so the child hears that an adult joined
/// before any step-in. The microphone goes on only after the platform
/// granted it and the parent confirmed. Nothing about the session or its
/// participants is logged, and nothing is recorded.
class LiveSessionController extends ChangeNotifier {
  LiveSessionController({
    required this.sessionId,
    required LiveApi live,
    required LiveConnector connector,
    required AuleApi api,
    required bool enabled,
    this.platform = const LivePlatform(),
    this.onEnded,
    this.grantTimeout = const Duration(seconds: 10),
    this.statusEvery = const Duration(seconds: 30),
  }) : _live = live,
       _connector = connector,
       _api = api,
       _phase = enabled ? LivePhase.connecting : LivePhase.soon;

  final String sessionId;
  final LiveApi _live;
  final LiveConnector _connector;
  final AuleApi _api;
  final LivePlatform platform;

  /// Called once the session ended, to refresh what Progress shows.
  final Future<void> Function()? onEnded;

  /// How long the platform has to grant the microphone after a step-in.
  final Duration grantTimeout;

  /// How often the time left is asked.
  final Duration statusEvery;

  LivePhase _phase;
  LiveFailure? _failure;
  Object? _error;
  LiveEndReason? _endReason;
  LiveConnection? _connection;
  Timer? _statusTimer;
  int? _minutesLeft;
  bool _started = false;
  bool _stepping = false;
  bool _ending = false;
  bool _handBackPending = false;
  bool _endedNotified = false;
  bool _awake = false;
  bool _disposed = false;

  LivePhase get phase => _phase;

  /// Why the join failed, when [phase] is [LivePhase.failed].
  LiveFailure? get failure => _failure;

  /// The error behind [LiveFailure.error], for `errorText`.
  Object? get error => _error;

  /// With [LivePhase.removed]: the same adult joined from another phone.
  bool get replaced => _endReason == LiveEndReason.replaced;

  /// Listening or talking, or on the way there.
  bool get isLive =>
      _phase == LivePhase.connecting ||
      _phase == LivePhase.listening ||
      _phase == LivePhase.talking;

  bool get reconnecting => _connection?.link == LiveLink.reconnecting;

  /// Who is talking now, or null when nobody is.
  LiveSpeaker? get speaker {
    final speaking = _connection?.speaking ?? const <LiveSpeaker>{};
    for (final who in const [
      LiveSpeaker.me,
      LiveSpeaker.child,
      LiveSpeaker.tutor,
    ]) {
      if (speaking.contains(who)) return who;
    }
    return null;
  }

  /// Whole minutes left in the session; null until the first answer.
  int? get minutesLeft => _minutesLeft;
  bool get otherAdult => _connection?.otherAdultPresent ?? false;
  bool get microphoneOn => _connection?.microphoneOn ?? false;

  /// A step-in is on its way.
  bool get stepping => _stepping;

  /// The end of the session was asked for.
  bool get ending => _ending;

  /// The platform has not heard that the adult handed back, so the tutor
  /// may still be paused. The listening page offers a retry.
  bool get handBackPending => _handBackPending;

  /// Listening, with nothing on its way, and with no microphone grant left
  /// over from an earlier step-in: a new step-in waits for a fresh grant.
  bool get canStepIn =>
      _phase == LivePhase.listening &&
      !_stepping &&
      !_ending &&
      !_handBackPending &&
      !reconnecting &&
      !(_connection?.canTalk ?? false);

  /// Joins listening (§9.3): asks the platform, checks the token's grants,
  /// connects, keeps the screen on, then follows the time left.
  Future<void> start() async {
    if (_started || _phase != LivePhase.connecting) return;
    _started = true;
    final LiveJoin join;
    try {
      join = await _live.join(sessionId);
    } on ApiException catch (error) {
      AppLog.warn('live.join_failed', <String, Object>{
        'kind': error.kind.name,
      });
      _fail(_failureOf(error), error);
      return;
    } on Object catch (error) {
      _fail(LiveFailure.error, error);
      return;
    }
    if (!isLive || _disposed) return;
    if (!join.grants.joinable) {
      // §9.2: a hidden, data or camera token is never used, and the join
      // token listens only: the microphone is granted later, after the tutor
      // has told the child.
      AppLog.warn('live.token_refused');
      _fail(LiveFailure.error, StateError('the join token is not acceptable'));
      return;
    }
    final connection = _connector.create();
    _connection = connection;
    connection.addListener(_onConnection);
    try {
      await connection.connect(join);
    } on Object catch (error) {
      if (!isLive || _disposed) return;
      AppLog.warn('live.connect_failed');
      unawaited(_leaveRoom());
      _fail(LiveFailure.error, error);
      return;
    }
    if (!isLive || _disposed) {
      unawaited(connection.leave());
      return;
    }
    _awake = true;
    unawaited(platform.keepScreenOn(true));
    _statusTimer = Timer.periodic(
      statusEvery,
      (_) => unawaited(_refreshStatus()),
    );
    unawaited(_refreshStatus());
    _onConnection();
  }

  static LiveFailure _failureOf(ApiException error) => switch (error.kind) {
    // Two 409s, told apart by the platform's message (§9.3).
    ApiErrorKind.conflict =>
      (error.message ?? '').contains('another adult')
          ? LiveFailure.busy
          : LiveFailure.notActive,
    ApiErrorKind.forbidden => LiveFailure.noVoice,
    ApiErrorKind.notFound => LiveFailure.notFound,
    _ => LiveFailure.error,
  };

  void _fail(LiveFailure failure, Object error) {
    _failure = failure;
    _error = error;
    _phase = LivePhase.failed;
    _stopTimers();
    _releaseScreen();
    _emit();
  }

  void _onConnection() {
    final connection = _connection;
    if (connection == null || _disposed || !isLive) return;
    final reason = connection.endReason;
    if (reason != null) {
      // leave() and end() change the phase first, so only the room's own
      // ends get here.
      _endedBy(reason);
      return;
    }
    if (connection.link == LiveLink.connected &&
        _phase == LivePhase.connecting) {
      _phase = LivePhase.listening;
      AppLog.info('live.listening');
    }
    if (_phase == LivePhase.talking && !connection.canTalk) {
      // The platform took the microphone back.
      _phase = LivePhase.listening;
    }
    _emit();
  }

  void _endedBy(LiveEndReason reason) {
    AppLog.info('live.closed', <String, Object>{'reason': reason.name});
    _endReason = reason;
    switch (reason) {
      case LiveEndReason.sessionEnded:
        _phase = LivePhase.ended;
        unawaited(_notifyEnded());
      case LiveEndReason.removed || LiveEndReason.replaced:
        _phase = LivePhase.removed;
      case LiveEndReason.failed:
        _failure = LiveFailure.error;
        _error = StateError('the room closed');
        _phase = LivePhase.failed;
      case LiveEndReason.left:
        _phase = LivePhase.left;
    }
    _stopTimers();
    _releaseScreen();
    _emit();
  }

  /// After the step-in sheet was confirmed (§9.3): the OS prompt, the
  /// platform's grant within [grantTimeout], then the microphone.
  Future<StepInResult> stepIn() async {
    final connection = _connection;
    if (connection == null || !canStepIn) return StepInResult.ignored;
    _stepping = true;
    _emit();
    try {
      if (!await platform.requestMicrophone()) return StepInResult.micDenied;
      if (_phase != LivePhase.listening) return StepInResult.ignored;
      await _live.setMode(sessionId, LiveMode.speak);
      if (!await _waitForGrant(connection)) {
        // Nothing came: ask to be back in listen mode, quietly.
        _live.setMode(sessionId, LiveMode.listen).ignore();
        return StepInResult.failed;
      }
      if (_phase != LivePhase.listening) return StepInResult.ignored;
      await connection.setMicrophone(true);
      _phase = LivePhase.talking;
      AppLog.info('live.talking');
      return StepInResult.talking;
    } on Object {
      return StepInResult.failed;
    } finally {
      _stepping = false;
      _emit();
    }
  }

  /// [canStepIn] made sure no grant was left over, so a grant seen after
  /// setMode(speak) is the platform's answer to this step-in.
  Future<bool> _waitForGrant(LiveConnection connection) async {
    if (connection.canTalk) return true;
    final granted = Completer<bool>();
    void check() {
      if (granted.isCompleted) return;
      if (connection.canTalk) {
        granted.complete(true);
      } else if (connection.endReason != null) {
        granted.complete(false);
      }
    }

    connection.addListener(check);
    try {
      return await granted.future.timeout(grantTimeout, onTimeout: () => false);
    } finally {
      connection.removeListener(check);
    }
  }

  /// "Silenciar" and "Activar micrófono". Throws on failure.
  Future<void> setMuted(bool muted) async {
    final connection = _connection;
    if (connection == null || _phase != LivePhase.talking) return;
    await connection.setMicrophone(!muted);
    _emit();
  }

  /// "Devolver a Aule": the microphone off at once, then listen mode. When
  /// the platform cannot be told, [handBackPending] stays true and the
  /// listening page offers [retryHandBack]. Throws only when the microphone
  /// could not be turned off here.
  Future<void> handBack() async {
    final connection = _connection;
    if (connection == null || _phase != LivePhase.talking) return;
    _phase = LivePhase.listening;
    _emit();
    try {
      await connection.setMicrophone(false);
    } finally {
      await _sendListen();
    }
  }

  /// The listening page's retry, while [handBackPending].
  Future<void> retryHandBack() async {
    if (!_handBackPending || !isLive) return;
    await _sendListen();
  }

  /// Tells the platform the adult stopped talking, so the tutor resumes.
  Future<void> _sendListen() async {
    try {
      await _live.setMode(sessionId, LiveMode.listen);
      _handBackPending = false;
    } on Object {
      AppLog.warn('live.hand_back_failed');
      _handBackPending = true;
    }
    _emit();
  }

  /// "Terminar", once confirmed: ends the session for everyone, then
  /// leaves the room. Throws when the platform refused; the adult is then
  /// still listening.
  Future<void> end() async {
    if (!isLive || _ending) return;
    _ending = true;
    _emit();
    try {
      await _api.endSession(sessionId);
    } on Object {
      _ending = false;
      _emit();
      rethrow;
    }
    await _endedHere();
  }

  /// "Salir", the back link, or the app going to the background: the
  /// adult leaves, and the child hears it. An adult who was talking also
  /// asks for listen mode on the way out, so the tutor is not left paused.
  Future<void> leave() async {
    if (!isLive) return;
    final talking = _phase == LivePhase.talking || _handBackPending;
    _phase = LivePhase.left;
    _endReason = LiveEndReason.left;
    _emit();
    if (talking) _live.setMode(sessionId, LiveMode.listen).ignore();
    await _leaveRoom();
  }

  Future<void> _refreshStatus() async {
    if (!isLive || _disposed) return;
    try {
      final status = await _api.session(sessionId);
      if (!isLive || _disposed) return;
      _minutesLeft = status.remainingSeconds ~/ 60;
      if (!status.isLive) {
        await _endedHere();
        return;
      }
      _emit();
    } on ApiException catch (error) {
      // A session that is gone has ended for this adult too.
      if (error.kind == ApiErrorKind.notFound && isLive) await _endedHere();
    } on Object {
      // Asked again at the next tick.
    }
  }

  Future<void> _endedHere() async {
    _phase = LivePhase.ended;
    _endReason = LiveEndReason.sessionEnded;
    _emit();
    await _leaveRoom();
    await _notifyEnded();
  }

  /// Tells Progress once, however the end was learnt.
  Future<void> _notifyEnded() async {
    if (_endedNotified) return;
    _endedNotified = true;
    try {
      await onEnded?.call();
    } on Object {
      // Progress refreshes on its own later.
    }
  }

  Future<void> _leaveRoom() async {
    _stopTimers();
    _releaseScreen();
    final connection = _connection;
    if (connection == null) return;
    try {
      await connection.leave();
    } on Object {
      // Gone already.
    }
  }

  void _stopTimers() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  void _releaseScreen() {
    if (!_awake) return;
    _awake = false;
    unawaited(platform.keepScreenOn(false));
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_phase == LivePhase.talking || _handBackPending) {
      // Closed while talking: the tutor should not stay paused.
      _live.setMode(sessionId, LiveMode.listen).ignore();
    }
    _disposed = true;
    _stopTimers();
    _releaseScreen();
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      connection.removeListener(_onConnection);
      unawaited(_close(connection));
    }
    super.dispose();
  }

  static Future<void> _close(LiveConnection connection) async {
    try {
      await connection.leave();
    } on Object {
      // Gone already.
    } finally {
      connection.dispose();
    }
  }
}
