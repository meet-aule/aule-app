import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/http_api_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const base = 'https://example.com/session/api/v1';

/// A transport over [handler], counting 401 callbacks.
class Harness {
  Harness(
    Future<http.Response> Function(http.Request request) handler, {
    String? token = 'a' * 64,
    Duration timeout = const Duration(seconds: 5),
  }) {
    transport = HttpApiTransport(
      baseUrl: base,
      readToken: () async => token,
      onUnauthorized: () => unauthorized++,
      client: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
      timeout: timeout,
    );
  }

  late final HttpApiTransport transport;
  final List<http.Request> requests = <http.Request>[];
  int unauthorized = 0;
}

http.Response jsonResponse(Object body, int status) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

Matcher apiError(ApiErrorKind kind, {int? status}) => isA<ApiException>()
    .having((error) => error.kind, 'kind', kind)
    .having((error) => error.status, 'status', status);

void main() {
  group('requests', () {
    test(
      'GET sends Accept and the bearer token, and no Content-Type',
      () async {
        final harness = Harness((_) async => jsonResponse({'ok': true}, 200));
        final json = await harness.transport.get('/me');
        expect(json, <String, dynamic>{'ok': true});
        final request = harness.requests.single;
        expect(request.method, 'GET');
        expect(request.url.toString(), '$base/me');
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer ${'a' * 64}');
        expect(request.headers.containsKey('Content-Type'), isFalse);
        // Nothing else: no device ids, no tracking headers.
        expect(
          request.headers.keys.map((key) => key.toLowerCase()).toSet(),
          <String>{'accept', 'authorization'},
        );
      },
    );

    test('without a token there is no Authorization header', () async {
      final harness = Harness((_) async => http.Response('', 204), token: null);
      await harness.transport.post('/auth/start', {'email': 'a@example.com'});
      expect(
        harness.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a body goes as JSON with Content-Type application/json', () async {
      final harness = Harness((_) async => http.Response('', 204));
      await harness.transport.put('/me', {'language': 'en'});
      final request = harness.requests.single;
      expect(request.headers['Content-Type'], 'application/json');
      expect(jsonDecode(request.body), <String, dynamic>{'language': 'en'});
    });

    test('DELETE may carry a body', () async {
      final harness = Harness((_) async => http.Response('', 204));
      await harness.transport.delete('/me', {
        'confirm_email': 'ana@example.com',
      });
      final request = harness.requests.single;
      expect(request.method, 'DELETE');
      expect(jsonDecode(request.body), <String, dynamic>{
        'confirm_email': 'ana@example.com',
      });
    });

    test('the query is added to the path', () async {
      final harness = Harness(
        (_) async => jsonResponse({'memories': <Object>[]}, 200),
      );
      await harness.transport.get(
        '/children/c1/memories',
        query: {'limit': '100'},
      );
      expect(
        harness.requests.single.url.toString(),
        '$base/children/c1/memories?limit=100',
      );
    });
  });

  group('answers', () {
    test('a 2xx with no body is null', () async {
      final harness = Harness((_) async => http.Response('', 204));
      expect(await harness.transport.post('/notices/n1/read'), isNull);
    });

    test('GET needs a body', () async {
      final harness = Harness((_) async => http.Response('', 200));
      expect(
        harness.transport.get('/me'),
        throwsA(apiError(ApiErrorKind.invalidResponse)),
      );
    });

    test('a 2xx that is not a JSON object is invalidResponse', () async {
      final notJson = Harness((_) async => http.Response('<html>', 200));
      expect(
        notJson.transport.get('/me'),
        throwsA(apiError(ApiErrorKind.invalidResponse, status: 200)),
      );
      final list = Harness((_) async => jsonResponse(<int>[1, 2], 200));
      expect(
        list.transport.get('/me'),
        throwsA(apiError(ApiErrorKind.invalidResponse, status: 200)),
      );
    });

    test('UTF-8 bodies decode as UTF-8', () async {
      final harness = Harness((_) async => jsonResponse({'name': 'Mamá'}, 200));
      expect((await harness.transport.get('/me'))['name'], 'Mamá');
    });
  });

  group('errors', () {
    final cases = <int, ApiErrorKind>{
      400: ApiErrorKind.badRequest,
      401: ApiErrorKind.unauthorized,
      402: ApiErrorKind.planLimit,
      403: ApiErrorKind.forbidden,
      404: ApiErrorKind.notFound,
      409: ApiErrorKind.conflict,
      500: ApiErrorKind.internal,
      502: ApiErrorKind.internal,
      503: ApiErrorKind.unavailable,
      418: ApiErrorKind.internal,
    };
    for (final MapEntry(key: status, value: kind) in cases.entries) {
      test('$status is $kind', () async {
        final harness = Harness(
          (_) async => jsonResponse({
            'error': {'code': 'some_code', 'message': 'some message'},
          }, status),
        );
        await expectLater(
          harness.transport.get('/children/c1'),
          throwsA(
            apiError(kind, status: status)
                .having((error) => error.code, 'code', 'some_code')
                .having((error) => error.message, 'message', 'some message'),
          ),
        );
        expect(harness.unauthorized, status == 401 ? 1 : 0);
      });
    }

    test('an error without the platform body still maps its status', () async {
      final harness = Harness((_) async => http.Response('Bad gateway', 404));
      await expectLater(
        harness.transport.get('/nowhere'),
        throwsA(
          apiError(
            ApiErrorKind.notFound,
            status: 404,
          ).having((error) => error.code, 'code', isNull),
        ),
      );
    });

    test('a client failure is network', () async {
      final harness = Harness(
        (_) async => throw http.ClientException('connection closed'),
      );
      await expectLater(
        harness.transport.get('/me'),
        throwsA(apiError(ApiErrorKind.network)),
      );
    });

    test('a socket failure is network', () async {
      final harness = Harness(
        (_) async => throw const SocketException('no route to host'),
      );
      await expectLater(
        harness.transport.get('/me'),
        throwsA(apiError(ApiErrorKind.network)),
      );
    });

    test('a TLS failure is network', () async {
      final harness = Harness(
        (_) async => throw const HandshakeException('bad certificate'),
      );
      await expectLater(
        harness.transport.get('/me'),
        throwsA(apiError(ApiErrorKind.network)),
      );
    });

    test('no answer in time is network', () async {
      final harness = Harness((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('', 204);
      }, timeout: const Duration(milliseconds: 20));
      await expectLater(
        harness.transport.get('/me'),
        throwsA(apiError(ApiErrorKind.network)),
      );
    });

    test('the error message never shows in toString', () {
      const error = ApiException(
        ApiErrorKind.conflict,
        status: 409,
        message: 'another adult is already in the session',
      );
      expect(error.toString(), isNot(contains('adult')));
    });
  });

  group('routeTemplate', () {
    test('replaces every id and drops the query', () {
      expect(HttpApiTransport.routeTemplate('/me'), '/me');
      expect(
        HttpApiTransport.routeTemplate(
          '/children/0193a1f0-0000-7000-8000-000000000010/memories/m%2F1',
        ),
        '/children/{id}/memories/{id}',
      );
      expect(
        HttpApiTransport.routeTemplate('/families/f1/children'),
        '/families/{id}/children',
      );
      expect(
        HttpApiTransport.routeTemplate('/devices/claim'),
        '/devices/claim',
      );
      expect(
        HttpApiTransport.routeTemplate('/children/c1/sessions?limit=20'),
        '/children/{id}/sessions',
      );
      expect(HttpApiTransport.routeTemplate('/auth/verify'), '/auth/verify');
    });
  });
}
