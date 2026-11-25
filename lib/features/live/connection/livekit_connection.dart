import 'dart:async';

import 'package:aule/core/log/app_log.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../data/live_models.dart';
import 'live_connection.dart';

/// Builds [LiveKitConnection]s. In release builds it turns LiveKit's own
/// logging off, once, the first time one is created (§6.10).
class LiveKitConnector implements LiveConnector {
  LiveKitConnector() {
    if (kReleaseMode && !_loggingOff) {
      _loggingOff = true;
      disableLogging();
    }
  }

  static bool _loggingOff = false;

  @override
  LiveConnection create() => LiveKitConnection();
}

/// One adult in one session's LiveKit room (§9.3).
///
/// - Audio only: it never subscribes to video and never publishes a camera.
/// - It joins listening, with the microphone off, and turns the microphone
///   on only once the platform granted it.
/// - The token lives only in memory, and nothing about the participants is
///   logged.
/// - The Room lives only inside this class.
class LiveKitConnection extends LiveConnection {
  LiveKitConnection();

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  LiveLink _link = LiveLink.idle;
  Set<LiveSpeaker> _speaking = const <LiveSpeaker>{};
  bool _canTalk = false;
  bool _microphoneOn = false;
  bool _otherAdult = false;
  LiveEndReason? _endReason;
  bool _leaving = false;
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
    // §9.2: never be a hidden participant, never publish data or video, and
    // join listening only.
    if (!join.grants.joinable) {
      throw StateError('the join token is not acceptable');
    }
    if (_link != LiveLink.idle) throw StateError('a connection is used once');
    _setLink(LiveLink.connecting);
    final room = Room(roomOptions: const RoomOptions());
    _room = room;
    final listener = room.createListener();
    _listener = listener;
    listener
      ..on<TrackPublishedEvent>((event) {
        if (event.publication.kind == TrackType.AUDIO) {
          unawaited(_subscribe(event.publication));
        }
      })
      ..on<ActiveSpeakersChangedEvent>((event) => _onSpeakers(event.speakers))
      ..on<ParticipantPermissionsUpdatedEvent>((event) {
        if (event.participant is LocalParticipant) {
          _onPermissions(event.permissions);
        }
      })
      ..on<ParticipantConnectedEvent>((_) => _updateAdults())
      ..on<ParticipantDisconnectedEvent>((_) => _updateAdults())
      ..on<RoomReconnectingEvent>((_) => _setLink(LiveLink.reconnecting))
      ..on<RoomReconnectedEvent>((_) => _setLink(LiveLink.connected))
      ..on<RoomDisconnectedEvent>((event) => _onDisconnected(event.reason));
    try {
      await room.connect(
        join.serverUrl,
        join.token,
        connectOptions: const ConnectOptions(autoSubscribe: false),
      );
    } on Object {
      await _teardown();
      _endReason ??= LiveEndReason.failed;
      _setLink(LiveLink.disconnected);
      rethrow;
    }
    if (_leaving) return;
    // After the connect: the audio settings reach WebRTC's audio device
    // module, which exists only once a room has connected.
    await _prepareAudio();
    // Left, or dropped by the room, while the audio was being set up.
    if (_leaving || !identical(_room, room)) return;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        unawaited(_subscribe(publication));
      }
    }
    _canTalk = room.localParticipant?.permissions.canPublish ?? false;
    _updateAdults(notify: false);
    _setLink(LiveLink.connected);
  }

  @override
  Future<void> setMicrophone(bool on) async {
    final participant = _room?.localParticipant;
    if (participant == null || _link == LiveLink.disconnected) {
      throw StateError('not in the room');
    }
    if (on && !_canTalk) {
      throw StateError('the platform has not granted the microphone');
    }
    await participant.setMicrophoneEnabled(on);
    _microphoneOn = on;
    _emit();
  }

  @override
  Future<void> leave() async {
    if (_leaving) return;
    _leaving = true;
    _endReason ??= LiveEndReason.left;
    await _teardown();
    _clearMedia();
    _setLink(LiveLink.disconnected);
  }

  /// Prefers the speaker, and on iOS makes a mute stop the microphone input
  /// itself. Each is tried on its own; a failure is logged by step only, and
  /// the defaults still play the session.
  Future<void> _prepareAudio() async {
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(true);
    } on Object {
      AppLog.warn('live.audio_setup_failed', <String, Object>{
        'step': 'speaker',
      });
    }
    try {
      await AudioManager.instance.setMicrophoneMuteMode(
        MicrophoneMuteMode.restart,
      );
    } on Object {
      AppLog.warn('live.audio_setup_failed', <String, Object>{
        'step': 'mute_mode',
      });
    }
  }

  /// Audio only: a video publication is never subscribed to.
  Future<void> _subscribe(RemoteTrackPublication publication) async {
    if (publication.kind != TrackType.AUDIO || publication.subscribed) return;
    try {
      await publication.subscribe();
    } on Object {
      // A later publish event tries again.
    }
  }

  void _onSpeakers(List<Participant> speakers) {
    final next = <LiveSpeaker>{};
    for (final participant in speakers) {
      final who = _speakerOf(participant);
      if (who != null) next.add(who);
    }
    _speaking = Set<LiveSpeaker>.unmodifiable(next);
    _emit();
  }

  static LiveSpeaker? _speakerOf(Participant participant) {
    if (participant is LocalParticipant) return LiveSpeaker.me;
    final identity = participant.identity;
    if (identity.startsWith('child-')) return LiveSpeaker.child;
    if (participant.kind == ParticipantKind.AGENT) return LiveSpeaker.tutor;
    if (identity.startsWith('guardian-')) return LiveSpeaker.otherAdult;
    return null;
  }

  void _onPermissions(ParticipantPermissions permissions) {
    _canTalk = permissions.canPublish;
    if (!_canTalk && _microphoneOn) {
      // The platform took the microphone back: stop sending at once.
      _microphoneOn = false;
      unawaited(
        _room?.localParticipant
            ?.setMicrophoneEnabled(false)
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
    _emit();
  }

  void _updateAdults({bool notify = true}) {
    final room = _room;
    _otherAdult =
        room != null &&
        room.remoteParticipants.values.any(
          (participant) => participant.identity.startsWith('guardian-'),
        );
    if (notify) _emit();
  }

  void _onDisconnected(DisconnectReason? reason) {
    _endReason ??= switch (reason) {
      DisconnectReason.roomDeleted ||
      DisconnectReason.roomClosed => LiveEndReason.sessionEnded,
      DisconnectReason.participantRemoved => LiveEndReason.removed,
      DisconnectReason.duplicateIdentity => LiveEndReason.replaced,
      _ => _leaving ? LiveEndReason.left : LiveEndReason.failed,
    };
    unawaited(_teardown());
    _clearMedia();
    _setLink(LiveLink.disconnected);
  }

  /// The listener first, then the room: disconnect, then dispose.
  Future<void> _teardown() async {
    final listener = _listener;
    _listener = null;
    final room = _room;
    _room = null;
    try {
      await listener?.dispose();
    } on Object {
      // Already cancelled.
    }
    if (room == null) return;
    try {
      await room.disconnect();
    } on Object {
      // Already disconnected.
    }
    try {
      await room.dispose();
    } on Object {
      // Already disposed.
    }
  }

  void _clearMedia() {
    _speaking = const <LiveSpeaker>{};
    _canTalk = false;
    _microphoneOn = false;
    _otherAdult = false;
  }

  void _setLink(LiveLink link) {
    _link = link;
    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (!_leaving) unawaited(leave());
    super.dispose();
  }
}
