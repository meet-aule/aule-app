import 'dart:convert';

import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/fake/demo_data.dart';

import '../connection/fake_live_connection.dart';
import 'live_api.dart';
import 'live_models.dart';

/// The demo's join routes, following the contract proposed in §9.4. Only
/// Mati's live session, [DemoData.liveSessionId], can be joined.
class FakeLiveApi implements LiveApi {
  FakeLiveApi({this.latency = const Duration(milliseconds: 350)});

  final Duration latency;

  static const _notActive = ApiException(
    ApiErrorKind.conflict,
    status: 409,
    code: 'conflict',
    message: 'the session is not active',
  );

  /// The room the platform opens for a session.
  static String roomFor(String sessionId) => 'session-$sessionId';

  @override
  Future<LiveJoin> join(
    String sessionId, {
    LiveMode mode = LiveMode.listen,
  }) async {
    await Future<void>.delayed(latency);
    if (sessionId != DemoData.liveSessionId) throw _notActive;
    final room = roomFor(sessionId);
    return LiveJoin(
      // Never dialled: the fake connection has no network.
      serverUrl: 'wss://demo.invalid',
      room: room,
      token: demoToken(room: room, mode: mode),
      expiresInSeconds: 960,
      identity: 'guardian-${DemoData.guardianId.replaceAll('-', '')}',
    );
  }

  @override
  Future<void> setMode(String sessionId, LiveMode mode) async {
    await Future<void>.delayed(latency);
    if (sessionId != DemoData.liveSessionId) throw _notActive;
    FakeLiveRooms.setMode(roomFor(sessionId), mode);
  }

  /// A JWT-shaped token with the grants §9.4 asks of the platform: visible,
  /// no data, and the microphone only in speak mode. Its signature is not
  /// real; nothing checks it in demo mode.
  static String demoToken({
    required String room,
    LiveMode mode = LiveMode.listen,
    Map<String, Object> overrides = const <String, Object>{},
  }) {
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final speak = mode == LiveMode.speak;
    final video = <String, Object>{
      'room': room,
      'roomJoin': true,
      'canSubscribe': true,
      'canPublish': speak,
      if (speak) 'canPublishSources': <String>['microphone'],
      'canPublishData': false,
      'hidden': false,
      ...overrides,
    };
    final header = part(<String, Object>{'alg': 'none', 'typ': 'JWT'});
    final payload = part(<String, Object>{
      'sub': 'guardian-demo',
      'video': video,
      'attributes': <String, String>{
        'aule.role': 'guardian',
        'aule.mode': mode.name,
        'aule.relationship': '',
      },
    });
    return '$header.$payload.demo';
  }
}
