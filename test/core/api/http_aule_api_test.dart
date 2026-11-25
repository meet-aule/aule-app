import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/api_transport.dart';
import 'package:aule/core/api/http_aule_api.dart';
import 'package:aule/core/api/json.dart';
import 'package:aule/core/api/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// One request as HttpAuleApi made it.
class Call {
  Call(this.method, this.path, this.body, this.query);

  final String method;
  final String path;
  final Json? body;
  final Map<String, String>? query;
}

/// A transport that records requests and answers with [answer].
class RecordingTransport implements ApiTransport {
  final List<Call> calls = <Call>[];
  Json? answer;

  @override
  Future<Json> get(String path, {Map<String, String>? query}) async {
    calls.add(Call('GET', path, null, query));
    return answer ?? <String, dynamic>{};
  }

  @override
  Future<Json?> post(String path, [Json? body]) async {
    calls.add(Call('POST', path, body, null));
    return answer;
  }

  @override
  Future<Json?> put(String path, [Json? body]) async {
    calls.add(Call('PUT', path, body, null));
    return answer;
  }

  @override
  Future<Json?> delete(String path, [Json? body]) async {
    calls.add(Call('DELETE', path, body, null));
    return answer;
  }
}

const grant = <String, dynamic>{
  'token': 't',
  'guardian_id': 'g',
  'family_id': 'f',
  'new_account': false,
  'expires_in_days': 30,
};

void main() {
  late RecordingTransport transport;
  late HttpAuleApi api;

  setUp(() {
    transport = RecordingTransport();
    api = HttpAuleApi(transport);
  });

  test('verify sends a name only when there is one', () async {
    transport.answer = grant;
    await api.verifyEmailCode(
      email: 'ana@example.com',
      code: '123456',
      language: 'es',
    );
    expect(transport.calls.last.path, '/auth/verify');
    expect(transport.calls.last.body, <String, dynamic>{
      'email': 'ana@example.com',
      'code': '123456',
      'language': 'es',
    });
    await api.verifyEmailCode(
      email: 'ana@example.com',
      code: '123456',
      name: 'Ana',
      language: 'es',
    );
    expect(transport.calls.last.body!['name'], 'Ana');
  });

  test('Google sends the ID token as the credential', () async {
    transport.answer = grant;
    await api.signInWithGoogle(idToken: 'id-token', language: 'en');
    expect(transport.calls.last.path, '/auth/google');
    expect(transport.calls.last.body, <String, dynamic>{
      'credential': 'id-token',
      'language': 'en',
    });
  });

  test('settings send only the fields given', () async {
    await api.updateSettings(noticesByEmail: false);
    expect(transport.calls.last.method, 'PUT');
    expect(transport.calls.last.path, '/me');
    expect(transport.calls.last.body, <String, dynamic>{
      'notices_by_email': false,
    });
    await api.updateSettings(language: 'en');
    expect(transport.calls.last.body, <String, dynamic>{'language': 'en'});
  });

  test('deleting the account sends the typed email in a DELETE body', () async {
    await api.deleteAccount(confirmEmail: 'ana@example.com');
    expect(transport.calls.last.method, 'DELETE');
    expect(transport.calls.last.path, '/me');
    expect(transport.calls.last.body, <String, dynamic>{
      'confirm_email': 'ana@example.com',
    });
  });

  test('ids are encoded in paths', () async {
    await api.deleteChild('a/b');
    expect(transport.calls.last.path, '/children/a%2Fb');
    await api.forgetMemory('c1', 'm 1');
    expect(transport.calls.last.path, '/children/c1/memories/m%201');
  });

  test('creating a child posts the whole draft to the family', () async {
    transport.answer = <String, dynamic>{
      'id': 'c9',
      'family_id': 'f1',
      'nickname': 'Lu',
      'created_at': '2026-11-25T10:00:00Z',
    };
    final child = await api.createChild(
      familyId: 'f1',
      draft: const ChildDraft(nickname: 'Lu', grade: 'P1'),
    );
    expect(child.id, 'c9');
    final call = transport.calls.last;
    expect(call.method, 'POST');
    expect(call.path, '/families/f1/children');
    expect(call.body!['grade'], 'P1');
    expect(call.body!.containsKey('birth_year'), isTrue);
    expect(call.body!.containsKey('notes'), isTrue);
  });

  test('recordConsent reads the consent the platform answers', () async {
    transport.answer = <String, dynamic>{
      'consent': <String, dynamic>{
        'voice': true,
        'memory': false,
        'transcripts': false,
      },
    };
    final state = await api.recordConsent(
      'c1',
      const ConsentAnswer(
        purpose: ConsentPurpose.voice,
        granted: true,
        policyVersion: 'app-2026-11-v1',
        locale: 'es-PE',
      ),
    );
    expect(state.voice, isTrue);
    expect(transport.calls.last.path, '/children/c1/consents');
    expect(transport.calls.last.body!['policy_version'], 'app-2026-11-v1');
  });

  test('lists come from their wrapping key', () async {
    transport.answer = <String, dynamic>{
      'reviews': <Object>[
        <String, dynamic>{
          'session_id': 's1',
          'summary': 'Sumas.',
          'flags': <Object>[],
          'created_at': '2026-11-20T10:00:00Z',
        },
      ],
    };
    expect(await api.reviews('c1'), hasLength(1));
    expect(transport.calls.last.path, '/children/c1/reviews');
  });

  test('sessions and memories send their limit', () async {
    transport.answer = <String, dynamic>{'sessions': <Object>[]};
    await api.sessions('c1');
    expect(transport.calls.last.path, '/children/c1/sessions');
    expect(transport.calls.last.query, <String, String>{'limit': '20'});
    transport.answer = <String, dynamic>{'memories': <Object>[]};
    await api.memories('c1');
    expect(transport.calls.last.query, <String, String>{'limit': '100'});
  });

  test('ending a session and reading a notice are plain POSTs', () async {
    await api.endSession('s1');
    expect(transport.calls.last.path, '/sessions/s1/end');
    expect(transport.calls.last.body, isNull);
    await api.markNoticeRead('n1');
    expect(transport.calls.last.path, '/notices/n1/read');
  });

  test('a malformed answer becomes invalidResponse', () async {
    transport.answer = <String, dynamic>{'guardian': 'not an object'};
    await expectLater(
      api.me(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiErrorKind.invalidResponse,
        ),
      ),
    );
    transport.answer = null;
    await expectLater(
      api.verifyEmailCode(email: 'a@example.com', code: '1', language: 'es'),
      throwsA(isA<ApiException>()),
    );
  });
}
