import 'dart:async';

import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/aule_api.dart';
import 'package:aule/core/api/fake/demo_data.dart';
import 'package:aule/core/api/models/models.dart';
import 'package:aule/features/live/connection/fake_live_connection.dart';
import 'package:aule/features/live/connection/live_connection.dart';
import 'package:aule/features/live/data/fake_live_api.dart';
import 'package:aule/features/live/data/live_api.dart';
import 'package:aule/features/live/data/live_models.dart';
import 'package:aule/features/live/ui/live_session_controller.dart';
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

/// The two session calls the live screen makes; nothing else is used.
class _SessionApi implements AuleApi {
  int remainingSeconds = 600;
  String status = 'active';
  int ends = 0;
  Object? endError;

  @override
  Future<SessionStatus> session(String sessionId) async => SessionStatus(
    status: status,
    remainingSeconds: remainingSeconds,
    canResume: false,
    language: 'es',
    engine: true,
  );

  @override
  Future<void> endSession(String sessionId) async {
    ends++;
    final error = endError;
    if (error != null) throw error;
    status = 'ended';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Platform extends LivePlatform {
  _Platform({this.microphone = true});

  final bool microphone;
  final screenOn = <bool>[];
  int microphoneAsks = 0;

  @override
  Future<void> keepScreenOn(bool on) async => screenOn.add(on);

  @override
  Future<bool> requestMicrophone() async {
    microphoneAsks++;
    return microphone;
  }
}

/// A join route that answers [error], or a join with [token]. With
/// [grants], mode changes reach the demo rooms as the platform's would;
/// the first [listenFailures] listen requests fail.
class _ScriptedLiveApi implements LiveApi {
  _ScriptedLiveApi({
    this.error,
    this.token,
    this.grants = false,
    this.listenFailures = 0,
  });

  final ApiException? error;
  final String? token;
  final bool grants;
  int listenFailures;
  final modes = <LiveMode>[];

  @override
  Future<LiveJoin> join(
    String sessionId, {
    LiveMode mode = LiveMode.listen,
  }) async {
    final refusal = error;
    if (refusal != null) throw refusal;
    return LiveJoin(
      serverUrl: 'wss://example.invalid',
      room: 'session-$sessionId',
      token: token ?? FakeLiveApi.demoToken(room: 'session-$sessionId'),
      expiresInSeconds: 600,
      identity: 'guardian-x',
    );
  }

  @override
  Future<void> setMode(String sessionId, LiveMode mode) async {
    modes.add(mode);
    if (mode == LiveMode.listen && listenFailures > 0) {
      listenFailures--;
      throw const ApiException(ApiErrorKind.network);
    }
    if (grants) FakeLiveRooms.setMode(FakeLiveApi.roomFor(sessionId), mode);
  }
}

void main() {
  late FakeLiveConnector connector;
  late _SessionApi api;
  late _Platform platform;
  late List<String> refreshes;

  setUp(() {
    connector = FakeLiveConnector(
      connectAfter: const Duration(milliseconds: 10),
      grantAfter: const Duration(milliseconds: 10),
      cycleSpeakers: false,
    );
    api = _SessionApi();
    platform = _Platform();
    refreshes = <String>[];
  });

  LiveSessionController liveFor({
    LiveApi? live,
    bool enabled = true,
    Duration grantTimeout = const Duration(seconds: 1),
  }) {
    final controller = LiveSessionController(
      sessionId: DemoData.liveSessionId,
      live: live ?? FakeLiveApi(latency: Duration.zero),
      connector: connector,
      api: api,
      enabled: enabled,
      platform: platform,
      onEnded: () async => refreshes.add('progress'),
      grantTimeout: grantTimeout,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('with liveJoin off it stays "soon" and joins nothing', () async {
    final live = liveFor(enabled: false);
    expect(live.phase, LivePhase.soon);
    await live.start();
    expect(live.phase, LivePhase.soon);
    expect(connector.last, isNull);
  });

  test(
    'it joins listening, keeps the screen on, shows the time left',
    () async {
      api.remainingSeconds = 840;
      final live = liveFor();
      expect(live.phase, LivePhase.connecting);
      await live.start();
      expect(live.phase, LivePhase.listening);
      await until(live, () => live.minutesLeft != null);
      expect(live.minutesLeft, 14);
      expect(platform.screenOn, <bool>[true]);
      expect(live.microphoneOn, isFalse);
      expect(platform.microphoneAsks, 0, reason: 'no prompt while listening');
      expect(live.canStepIn, isTrue);
    },
  );

  test('step in, mute and unmute, then hand back to Aule', () async {
    final live = liveFor();
    await live.start();
    expect(await live.stepIn(), StepInResult.talking);
    expect(live.phase, LivePhase.talking);
    expect(live.microphoneOn, isTrue);
    expect(platform.microphoneAsks, 1);

    await live.setMuted(true);
    expect(live.microphoneOn, isFalse);
    await live.setMuted(false);
    expect(live.microphoneOn, isTrue);

    await live.handBack();
    expect(live.phase, LivePhase.listening);
    expect(live.microphoneOn, isFalse);
    // The platform takes the microphone back.
    await until(connector.last!, () => !connector.last!.canTalk);
  });

  test('a refused microphone keeps the adult listening', () async {
    platform = _Platform(microphone: false);
    final live = liveFor();
    await live.start();
    expect(await live.stepIn(), StepInResult.micDenied);
    expect(live.phase, LivePhase.listening);
    expect(live.microphoneOn, isFalse);
  });

  test('no grant in time fails the step-in, and asks to listen', () async {
    connector = FakeLiveConnector(
      connectAfter: const Duration(milliseconds: 10),
      grantAfter: const Duration(seconds: 5),
      cycleSpeakers: false,
    );
    final scripted = _ScriptedLiveApi();
    final live = liveFor(
      live: scripted,
      grantTimeout: const Duration(milliseconds: 50),
    );
    await live.start();
    expect(await live.stepIn(), StepInResult.failed);
    expect(live.phase, LivePhase.listening);
    expect(live.microphoneOn, isFalse);
    expect(scripted.modes, <LiveMode>[LiveMode.speak, LiveMode.listen]);
  });

  test('the platform taking the microphone back ends talking', () async {
    final live = liveFor();
    await live.start();
    await live.stepIn();
    expect(live.phase, LivePhase.talking);
    FakeLiveRooms.setMode(
      FakeLiveApi.roomFor(DemoData.liveSessionId),
      LiveMode.listen,
    );
    await until(live, () => live.phase == LivePhase.listening);
    expect(live.microphoneOn, isFalse);
  });

  test('ending the session ends it for everyone, then refreshes', () async {
    final live = liveFor();
    await live.start();
    await live.end();
    expect(api.ends, 1);
    expect(live.phase, LivePhase.ended);
    expect(connector.last!.link, LiveLink.disconnected);
    expect(refreshes, <String>['progress']);
    expect(platform.screenOn, <bool>[true, false]);
  });

  test('a refused end keeps the adult listening', () async {
    api.endError = const ApiException(ApiErrorKind.network);
    final live = liveFor();
    await live.start();
    await expectLater(live.end(), throwsA(isA<ApiException>()));
    expect(live.phase, LivePhase.listening);
    expect(live.ending, isFalse);
    expect(refreshes, isEmpty);
  });

  test('leaving leaves the room, and the screen may sleep', () async {
    final live = liveFor();
    await live.start();
    await live.leave();
    expect(live.phase, LivePhase.left);
    expect(connector.last!.link, LiveLink.disconnected);
    expect(connector.last!.endReason, LiveEndReason.left);
    expect(platform.screenOn, <bool>[true, false]);
    expect(api.ends, 0, reason: 'leaving does not end the session');
  });

  test('disposing the screen leaves the room', () async {
    final live = LiveSessionController(
      sessionId: DemoData.liveSessionId,
      live: FakeLiveApi(latency: Duration.zero),
      connector: connector,
      api: api,
      enabled: true,
      platform: platform,
    );
    await live.start();
    final room = connector.last!;
    live.dispose();
    await until(room, () => room.link == LiveLink.disconnected);
    expect(room.endReason, LiveEndReason.left);
  });

  group('the room ends from the other side', () {
    for (final (reason, phase) in const <(LiveEndReason, LivePhase)>[
      (LiveEndReason.sessionEnded, LivePhase.ended),
      (LiveEndReason.removed, LivePhase.removed),
      (LiveEndReason.replaced, LivePhase.removed),
      (LiveEndReason.failed, LivePhase.failed),
    ]) {
      test(reason.name, () async {
        final live = liveFor();
        await live.start();
        connector.last!.endFromServer(reason);
        expect(live.phase, phase);
        expect(live.replaced, reason == LiveEndReason.replaced);
        expect(
          refreshes,
          reason == LiveEndReason.sessionEnded ? <String>['progress'] : isEmpty,
        );
      });
    }
  });

  test('a session the platform reports ended ends the screen', () async {
    api.status = 'ended';
    final live = liveFor();
    await live.start();
    await until(live, () => live.phase == LivePhase.ended);
    expect(connector.last!.link, LiveLink.disconnected);
  });

  test('reconnecting, and another adult in the room', () async {
    final live = liveFor();
    await live.start();
    final room = connector.last!;
    room.setReconnecting(true);
    expect(live.reconnecting, isTrue);
    expect(live.canStepIn, isFalse);
    room.setReconnecting(false);
    expect(live.reconnecting, isFalse);
    room.setOtherAdult(true);
    expect(live.otherAdult, isTrue);
  });

  test('who is talking comes from the room', () async {
    connector = FakeLiveConnector(
      connectAfter: const Duration(milliseconds: 10),
      cycleSpeakers: true,
    );
    final live = liveFor();
    await live.start();
    // The fake starts with the tutor, for 4 s.
    expect(live.speaker, LiveSpeaker.tutor);
  });

  group('a refused join (§9.3)', () {
    for (final (error, failure) in const <(ApiException, LiveFailure)>[
      (
        ApiException(
          ApiErrorKind.conflict,
          status: 409,
          message: 'the session is not active',
        ),
        LiveFailure.notActive,
      ),
      (
        ApiException(
          ApiErrorKind.conflict,
          status: 409,
          message: 'another adult is already in the session',
        ),
        LiveFailure.busy,
      ),
      (ApiException(ApiErrorKind.forbidden, status: 403), LiveFailure.noVoice),
      (ApiException(ApiErrorKind.notFound, status: 404), LiveFailure.notFound),
      (ApiException(ApiErrorKind.unavailable, status: 503), LiveFailure.error),
    ]) {
      test('${error.status} ${error.message ?? ''}', () async {
        final live = liveFor(live: _ScriptedLiveApi(error: error));
        await live.start();
        expect(live.phase, LivePhase.failed);
        expect(live.failure, failure);
        expect(connector.last, isNull, reason: 'nothing connects');
        expect(platform.screenOn, isEmpty);
      });
    }
  });

  test('a join token that could already talk is never used', () async {
    final live = liveFor(
      live: _ScriptedLiveApi(
        token: FakeLiveApi.demoToken(room: 'session-x', mode: LiveMode.speak),
      ),
    );
    await live.start();
    expect(live.phase, LivePhase.failed);
    expect(live.failure, LiveFailure.error);
    expect(connector.last, isNull);
  });

  test('a hand-back the platform did not hear keeps a retry', () async {
    final scripted = _ScriptedLiveApi(grants: true, listenFailures: 1);
    final live = liveFor(live: scripted);
    await live.start();
    expect(await live.stepIn(), StepInResult.talking);
    await live.handBack();
    expect(live.phase, LivePhase.listening);
    expect(live.microphoneOn, isFalse);
    expect(live.handBackPending, isTrue);
    // No new step-in on top of a grant the platform still holds.
    expect(live.canStepIn, isFalse);
    await live.retryHandBack();
    expect(live.handBackPending, isFalse);
    expect(scripted.modes, <LiveMode>[
      LiveMode.speak,
      LiveMode.listen,
      LiveMode.listen,
    ]);
    await until(connector.last!, () => !connector.last!.canTalk);
    expect(live.canStepIn, isTrue);
  });

  test('leaving while talking asks for listen mode on the way out', () async {
    final scripted = _ScriptedLiveApi(grants: true);
    final live = liveFor(live: scripted);
    await live.start();
    expect(await live.stepIn(), StepInResult.talking);
    await live.leave();
    expect(live.phase, LivePhase.left);
    expect(scripted.modes, <LiveMode>[LiveMode.speak, LiveMode.listen]);
  });

  test('demo mode asks the OS for no microphone', () async {
    expect(await const DemoLivePlatform().requestMicrophone(), isTrue);
  });

  test('a token that would hide the adult is never used', () async {
    final live = liveFor(
      live: _ScriptedLiveApi(
        token: FakeLiveApi.demoToken(
          room: 'session-x',
          overrides: const <String, Object>{'hidden': true},
        ),
      ),
    );
    await live.start();
    expect(live.phase, LivePhase.failed);
    expect(live.failure, LiveFailure.error);
    expect(connector.last, isNull);
  });

  test('the demo joins only the seeded live session', () async {
    final live = LiveSessionController(
      sessionId: 'another-session',
      live: FakeLiveApi(latency: Duration.zero),
      connector: connector,
      api: api,
      enabled: true,
      platform: platform,
    );
    addTearDown(live.dispose);
    await live.start();
    expect(live.phase, LivePhase.failed);
    expect(live.failure, LiveFailure.notActive);
  });
}
