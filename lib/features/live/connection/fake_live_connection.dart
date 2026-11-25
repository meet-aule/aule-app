import 'dart:async';

import '../data/live_models.dart';
import 'live_connection.dart';

/// How the demo's FakeLiveApi tells the demo's rooms about a mode change,
/// as the platform would through LiveKit. Demo mode and tests only: nothing
/// here touches the network.
abstract final class FakeLiveRooms {
  static final _modes = StreamController<(String, LiveMode)>.broadcast();

  /// (room, mode) for every PUT /sessions/{id}/join the fake answers.
  static Stream<(String, LiveMode)> get modes => _modes.stream;

  static void setMode(String room, LiveMode mode) => _modes.add((room, mode));
}

/// The demo's connector: no LiveKit, no audio, no network.
class FakeLiveConnector implements LiveConnector {
  FakeLiveConnector({
    this.connectAfter = const Duration(seconds: 1),
    this.grantAfter = const Duration(seconds: 1),
    this.cycleSpeakers = true,
  });

  final Duration connectAfter;

  /// How long after `setMode(speak)` the fake grants the microphone.
  final Duration grantAfter;

  /// Whether who is talking cycles: tutor 4 s, child 3 s, quiet 1 s.
  final bool cycleSpeakers;

  FakeLiveConnection? _last;

  /// The connection created last, for tests.
  FakeLiveConnection? get last => _last;

  @override
  LiveConnection create() => _last = FakeLiveConnection(
    connectAfter: connectAfter,
    grantAfter: grantAfter,
    cycleSpeakers: cycleSpeakers,
  );
}

/// A pretend room. It connects after [connectAfter], cycles the speakers,
/// and grants the microphone [grantAfter] the fake platform switched it to
/// speak.
class FakeLiveConnection extends LiveConnection {
  FakeLiveConnection({
    this.connectAfter = const Duration(seconds: 1),
    this.grantAfter = const Duration(seconds: 1),
    this.cycleSpeakers = true,
  });

  final Duration connectAfter;
  final Duration grantAfter;
  final bool cycleSpeakers;

  static const _listening = <(LiveSpeaker?, Duration)>[
    (LiveSpeaker.tutor, Duration(seconds: 4)),
    (LiveSpeaker.child, Duration(seconds: 3)),
    (null, Duration(seconds: 1)),
  ];

  /// While the adult talks, the tutor holds its turns (§9.4).
  static const _talking = <(LiveSpeaker?, Duration)>[
    (LiveSpeaker.me, Duration(seconds: 3)),
    (LiveSpeaker.child, Duration(seconds: 3)),
    (null, Duration(seconds: 1)),
  ];

  LiveLink _link = LiveLink.idle;
  Set<LiveSpeaker> _speaking = const <LiveSpeaker>{};
  bool _canTalk = false;
  bool _microphoneOn = false;
  bool _otherAdult = false;
  LiveEndReason? _endReason;
  String? _room;
  StreamSubscription<(String, LiveMode)>? _modes;
  Timer? _speakerTimer;
  Timer? _grantTimer;
  int _turn = 0;
  bool _disposed = false;

  @override
  LiveLink get link => _link;

  @override
  Set<LiveSpeaker> get speaking => _speaking;

  @override
  bool get canTalk => _canTalk;

  @override
  bool get microphoneOn => _microphoneOn;

  @override
  bool get otherAdultPresent => _otherAdult;

  @override
  LiveEndReason? get endReason => _endReason;

  @override
  Future<void> connect(LiveJoin join) async {
    if (!join.grants.joinable) {
      throw StateError('the join token is not acceptable');
    }
    if (_link != LiveLink.idle) throw StateError('a connection is used once');
    _room = join.room;
    _link = LiveLink.connecting;
    _emit();
    _modes = FakeLiveRooms.modes.listen(_onMode);
    await Future<void>.delayed(connectAfter);
    if (_endReason != null) return;
    _link = LiveLink.connected;
    _emit();
    if (cycleSpeakers) _nextSpeaker();
  }

  void _nextSpeaker() {
    if (_link != LiveLink.connected || _disposed) return;
    final cycle = _microphoneOn ? _talking : _listening;
    final (speaker, duration) = cycle[_turn % cycle.length];
    _turn++;
    _speaking = speaker == null
        ? const <LiveSpeaker>{}
        : Set<LiveSpeaker>.unmodifiable(<LiveSpeaker>{speaker});
    _emit();
    _speakerTimer = Timer(duration, _nextSpeaker);
  }

  void _onMode((String, LiveMode) change) {
    final (room, mode) = change;
    if (room != _room || _endReason != null) return;
    _grantTimer?.cancel();
    if (mode == LiveMode.speak) {
      _grantTimer = Timer(grantAfter, () {
        if (_endReason != null) return;
        _canTalk = true;
        _emit();
      });
    } else {
      _canTalk = false;
      _microphoneOn = false;
      _emit();
    }
  }

  @override
  Future<void> setMicrophone(bool on) async {
    if (_endReason != null) throw StateError('not in the room');
    if (on && !_canTalk) throw StateError('the microphone was not granted');
    _microphoneOn = on;
    _emit();
  }

  @override
  Future<void> leave() async => _stop(LiveEndReason.left);

  /// For the demo and tests: the room ends from the platform's side.
  void endFromServer(LiveEndReason reason) => _stop(reason);

  /// For tests: the link drops, or comes back.
  void setReconnecting(bool reconnecting) {
    if (_endReason != null) return;
    _link = reconnecting ? LiveLink.reconnecting : LiveLink.connected;
    _emit();
  }

  /// For tests: another guardian joins or leaves.
  void setOtherAdult(bool present) {
    _otherAdult = present;
    _emit();
  }

  void _stop(LiveEndReason reason) {
    if (_link == LiveLink.disconnected) return;
    _endReason ??= reason;
    _link = LiveLink.disconnected;
    _speaking = const <LiveSpeaker>{};
    _canTalk = false;
    _microphoneOn = false;
    _speakerTimer?.cancel();
    _grantTimer?.cancel();
    unawaited(_modes?.cancel());
    _modes = null;
    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _speakerTimer?.cancel();
    _grantTimer?.cancel();
    unawaited(_modes?.cancel());
    super.dispose();
  }
}
