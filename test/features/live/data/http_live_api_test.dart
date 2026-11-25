import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/api_transport.dart';
import 'package:aule/core/api/json.dart';
import 'package:aule/features/live/data/http_live_api.dart';
import 'package:aule/features/live/data/live_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _Call {
  const _Call(this.method, this.path, this.body);

  final String method;
  final String path;
  final Json? body;
}

class _RecordingTransport implements ApiTransport {
  final calls = <_Call>[];
  Json? answer;

  @override
  Future<Json> get(String path, {Map<String, String>? query}) async {
    calls.add(_Call('GET', path, null));
    return answer ?? <String, dynamic>{};
  }

  @override
  Future<Json?> post(String path, [Json? body]) async {
    calls.add(_Call('POST', path, body));
    return answer;
  }

  @override
  Future<Json?> put(String path, [Json? body]) async {
    calls.add(_Call('PUT', path, body));
    return null;
  }

  @override
  Future<Json?> delete(String path, [Json? body]) async {
    calls.add(_Call('DELETE', path, body));
    return null;
  }
}

void main() {
  late _RecordingTransport transport;
  late HttpLiveApi api;

  setUp(() {
    transport = _RecordingTransport();
    api = HttpLiveApi(transport);
  });

  test('join is POST /sessions/{id}/join, always listening', () async {
    transport.answer = <String, dynamic>{
      'serverUrl': 'wss://livekit.example.invalid',
      'room': 'session-s1',
      'token': 'a.b.c',
      'expiresInSeconds': 900,
      'identity': 'guardian-g1',
    };
    final join = await api.join('s1');
    final call = transport.calls.single;
    expect(call.method, 'POST');
    expect(call.path, '/sessions/s1/join');
    expect(call.body, <String, dynamic>{'mode': 'listen'});
    expect(join.room, 'session-s1');
  });

  test('setMode is PUT /sessions/{id}/join, with the id encoded', () async {
    await api.setMode('s/1', LiveMode.speak);
    await api.setMode('s/1', LiveMode.listen);
    expect(transport.calls.map((c) => c.method), <String>['PUT', 'PUT']);
    expect(transport.calls.map((c) => c.path), <String>[
      '/sessions/s%2F1/join',
      '/sessions/s%2F1/join',
    ]);
    expect(transport.calls[0].body, <String, dynamic>{'mode': 'speak'});
    expect(transport.calls[1].body, <String, dynamic>{'mode': 'listen'});
  });

  test('an answer without its fields is invalidResponse', () async {
    transport.answer = <String, dynamic>{'room': 'session-s1'};
    await expectLater(
      api.join('s1'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.invalidResponse,
        ),
      ),
    );
  });
}
