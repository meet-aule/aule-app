import '../api_exception.dart';
import '../aule_api.dart';
import '../json.dart';
import '../models/models.dart';
import 'demo_data.dart';

/// [AuleApi] in memory, for demo mode and tests. It is seeded with the
/// invented family of Appendix B and mirrors the platform's rules, so every
/// screen can be reached without a server. No byte leaves the phone.
///
/// The fake cannot see the token, so it answers as the family that signed in
/// last. A fresh fake answers as the seeded family, which is what a demo
/// token restored from a previous launch stands for.
class FakeAuleApi implements AuleApi {
  FakeAuleApi({
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? clock,
    bool signedIn = true,
  }) : _clock = clock ?? DateTime.now {
    _reset(signedIn: signedIn);
  }

  /// How long each answer takes.
  final Duration latency;
  final DateTime Function() _clock;

  static const token = 'demo-token';
  static const unavailableEmail = 'error@example.com';

  /// The live session's time budget, counted down in real time. The demo
  /// renews it when it runs out, so there is always a session to listen to
  /// until a parent ends it.
  static const liveBudget = Duration(seconds: 840);

  final Map<String, _Family> _families = <String, _Family>{};
  final Set<String> _codesSent = <String>{};
  _Family? _current;
  int _nextId = 0x1000;

  // Sign-in.

  @override
  Future<void> startEmailSignIn({
    required String email,
    required String language,
  }) async {
    await _wait();
    final address = _normalizedEmail(email);
    if (address == unavailableEmail) {
      throw const ApiException(
        ApiErrorKind.unavailable,
        status: 503,
        code: 'unavailable',
        message: 'the code could not be sent; try again later',
      );
    }
    _codesSent.add(address);
  }

  @override
  Future<TokenGrant> verifyEmailCode({
    required String email,
    required String code,
    String? name,
    required String language,
  }) async {
    await _wait();
    final address = _normalizedEmail(email);
    if (!_codesSent.contains(address) || code.trim() != DemoData.signInCode) {
      throw const ApiException(
        ApiErrorKind.forbidden,
        status: 403,
        code: 'forbidden',
        message: 'that code is wrong or has expired',
      );
    }
    var family = _families[address];
    var newAccount = false;
    if (family == null) {
      final given = name?.trim() ?? '';
      if (given.isEmpty || given.runes.length > 120) {
        // The code stays valid, as on the server.
        throw _badRequest('name is needed to create the account');
      }
      family = _newFamily(address, given, language);
      _families[address] = family;
      newAccount = true;
    }
    _codesSent.remove(address);
    _current = family;
    return TokenGrant(
      token: token,
      guardianId: family.guardian.id,
      familyId: family.id,
      newAccount: newAccount,
      expiresInDays: 30,
    );
  }

  @override
  Future<String> googleClientId() async {
    await _wait();
    throw _googleOff;
  }

  @override
  Future<TokenGrant> signInWithGoogle({
    required String idToken,
    String? name,
    required String language,
  }) async {
    await _wait();
    throw _googleOff;
  }

  static const _googleOff = ApiException(
    ApiErrorKind.unavailable,
    status: 503,
    code: 'unavailable',
    message: 'sign-in with Google is not set up here',
  );

  // The signed-in guardian.

  @override
  Future<void> signOut() async {
    await _wait();
    _current = null;
  }

  @override
  Future<Me> me() async {
    await _wait();
    final family = _family;
    return Me(
      guardian: family.guardian,
      familyId: family.id,
      children: <ChildRef>[
        for (final kid in family.kids)
          ChildRef(id: kid.child.id, nickname: kid.child.nickname),
      ],
      unreadNotices: family.notices.where((n) => n.readAt == null).length,
      subjects: ChildCodes.subjects,
    );
  }

  @override
  Future<void> updateSettings({String? language, bool? noticesByEmail}) async {
    await _wait();
    final family = _family;
    if (language != null && !ChildCodes.languages.contains(language)) {
      throw _badRequest('language must be es or en');
    }
    family.guardian = family.guardian.copyWith(
      language: language,
      noticesByEmail: noticesByEmail,
    );
  }

  @override
  Future<void> deleteAccount({required String confirmEmail}) async {
    await _wait();
    final family = _family;
    final given = _normalizedEmail(confirmEmail);
    if (given != family.guardian.email) {
      throw _badRequest('confirm_email must be the address you signed in with');
    }
    _reset(signedIn: false);
  }

  // Children and consent.

  @override
  Future<Child> createChild({
    required String familyId,
    required ChildDraft draft,
  }) async {
    await _wait();
    final family = _family;
    if (familyId != family.id) throw _notFound('family');
    final json = _checked(draft);
    final child = _childFrom(
      json,
      id: _newId(),
      familyId: family.id,
      createdAt: _now,
    );
    family.kids.add(_Kid(child: child, relationship: _relationOf(json)));
    return child;
  }

  @override
  Future<ChildDetail> child(String childId) async {
    await _wait();
    final kid = _kid(childId);
    return ChildDetail(
      child: kid.child,
      consent: kid.consent,
      relationship: kid.relationship,
    );
  }

  @override
  Future<Child> updateChild(String childId, ChildDraft draft) async {
    await _wait();
    final kid = _kid(childId);
    final json = _checked(draft);
    kid.child = _childFrom(
      json,
      id: kid.child.id,
      familyId: kid.child.familyId,
      createdAt: kid.child.createdAt,
    );
    kid.relationship = _relationOf(json);
    return kid.child;
  }

  @override
  Future<void> deleteChild(String childId) async {
    await _wait();
    final family = _family;
    final kid = _kid(childId);
    family.kids.remove(kid);
    family.notices.removeWhere((notice) => notice.childId == childId);
  }

  @override
  Future<ConsentState> recordConsent(
    String childId,
    ConsentAnswer answer,
  ) async {
    await _wait();
    final kid = _kid(childId);
    final version = answer.policyVersion.trim();
    if (version.isEmpty || version.length > 40) {
      throw _badRequest('policy_version must have 1 to 40 characters');
    }
    kid.answers.add(answer);
    if (!answer.granted) {
      switch (answer.purpose) {
        case ConsentPurpose.memory:
          kid.memories.clear();
        case ConsentPurpose.voice:
          for (final session in kid.sessions) {
            if (session.isLive) session.end('parent_ended', _now);
          }
        case ConsentPurpose.transcripts:
          break;
      }
    }
    return kid.consent;
  }

  // Progress.

  @override
  Future<List<Review>> reviews(String childId) async {
    await _wait();
    return _kid(childId).reviews.take(20).toList(growable: false);
  }

  @override
  Future<SkillReport> skills(String childId) async {
    await _wait();
    return _kid(childId).skills;
  }

  @override
  Future<List<SkillInfo>> skillCatalog() async {
    await _wait();
    return _catalog;
  }

  @override
  Future<List<SessionFact>> sessions(String childId, {int limit = 20}) async {
    await _wait();
    final kid = _kid(childId);
    if (limit < 1 || limit > 50) throw _badRequest('limit must be 1 to 50');
    for (final session in kid.sessions) {
      _expire(session);
    }
    return <SessionFact>[
      for (final session in kid.sessions.take(limit)) session.toFact(),
    ];
  }

  @override
  Future<SessionStatus> session(String sessionId) async {
    await _wait();
    final session = _session(sessionId);
    _expire(session);
    return SessionStatus(
      status: session.status,
      endReason: session.endReason,
      remainingSeconds: session.remaining(_now),
      canResume: false,
      language: 'es',
      engine: true,
    );
  }

  @override
  Future<void> endSession(String sessionId) async {
    await _wait();
    final session = _session(sessionId);
    if (session.isLive) session.end('parent_ended', _now);
  }

  // What Aule remembers.

  @override
  Future<List<Memory>> memories(String childId, {int limit = 100}) async {
    await _wait();
    final kid = _kid(childId);
    if (limit < 1 || limit > 100) throw _badRequest('limit must be 1 to 100');
    return kid.memories.take(limit).toList(growable: false);
  }

  @override
  Future<void> forgetMemory(String childId, String memoryId) async {
    await _wait();
    final kid = _kid(childId);
    final before = kid.memories.length;
    kid.memories.removeWhere((memory) => memory.id == memoryId);
    if (kid.memories.length == before) throw _notFound('memory');
  }

  // Notices.

  @override
  Future<List<Notice>> notices() async {
    await _wait();
    final family = _family;
    final sorted = family.notices.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return <Notice>[
      for (final notice in sorted.take(50))
        notice.toNotice(family.guardian.language),
    ];
  }

  @override
  Future<void> markNoticeRead(String noticeId) async {
    await _wait();
    for (final notice in _family.notices) {
      if (notice.id == noticeId) {
        notice.readAt ??= _now;
        return;
      }
    }
    throw _notFound('notice');
  }

  // The rules the platform applies.

  Future<void> _wait() => latency == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(latency);

  DateTime get _now => _clock().toUtc();

  _Family get _family {
    final family = _current;
    if (family == null) {
      throw const ApiException(
        ApiErrorKind.unauthorized,
        status: 401,
        code: 'unauthorized',
      );
    }
    return family;
  }

  _Kid _kid(String childId) {
    for (final kid in _family.kids) {
      if (kid.child.id == childId) return kid;
    }
    throw _notFound('child');
  }

  _FakeSession _session(String sessionId) {
    for (final kid in _family.kids) {
      for (final session in kid.sessions) {
        if (session.id == sessionId) return session;
      }
    }
    throw _notFound('session');
  }

  void _expire(_FakeSession session) {
    if (!session.isLive || session.remaining(_now) > 0) return;
    if (session.id == DemoData.liveSessionId) {
      // The demo's own live session starts a new budget instead.
      session.deadline = _now.add(liveBudget);
      return;
    }
    session.end('budget_reached', _now);
  }

  static ApiException _badRequest(String message) => ApiException(
    ApiErrorKind.badRequest,
    status: 400,
    code: 'bad_request',
    message: message,
  );

  static ApiException _notFound(String what) => ApiException(
    ApiErrorKind.notFound,
    status: 404,
    code: 'not_found',
    message: '$what not found',
  );

  /// The server's check: one @, a dot inside the domain, no spaces, at most
  /// 254 characters. Answers the trimmed, lower-case address.
  static String _normalizedEmail(String email) {
    final address = email.trim().toLowerCase();
    final parts = address.split('@');
    final valid =
        parts.length == 2 &&
        parts[0].isNotEmpty &&
        parts[1].contains('.') &&
        !parts[1].startsWith('.') &&
        !parts[1].endsWith('.') &&
        address.length <= 254 &&
        !address.contains(RegExp(r'\s'));
    if (!valid) throw _badRequest('email is not an email address');
    return address;
  }

  /// Validates as the server does and answers the body it would receive.
  Json _checked(ChildDraft draft) {
    final problem = draft.validate();
    if (problem != null) throw _badRequest('child: ${problem.name}');
    final year = draft.birthYear;
    final now = _now.year;
    if (year != null && (year < now - 19 || year > now - 3)) {
      throw _badRequest("birth_year is not a school student's");
    }
    return draft.toJson();
  }

  static Child _childFrom(
    Json json, {
    required String id,
    required String familyId,
    required DateTime createdAt,
  }) {
    String? blankToNull(Object? value) {
      final text = value is String ? value.trim() : '';
      return text.isEmpty ? null : text;
    }

    final subjects = <String>[];
    for (final subject in jStrings(json, 'subjects')) {
      if (!subjects.contains(subject)) subjects.add(subject);
    }
    return Child(
      id: id,
      familyId: familyId,
      nickname: jString(json, 'nickname'),
      birthYear: jIntOrNull(json, 'birth_year'),
      grade: blankToNull(json['grade'])?.toUpperCase(),
      language: jStringOrNull(json, 'language') ?? 'es',
      interests: <String>[
        for (final interest in jStrings(json, 'interests')) interest.trim(),
      ],
      subjects: subjects,
      notes: blankToNull(json['notes']),
      tutorName: 'Aule',
      tutorPersona:
          jStringOrNull(json, 'tutor_persona') ?? ChildCodes.defaultPersona,
      tutorPersonaNote: blankToNull(json['tutor_persona_note']),
      createdAt: createdAt,
    );
  }

  static String? _relationOf(Json json) {
    final code = jStringOrNull(json, 'relationship') ?? '';
    return code.trim().isEmpty ? null : code;
  }

  String _newId() =>
      '0193a1f0-0000-7000-8000-${(_nextId++).toRadixString(16).padLeft(12, '0')}';

  _Family _newFamily(String email, String name, String language) {
    return _Family(
      id: _newId(),
      guardian: Guardian(
        id: _newId(),
        email: email,
        name: name,
        language: ChildCodes.languages.contains(language) ? language : 'es',
        noticesByEmail: true,
        noticesByPush: true,
      ),
    );
  }

  // The seed (Appendix B).

  void _reset({required bool signedIn}) {
    _families.clear();
    _codesSent.clear();
    final family = _seed(_now);
    _families[DemoData.guardianEmail] = family;
    _current = signedIn ? family : null;
  }

  static String _demoId(int n) =>
      '0193a1f0-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';

  static const _policy = 'app-2026-11-v2';

  static List<ConsentAnswer> _answers({
    required bool voice,
    required bool memory,
    required bool transcripts,
  }) => <ConsentAnswer>[
    ConsentAnswer(
      purpose: ConsentPurpose.voice,
      granted: voice,
      policyVersion: _policy,
      locale: 'es-PE',
    ),
    ConsentAnswer(
      purpose: ConsentPurpose.memory,
      granted: memory,
      policyVersion: _policy,
      locale: 'es-PE',
    ),
    ConsentAnswer(
      purpose: ConsentPurpose.transcripts,
      granted: transcripts,
      policyVersion: _policy,
      locale: 'es-PE',
    ),
  ];

  static SkillTrace _trace(
    String id, {
    required int attempts,
    required double pNow,
    required bool mastered,
  }) => SkillTrace(
    skillId: id,
    attempts: attempts,
    pKnown: pNow,
    pNow: pNow,
    p7d: pNow - 0.05,
    halfLifeDays: mastered ? 12 : 4,
    mastered: mastered,
    targetDifficulty: 0.5,
    corrected: false,
  );

  static const List<SkillInfo> _catalog = <SkillInfo>[
    SkillInfo(
      id: 'conteo-20',
      subject: 'matematica',
      name: 'Contar hasta 20',
      grade: 'P1',
      prerequisites: <String>[],
    ),
    SkillInfo(
      id: 'suma-objetos',
      subject: 'matematica',
      name: 'Sumas con objetos',
      grade: 'P1',
      prerequisites: <String>['conteo-20'],
    ),
    SkillInfo(
      id: 'conteo-100',
      subject: 'matematica',
      name: 'Contar hasta 100',
      grade: 'P2',
      prerequisites: <String>['conteo-20'],
    ),
    SkillInfo(
      id: 'suma-sin-llevar',
      subject: 'matematica',
      name: 'Sumas sin llevar',
      grade: 'P2',
      prerequisites: <String>['conteo-100'],
    ),
    SkillInfo(
      id: 'suma-con-llevar',
      subject: 'matematica',
      name: 'Sumas con llevadas',
      grade: 'P3',
      prerequisites: <String>['suma-sin-llevar'],
    ),
    SkillInfo(
      id: 'suma-tres-cifras',
      subject: 'matematica',
      name: 'Sumas de tres cifras',
      grade: 'P3',
      prerequisites: <String>['suma-con-llevar'],
    ),
    SkillInfo(
      id: 'tabla-2',
      subject: 'matematica',
      name: 'Tabla del 2',
      grade: 'P3',
      prerequisites: <String>['suma-sin-llevar'],
    ),
    SkillInfo(
      id: 'tabla-3',
      subject: 'matematica',
      name: 'Tabla del 3',
      grade: 'P3',
      prerequisites: <String>['tabla-2'],
    ),
    SkillInfo(
      id: 'tabla-4',
      subject: 'matematica',
      name: 'Tabla del 4',
      grade: 'P3',
      prerequisites: <String>['tabla-2'],
    ),
  ];

  static const _summaryMati1 =
      'Mati practicó sumas con llevadas con ejemplos de fútbol. Resolvió 7 de '
      '9 ejercicios y pidió una pista en dos. Al final tenía ganas de seguir.';

  /// The same summary for an English-speaking guardian's notice.
  static const _summaryMati1En =
      'Mati practiced addition with carrying, using soccer examples, solved 7 '
      'of 9 exercises and asked for a hint on two. By the end, Mati wanted to '
      'keep going.';

  _Family _seed(DateTime now) {
    final family = _Family(
      id: DemoData.familyId,
      guardian: const Guardian(
        id: DemoData.guardianId,
        email: DemoData.guardianEmail,
        name: DemoData.guardianName,
        language: 'es',
        noticesByEmail: true,
        noticesByPush: true,
      ),
    );

    // Mati.
    final mati = _Kid(
      child: Child(
        id: DemoData.childMati,
        familyId: DemoData.familyId,
        nickname: 'Mati',
        birthYear: now.year - 8,
        grade: 'P3',
        language: 'es',
        interests: const <String>['fútbol', 'dinosaurios'],
        subjects: const <String>['matematica'],
        tutorName: 'Aule',
        tutorPersona: 'calido',
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      relationship: 'MTH',
    )..answers.addAll(_answers(voice: true, memory: true, transcripts: false));

    final live = _FakeSession(
      id: DemoData.liveSessionId,
      createdAt: now.subtract(const Duration(minutes: 6, seconds: 20)),
      startedAt: now.subtract(const Duration(minutes: 6)),
      onDevice: false,
      objective: const Objective(
        kind: 'homework',
        subject: 'matematica',
        topic: 'fracciones',
      ),
      reviewed: false,
      deadline: now.add(liveBudget),
    );
    final mati1 = _FakeSession.ended(
      id: _demoId(0x101),
      endedAt: now.subtract(const Duration(days: 2)),
      minutes: 18,
      endReason: 'budget_reached',
      objective: const Objective(kind: 'homework', subject: 'matematica'),
    );
    final mati2 = _FakeSession.ended(
      id: _demoId(0x102),
      endedAt: now.subtract(const Duration(days: 4)),
      minutes: 20,
      endReason: 'child_ended',
      objective: const Objective(kind: 'exam_prep', subject: 'matematica'),
    );
    final mati3 = _FakeSession.ended(
      id: _demoId(0x103),
      endedAt: now.subtract(const Duration(days: 6)),
      minutes: 9,
      endReason: 'idle',
      objective: const Objective(kind: 'explore', subject: 'comunicacion'),
    );
    mati.sessions.addAll(<_FakeSession>[live, mati1, mati2, mati3]);
    mati.reviews.addAll(<Review>[
      Review(
        sessionId: mati1.id,
        summary: _summaryMati1,
        nextStep: 'Seguir con sumas de tres cifras.',
        flags: const <String>[],
        createdAt: mati1.endedAt!.add(const Duration(minutes: 1)),
      ),
      Review(
        sessionId: mati2.id,
        summary:
            'Mati repasó las tablas del 3 y del 4. La del 4 le costó, pero '
            'corrigió sus errores con calma.',
        nextStep: 'Repasar la tabla del 4 con juegos cortos.',
        flags: const <String>['struggling'],
        createdAt: mati2.endedAt!.add(const Duration(minutes: 1)),
      ),
      Review(
        sessionId: mati3.id,
        summary:
            'Sesión corta: Mati leyó un cuento sobre dinosaurios y contó con '
            'sus palabras lo que pasó.',
        flags: const <String>[],
        createdAt: mati3.endedAt!.add(const Duration(minutes: 1)),
      ),
    ]);
    mati.skills = SkillReport(
      ability: 0.42,
      skills: <SkillTrace>[
        _trace('suma-sin-llevar', attempts: 14, pNow: 0.93, mastered: true),
        _trace('conteo-100', attempts: 9, pNow: 0.95, mastered: true),
        _trace('tabla-2', attempts: 11, pNow: 0.9, mastered: true),
        _trace('suma-con-llevar', attempts: 9, pNow: 0.62, mastered: false),
        _trace('tabla-4', attempts: 7, pNow: 0.48, mastered: false),
      ],
      next: const <NextSkill>[
        NextSkill(
          skillId: 'tabla-4',
          name: 'Tabla del 4',
          reason: 'in_progress',
        ),
        NextSkill(
          skillId: 'suma-tres-cifras',
          name: 'Sumas de tres cifras',
          reason: 'ready',
        ),
        NextSkill(
          skillId: 'tabla-3',
          name: 'Tabla del 3',
          reason: 'review_due',
        ),
      ],
    );
    mati.memories.addAll(<Memory>[
      Memory(
        id: _demoId(0x401),
        kind: 'success',
        content: 'Ya suma sin llevar con seguridad.',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Memory(
        id: _demoId(0x402),
        kind: 'struggle',
        content: 'Se confunde con la tabla del 4.',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      Memory(
        id: _demoId(0x403),
        kind: 'preference',
        content: 'Le gustan los dinosaurios, sobre todo el triceratops.',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      Memory(
        id: _demoId(0x404),
        kind: 'preference',
        content: 'Le encanta el fútbol.',
        createdAt: now.subtract(const Duration(days: 9)),
      ),
    ]);

    // Lu.
    final lu = _Kid(
      child: Child(
        id: DemoData.childLu,
        familyId: DemoData.familyId,
        nickname: 'Lu',
        birthYear: now.year - 6,
        grade: 'P1',
        language: 'es',
        interests: const <String>['animales', 'cuentos'],
        subjects: const <String>[],
        tutorName: 'Aule',
        tutorPersona: 'jugueton',
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    )..answers.addAll(_answers(voice: true, memory: false, transcripts: false));
    final lu1 = _FakeSession.ended(
      id: _demoId(0x111),
      endedAt: now.subtract(const Duration(days: 2, hours: 5)),
      minutes: 12,
      endReason: 'not_working',
      reviewed: false,
    );
    final lu2 = _FakeSession.ended(
      id: _demoId(0x112),
      endedAt: now.subtract(const Duration(days: 3)),
      minutes: 15,
      endReason: 'budget_reached',
      objective: const Objective(kind: 'explore', subject: 'matematica'),
    );
    lu.sessions.addAll(<_FakeSession>[lu1, lu2]);
    lu.reviews.add(
      Review(
        sessionId: lu2.id,
        summary:
            'Lu contó objetos hasta 20 y comparó cantidades. Respondió con '
            'seguridad y quiso seguir jugando.',
        nextStep: 'Empezar a sumar con objetos.',
        flags: const <String>[],
        createdAt: lu2.endedAt!.add(const Duration(minutes: 1)),
      ),
    );
    lu.skills = SkillReport(
      ability: 0.2,
      skills: <SkillTrace>[
        _trace('conteo-20', attempts: 8, pNow: 0.91, mastered: true),
      ],
      next: const <NextSkill>[
        NextSkill(
          skillId: 'suma-objetos',
          name: 'Sumas con objetos',
          reason: 'ready',
        ),
      ],
    );

    family.kids.addAll(<_Kid>[mati, lu]);

    // Notices, in the server's own words (notices.rs).
    family.notices.addAll(<_FakeNotice>[
      _FakeNotice(
        id: _demoId(0x301),
        childId: DemoData.childMati,
        kind: 'attention',
        title: const <String, String>{
          'es': 'Mati puede necesitarte',
          'en': 'Mati may need you',
        },
        body: const <String, String>{
          'es':
              'Durante una sesión, Mati dijo algo que hizo que el tutor le '
              'sugiriera conversar con un adulto de confianza. El tutor no '
              'siguió con ese tema. Puede no ser nada, pero conviene conversar '
              'con Mati hoy, con calma.',
          'en':
              'During a session, Mati said something that made the tutor '
              'suggest talking with a trusted adult. The tutor did not '
              'continue that topic. It may be nothing, but a calm conversation '
              'with Mati today is a good idea.',
        },
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      _FakeNotice(
        id: _demoId(0x302),
        childId: DemoData.childMati,
        sessionId: mati1.id,
        kind: 'session_summary',
        title: const <String, String>{
          'es': 'La sesión de Mati',
          'en': "Mati's session",
        },
        body: const <String, String>{
          'es': _summaryMati1,
          'en': _summaryMati1En,
        },
        createdAt: mati1.endedAt!.add(const Duration(minutes: 2)),
        readAt: mati1.endedAt!.add(const Duration(hours: 1)),
      ),
      _FakeNotice(
        id: _demoId(0x303),
        childId: DemoData.childLu,
        sessionId: lu1.id,
        kind: 'session_stopped',
        title: const <String, String>{
          'es': 'La sesión de Lu terminó antes de tiempo',
          'en': "Lu's session ended early",
        },
        body: const <String, String>{
          'es':
              'Aule cerró la sesión de hoy antes de tiempo: Lu no estaba '
              'trabajando en la actividad y siguió así después de un aviso. '
              'No pasó nada malo. Pueden empezar otra sesión cuando Lu tenga '
              'ganas de trabajar.',
          'en':
              "Aule closed today's session before its time: Lu was not "
              'working on the activity, and kept going after a reminder. '
              'Nothing is wrong. Another session can start whenever Lu is '
              'ready to work.',
        },
        createdAt: lu1.endedAt!.add(const Duration(minutes: 1)),
        readAt: lu1.endedAt!.add(const Duration(hours: 2)),
      ),
    ]);
    return family;
  }
}

class _Family {
  _Family({required this.id, required this.guardian});

  final String id;
  Guardian guardian;
  final List<_Kid> kids = <_Kid>[];
  final List<_FakeNotice> notices = <_FakeNotice>[];
}

class _Kid {
  _Kid({required this.child, this.relationship});

  Child child;
  String? relationship;

  /// Every answer, oldest first. The current consent is the latest per purpose.
  final List<ConsentAnswer> answers = <ConsentAnswer>[];

  /// Newest first.
  final List<Review> reviews = <Review>[];
  SkillReport skills = const SkillReport(
    ability: 0,
    skills: <SkillTrace>[],
    next: <NextSkill>[],
  );

  /// Newest first.
  final List<_FakeSession> sessions = <_FakeSession>[];

  /// Newest first.
  final List<Memory> memories = <Memory>[];

  ConsentState get consent {
    bool latest(ConsentPurpose purpose) {
      for (final answer in answers.reversed) {
        if (answer.purpose == purpose) return answer.granted;
      }
      return false;
    }

    return ConsentState(
      voice: latest(ConsentPurpose.voice),
      transcripts: latest(ConsentPurpose.transcripts),
      memory: latest(ConsentPurpose.memory),
    );
  }
}

class _FakeSession {
  _FakeSession({
    required this.id,
    required this.createdAt,
    this.startedAt,
    required this.onDevice,
    this.objective,
    required this.reviewed,
    this.deadline,
  });

  factory _FakeSession.ended({
    required String id,
    required DateTime endedAt,
    required int minutes,
    required String endReason,
    Objective? objective,
    bool reviewed = true,
  }) {
    final startedAt = endedAt.subtract(Duration(minutes: minutes));
    return _FakeSession(
        id: id,
        createdAt: startedAt.subtract(const Duration(seconds: 20)),
        startedAt: startedAt,
        onDevice: false,
        objective: objective,
        reviewed: reviewed,
      )
      ..endedAt = endedAt
      ..endReason = endReason;
  }

  final String id;
  final DateTime createdAt;
  final DateTime? startedAt;
  final bool onDevice;
  final Objective? objective;
  final bool reviewed;

  /// When a live session runs out of time.
  DateTime? deadline;
  DateTime? endedAt;
  String? endReason;

  bool get isLive => endedAt == null;
  String get status => isLive ? 'active' : 'ended';

  int remaining(DateTime now) {
    final end = deadline;
    if (!isLive || end == null) return 0;
    final seconds = end.difference(now).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  void end(String reason, DateTime at) {
    endedAt = at;
    endReason = reason;
  }

  SessionFact toFact() => SessionFact(
    id: id,
    status: status,
    createdAt: createdAt,
    startedAt: startedAt,
    endedAt: endedAt,
    endReason: endReason,
    engine: true,
    language: 'es',
    objective: objective,
    onDevice: onDevice,
    reviewed: reviewed,
  );
}

class _FakeNotice {
  _FakeNotice({
    required this.id,
    this.childId,
    this.sessionId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String? childId;
  final String? sessionId;
  final String kind;

  /// The server writes each notice in the guardian's language; the fake keeps
  /// both and answers in the language set now.
  final Map<String, String> title;
  final Map<String, String> body;
  final DateTime createdAt;
  DateTime? readAt;

  Notice toNotice(String language) => Notice(
    id: id,
    childId: childId,
    sessionId: sessionId,
    kind: kind,
    title: title[language] ?? title['es']!,
    body: body[language] ?? body['es']!,
    createdAt: createdAt,
    readAt: readAt,
  );
}
