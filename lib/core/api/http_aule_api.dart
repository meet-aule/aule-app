import 'api_exception.dart';
import 'api_transport.dart';
import 'aule_api.dart';
import 'json.dart';
import 'models/models.dart';

/// [AuleApi] over the platform's HTTP routes (§6.6). Paths are relative to a
/// base that ends in /v1; every id goes through [Uri.encodeComponent].
class HttpAuleApi implements AuleApi {
  HttpAuleApi(this._transport);

  final ApiTransport _transport;

  static String _id(String id) => Uri.encodeComponent(id);

  /// Parses an answer, turning a malformed one into [ApiErrorKind.invalidResponse].
  static T _parse<T>(Json? json, T Function(Json json) parse) {
    if (json == null) throw const ApiException(ApiErrorKind.invalidResponse);
    try {
      return parse(json);
    } on FormatException {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
  }

  // Sign-in.

  @override
  Future<void> startEmailSignIn({
    required String email,
    required String language,
  }) async {
    await _transport.post('/auth/start', <String, dynamic>{
      'email': email,
      'language': language,
    });
  }

  @override
  Future<TokenGrant> verifyEmailCode({
    required String email,
    required String code,
    String? name,
    required String language,
  }) async {
    final json = await _transport.post('/auth/verify', <String, dynamic>{
      'email': email,
      'code': code,
      'language': language,
      if (name != null) 'name': name,
    });
    return _parse(json, TokenGrant.fromJson);
  }

  @override
  Future<String> googleClientId() async {
    final json = await _transport.get('/auth/google');
    return _parse(json, (json) => jString(json, 'client_id'));
  }

  @override
  Future<TokenGrant> signInWithGoogle({
    required String idToken,
    String? name,
    required String language,
  }) async {
    final json = await _transport.post('/auth/google', <String, dynamic>{
      'credential': idToken,
      'language': language,
      if (name != null) 'name': name,
    });
    return _parse(json, TokenGrant.fromJson);
  }

  // The signed-in guardian.

  @override
  Future<void> signOut() async {
    try {
      await _transport.post('/auth/signout');
    } on ApiException {
      // Signing out always succeeds on the phone; the server's answer does
      // not matter.
    }
  }

  @override
  Future<Me> me() async => _parse(await _transport.get('/me'), Me.fromJson);

  @override
  Future<void> updateSettings({String? language, bool? noticesByEmail}) async {
    await _transport.put('/me', <String, dynamic>{
      if (language != null) 'language': language,
      if (noticesByEmail != null) 'notices_by_email': noticesByEmail,
    });
  }

  @override
  Future<void> deleteAccount({required String confirmEmail}) async {
    await _transport.delete('/me', <String, dynamic>{
      'confirm_email': confirmEmail,
    });
  }

  // Children and consent.

  @override
  Future<Child> createChild({
    required String familyId,
    required ChildDraft draft,
  }) async {
    final json = await _transport.post(
      '/families/${_id(familyId)}/children',
      draft.toJson(),
    );
    return _parse(json, Child.fromJson);
  }

  @override
  Future<ChildDetail> child(String childId) async => _parse(
    await _transport.get('/children/${_id(childId)}'),
    ChildDetail.fromJson,
  );

  @override
  Future<Child> updateChild(String childId, ChildDraft draft) async {
    final json = await _transport.put(
      '/children/${_id(childId)}',
      draft.toJson(),
    );
    return _parse(json, Child.fromJson);
  }

  @override
  Future<void> deleteChild(String childId) async {
    await _transport.delete('/children/${_id(childId)}');
  }

  @override
  Future<ConsentState> recordConsent(
    String childId,
    ConsentAnswer answer,
  ) async {
    final json = await _transport.post(
      '/children/${_id(childId)}/consents',
      answer.toJson(),
    );
    return _parse(
      json,
      (json) => ConsentState.fromJson(jObject(json, 'consent')),
    );
  }

  // Progress.

  @override
  Future<List<Review>> reviews(String childId) async => _parse(
    await _transport.get('/children/${_id(childId)}/reviews'),
    (json) => jList(json, 'reviews', Review.fromJson),
  );

  @override
  Future<SkillReport> skills(String childId) async => _parse(
    await _transport.get('/children/${_id(childId)}/skills'),
    SkillReport.fromJson,
  );

  @override
  Future<List<SkillInfo>> skillCatalog() async => _parse(
    await _transport.get('/skills'),
    (json) => jList(json, 'skills', SkillInfo.fromJson),
  );

  @override
  Future<List<SessionFact>> sessions(String childId, {int limit = 20}) async =>
      _parse(
        await _transport.get(
          '/children/${_id(childId)}/sessions',
          query: <String, String>{'limit': '${limit.clamp(1, 50)}'},
        ),
        (json) => jList(json, 'sessions', SessionFact.fromJson),
      );

  @override
  Future<SessionStatus> session(String sessionId) async => _parse(
    await _transport.get('/sessions/${_id(sessionId)}'),
    SessionStatus.fromJson,
  );

  @override
  Future<void> endSession(String sessionId) async {
    await _transport.post('/sessions/${_id(sessionId)}/end');
  }

  // What Aule remembers.

  @override
  Future<List<Memory>> memories(String childId, {int limit = 100}) async =>
      _parse(
        await _transport.get(
          '/children/${_id(childId)}/memories',
          query: <String, String>{'limit': '${limit.clamp(1, 100)}'},
        ),
        (json) => jList(json, 'memories', Memory.fromJson),
      );

  @override
  Future<void> forgetMemory(String childId, String memoryId) async {
    await _transport.delete(
      '/children/${_id(childId)}/memories/${_id(memoryId)}',
    );
  }

  // Notices.

  @override
  Future<List<Notice>> notices() async => _parse(
    await _transport.get('/notices'),
    (json) => jList(json, 'notices', Notice.fromJson),
  );

  @override
  Future<void> markNoticeRead(String noticeId) async {
    await _transport.post('/notices/${_id(noticeId)}/read');
  }
}
