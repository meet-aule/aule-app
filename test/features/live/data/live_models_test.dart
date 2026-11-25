import 'dart:convert';

import 'package:aule/features/live/data/fake_live_api.dart';
import 'package:aule/features/live/data/live_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A JWT-shaped token whose payload carries [video].
String tokenWith(Map<String, Object> video) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part(<String, String>{'alg': 'HS256'})}.'
      '${part(<String, Object>{'sub': 'guardian-x', 'video': video})}.sig';
}

LiveJoin joinWith(String token) => LiveJoin(
  serverUrl: 'wss://example.invalid',
  room: 'session-1',
  token: token,
  expiresInSeconds: 600,
  identity: 'guardian-x',
);

void main() {
  test('LiveJoin.fromJson reads the proposed answer (§9.4)', () {
    final join = LiveJoin.fromJson(<String, dynamic>{
      'serverUrl': 'wss://livekit.example.invalid',
      'room': 'session-abc',
      'token': 'a.b.c',
      'expiresInSeconds': 960,
      'identity': 'guardian-0193a1f0000070008000000000000002',
    });
    expect(join.serverUrl, 'wss://livekit.example.invalid');
    expect(join.room, 'session-abc');
    expect(join.token, 'a.b.c');
    expect(join.expiresInSeconds, 960);
    expect(join.identity, startsWith('guardian-'));
  });

  test('the token is never printed', () {
    final join = joinWith(tokenWith(const <String, Object>{}));
    expect(join.toString(), isNot(contains(join.token)));
    expect(join.toString(), 'LiveJoin(<redacted>)');
  });

  group('grants (§9.2)', () {
    test('the listen token the platform signs is acceptable', () {
      final grants = joinWith(
        tokenWith(const <String, Object>{
          'roomJoin': true,
          'room': 'session-1',
          'canSubscribe': true,
          'canPublish': false,
          'canPublishData': false,
          'hidden': false,
        }),
      ).grants;
      expect(grants.hidden, isFalse);
      expect(grants.canPublish, isFalse);
      expect(grants.canPublishData, isFalse);
      expect(grants.acceptable, isTrue);
    });

    test('a speak token with the microphone only is acceptable', () {
      final grants = joinWith(
        tokenWith(const <String, Object>{
          'roomJoin': true,
          'canPublish': true,
          'canPublishSources': <String>['microphone'],
          'canPublishData': false,
          'hidden': false,
        }),
      ).grants;
      expect(grants.sources, <String>['microphone']);
      expect(grants.acceptable, isTrue);
    });

    test('a hidden adult is refused', () {
      expect(
        joinWith(
          tokenWith(const <String, Object>{
            'canPublish': false,
            'canPublishData': false,
            'hidden': true,
          }),
        ).grants.acceptable,
        isFalse,
      );
    });

    test('publishing data is refused', () {
      expect(
        joinWith(
          tokenWith(const <String, Object>{
            'canPublish': false,
            'canPublishData': true,
          }),
        ).grants.acceptable,
        isFalse,
      );
    });

    test('the camera is refused', () {
      expect(
        joinWith(
          tokenWith(const <String, Object>{
            'canPublish': true,
            'canPublishSources': <String>['microphone', 'camera'],
            'canPublishData': false,
          }),
        ).grants.acceptable,
        isFalse,
      );
    });

    test("absent fields take LiveKit's defaults", () {
      // Nothing said: LiveKit lets it publish everything, data included.
      final open = joinWith(tokenWith(const <String, Object>{'roomJoin': true}))
          .grants;
      expect(open.canPublish, isTrue);
      expect(open.canPublishData, isTrue);
      expect(open.acceptable, isFalse);
      // canPublishData follows canPublish.
      final listen = joinWith(
        tokenWith(const <String, Object>{'canPublish': false}),
      ).grants;
      expect(listen.canPublishData, isFalse);
      expect(listen.acceptable, isTrue);
      // Publishing with no sources named means every source.
      final everything = joinWith(
        tokenWith(const <String, Object>{
          'canPublish': true,
          'canPublishData': false,
        }),
      ).grants;
      expect(everything.acceptable, isFalse);
    });

    test('an unreadable token is refused', () {
      String encoded(List<int> bytes) =>
          base64Url.encode(bytes).replaceAll('=', '');
      for (final token in <String>[
        'not-a-jwt',
        'a.b',
        'a.%%%.c',
        'h.${encoded(utf8.encode('not json'))}.s',
        'h.${encoded(const <int>[0xFF, 0xFE])}.s',
        'h.${encoded(utf8.encode(jsonEncode(<int>[1, 2])))}.s',
        'h.${encoded(utf8.encode(jsonEncode(<String, Object>{'sub': 'x'})))}.s',
      ]) {
        expect(joinWith(token).grants.acceptable, isFalse, reason: token);
      }
      expect(LiveGrants.unreadable.acceptable, isFalse);
    });

    test("the demo's tokens are acceptable in both modes", () {
      for (final mode in LiveMode.values) {
        final token = FakeLiveApi.demoToken(room: 'session-1', mode: mode);
        expect(joinWith(token).grants.acceptable, isTrue, reason: mode.name);
      }
    });

    test('only a listening token is joinable', () {
      final listen = FakeLiveApi.demoToken(room: 'session-1');
      final speak = FakeLiveApi.demoToken(
        room: 'session-1',
        mode: LiveMode.speak,
      );
      expect(joinWith(listen).grants.joinable, isTrue);
      expect(joinWith(speak).grants.joinable, isFalse);
      expect(LiveGrants.unreadable.joinable, isFalse);
    });
  });
}
