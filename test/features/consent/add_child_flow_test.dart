import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/fake/fake_aule_api.dart';
import 'package:aule/core/api/models/models.dart';
import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/features/consent/add_child_flow.dart';
import 'package:aule/features/consent/consent_draft.dart';
import 'package:aule/features/consent/consent_texts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/harness.dart';

/// A fake platform whose answers fail as scripted.
class ScriptedApi extends FakeAuleApi {
  ScriptedApi() : super(latency: Duration.zero);

  /// The failures to throw for each purpose, in order. Once a list is used
  /// up, the answer is recorded.
  final Map<ConsentPurpose, List<ApiErrorKind>> failures =
      <ConsentPurpose, List<ApiErrorKind>>{};
  final List<ConsentAnswer> recorded = <ConsentAnswer>[];
  final Map<ConsentPurpose, int> attempts = <ConsentPurpose, int>{};

  /// Every delete asked for, and the failures to throw first, in order.
  final List<String> deleted = <String>[];
  final List<ApiErrorKind> deleteFailures = <ApiErrorKind>[];

  /// The next create happens on the platform, but its answer is lost.
  ApiErrorKind? createAnswerLost;

  /// The next create fails before anything is created.
  ApiErrorKind? createFails;
  int creates = 0;

  /// How many `me` answers fail with a network error.
  int meFailures = 0;

  @override
  Future<ConsentState> recordConsent(
    String childId,
    ConsentAnswer answer,
  ) async {
    attempts[answer.purpose] = (attempts[answer.purpose] ?? 0) + 1;
    final queue = failures[answer.purpose];
    if (queue != null && queue.isNotEmpty) {
      throw ApiException(queue.removeAt(0));
    }
    recorded.add(answer);
    return super.recordConsent(childId, answer);
  }

  @override
  Future<void> deleteChild(String childId) async {
    deleted.add(childId);
    if (deleteFailures.isNotEmpty) {
      throw ApiException(deleteFailures.removeAt(0));
    }
    await super.deleteChild(childId);
  }

  @override
  Future<Child> createChild({
    required String familyId,
    required ChildDraft draft,
  }) async {
    final fails = createFails;
    if (fails != null) {
      createFails = null;
      throw ApiException(fails);
    }
    creates++;
    final child = await super.createChild(familyId: familyId, draft: draft);
    final lost = createAnswerLost;
    if (lost != null) {
      createAnswerLost = null;
      throw ApiException(lost);
    }
    return child;
  }

  @override
  Future<Me> me() async {
    if (meFailures > 0) {
      meFailures--;
      throw const ApiException(ApiErrorKind.network);
    }
    return super.me();
  }
}

const noWait = <Duration>[Duration.zero, Duration.zero];
const draft = ChildDraft(nickname: 'Pía', grade: 'P2');

Future<(ScriptedApi, AuthController, AddChildFlow)> setUpFlow() async {
  final api = ScriptedApi();
  final auth = await signedInAuth(api);
  final flow = AddChildFlow(api: api, auth: auth, retryDelays: noWait);
  return (api, auth, flow);
}

void main() {
  test('the child exists only after the consent screen', () async {
    final (_, _, flow) = await setUpFlow();
    expect(flow.hasConsent, isFalse);
    await expectLater(flow.create(draft), throwsStateError);
  });

  test(
    'creates the child, then records voice, memory and transcripts',
    () async {
      final (api, auth, flow) = await setUpFlow();
      flow.accept(
        const ConsentDraft(memory: true, transcripts: false, locale: 'es-PE'),
      );
      final result = await flow.create(draft);
      expect(result.allChoicesSaved, isTrue);
      expect((await api.child(result.childId)).child.nickname, 'Pía');

      // Every answer, a "no" included, with the version and the locale.
      expect(
        api.recorded.map((answer) => (answer.purpose, answer.granted)),
        <(ConsentPurpose, bool)>[
          (ConsentPurpose.voice, true),
          (ConsentPurpose.memory, true),
          (ConsentPurpose.transcripts, false),
        ],
      );
      for (final answer in api.recorded) {
        expect(answer.policyVersion, kConsentPolicyVersion);
        expect(answer.policyVersion, 'app-2026-11-v2');
        expect(answer.locale, 'es-PE');
      }

      // The draft is gone and `me` lists the new child.
      expect(flow.hasConsent, isFalse);
      expect(auth.children.map((child) => child.id), contains(result.childId));
      final detail = await api.child(result.childId);
      expect(detail.consent.voice, isTrue);
      expect(detail.consent.memory, isTrue);
      expect(detail.consent.transcripts, isFalse);
    },
  );

  test('if voice cannot be recorded, the new child is deleted', () async {
    final (api, auth, flow) = await setUpFlow();
    api.failures[ConsentPurpose.voice] = <ApiErrorKind>[
      ApiErrorKind.network,
      ApiErrorKind.unavailable,
      ApiErrorKind.internal,
    ];
    flow.accept(
      const ConsentDraft(memory: false, transcripts: false, locale: 'en'),
    );
    final before = auth.children.length;
    await expectLater(
      flow.create(draft),
      throwsA(
        isA<ConsentNotRecorded>().having(
          (failure) => failure.childKept,
          'childKept',
          isFalse,
        ),
      ),
    );
    // Three attempts, then the rollback.
    expect(api.attempts[ConsentPurpose.voice], 3);
    expect(api.deleted, hasLength(1));
    expect((await api.me()).children, hasLength(before));
    // Memory and transcripts were never asked for.
    expect(api.attempts[ConsentPurpose.memory], isNull);
    // The draft is kept so the parent can try again, with no child kept.
    expect(flow.hasConsent, isTrue);
    expect(flow.pendingChild, isNull);
  });

  test('the rollback is retried before it gives up', () async {
    final (api, _, flow) = await setUpFlow();
    api.failures[ConsentPurpose.voice] = <ApiErrorKind>[
      ApiErrorKind.badRequest,
    ];
    api.deleteFailures.addAll(<ApiErrorKind>[
      ApiErrorKind.network,
      ApiErrorKind.unavailable,
    ]);
    flow.accept(
      const ConsentDraft(memory: false, transcripts: false, locale: 'es-PE'),
    );
    await expectLater(flow.create(draft), throwsA(isA<ConsentNotRecorded>()));
    expect(api.deleted, hasLength(3));
    expect(flow.pendingChild, isNull);
  });

  test(
    'a child the rollback cannot delete is kept, and never made twice',
    () async {
      final (api, auth, flow) = await setUpFlow();
      api.failures[ConsentPurpose.voice] = <ApiErrorKind>[
        ApiErrorKind.network,
        ApiErrorKind.network,
        ApiErrorKind.network,
      ];
      api.deleteFailures.addAll(<ApiErrorKind>[
        ApiErrorKind.network,
        ApiErrorKind.network,
        ApiErrorKind.network,
      ]);
      flow.accept(
        const ConsentDraft(memory: true, transcripts: false, locale: 'es-PE'),
      );
      final before = auth.children.length;
      await expectLater(
        flow.create(draft),
        throwsA(
          isA<ConsentNotRecorded>().having(
            (failure) => failure.childKept,
            'childKept',
            isTrue,
          ),
        ),
      );
      // The truth: the profile exists, with no consent, and `me` shows it.
      final kept = flow.pendingChild!;
      expect(kept.nickname, 'Pía');
      expect(auth.children.map((child) => child.id), contains(kept.id));
      expect((await api.child(kept.id)).consent.voice, isFalse);

      // Trying again records the consent for the same child.
      final result = await flow.create(draft);
      expect(result.childId, kept.id);
      expect(api.creates, 1);
      expect(auth.children, hasLength(before + 1));
      expect((await api.child(kept.id)).consent.voice, isTrue);
      expect(flow.pendingChild, isNull);
    },
  );

  test('a kept child can be deleted from the profile screen', () async {
    final (api, auth, flow) = await setUpFlow();
    api.failures[ConsentPurpose.voice] = <ApiErrorKind>[
      ApiErrorKind.badRequest,
    ];
    api.deleteFailures.add(ApiErrorKind.forbidden);
    flow.accept(
      const ConsentDraft(memory: false, transcripts: false, locale: 'es-PE'),
    );
    final before = auth.children.length;
    await expectLater(flow.create(draft), throwsA(isA<ConsentNotRecorded>()));
    expect(flow.pendingChild, isNotNull);
    expect(auth.children, hasLength(before + 1));
    await flow.discardPending();
    expect(flow.pendingChild, isNull);
    expect(auth.children, hasLength(before));
  });

  test('a create whose answer was lost is found, not made twice', () async {
    final (api, auth, flow) = await setUpFlow();
    api.createAnswerLost = ApiErrorKind.network;
    flow.accept(
      const ConsentDraft(memory: false, transcripts: false, locale: 'es-PE'),
    );
    final before = auth.children.length;
    final result = await flow.create(draft);
    expect(api.creates, 1);
    expect(auth.children, hasLength(before + 1));
    expect((await api.child(result.childId)).consent.voice, isTrue);
  });

  test('when `me` cannot tell, the next attempt looks first', () async {
    final (api, auth, flow) = await setUpFlow();
    api.createAnswerLost = ApiErrorKind.network;
    api.meFailures = 1;
    flow.accept(
      const ConsentDraft(memory: false, transcripts: false, locale: 'es-PE'),
    );
    final before = auth.children.length;
    await expectLater(flow.create(draft), throwsA(isA<ApiException>()));
    // The retry finds the child the lost answer made, and uses it.
    final result = await flow.create(draft);
    expect(api.creates, 1);
    expect(auth.children, hasLength(before + 1));
    expect(auth.children.map((child) => child.id), contains(result.childId));
  });

  test('a create that never happened is made on the retry', () async {
    final (api, auth, flow) = await setUpFlow();
    api.createFails = ApiErrorKind.network;
    flow.accept(
      const ConsentDraft(memory: false, transcripts: false, locale: 'es-PE'),
    );
    final before = auth.children.length;
    await expectLater(flow.create(draft), throwsA(isA<ApiException>()));
    await flow.create(draft);
    expect(api.creates, 1);
    expect(auth.children, hasLength(before + 1));
  });

  test('voice is retried on network errors and then succeeds', () async {
    final (api, _, flow) = await setUpFlow();
    api.failures[ConsentPurpose.voice] = <ApiErrorKind>[ApiErrorKind.network];
    flow.accept(
      const ConsentDraft(memory: false, transcripts: false, locale: 'es-PE'),
    );
    final result = await flow.create(draft);
    expect(api.attempts[ConsentPurpose.voice], 2);
    expect(api.deleted, isEmpty);
    expect(result.allChoicesSaved, isTrue);
  });

  test('a refusal is not retried', () async {
    final (api, _, flow) = await setUpFlow();
    api.failures[ConsentPurpose.voice] = <ApiErrorKind>[
      ApiErrorKind.badRequest,
    ];
    flow.accept(
      const ConsentDraft(memory: true, transcripts: true, locale: 'es-PE'),
    );
    await expectLater(flow.create(draft), throwsA(isA<ConsentNotRecorded>()));
    expect(api.attempts[ConsentPurpose.voice], 1);
    expect(api.deleted, hasLength(1));
  });

  test('a lost memory or transcripts answer keeps the child', () async {
    final (api, _, flow) = await setUpFlow();
    api.failures[ConsentPurpose.memory] = <ApiErrorKind>[
      ApiErrorKind.unavailable,
      ApiErrorKind.unavailable,
      ApiErrorKind.unavailable,
    ];
    flow.accept(
      const ConsentDraft(memory: true, transcripts: true, locale: 'es-PE'),
    );
    final result = await flow.create(draft);
    expect(result.allChoicesSaved, isFalse);
    expect(api.deleted, isEmpty);
    // Missing, memory counts as "no" on the server: the safe default.
    final detail = await api.child(result.childId);
    expect(detail.consent.memory, isFalse);
    expect(detail.consent.transcripts, isTrue);
  });

  test('a failed profile keeps the draft and records nothing', () async {
    final (api, _, flow) = await setUpFlow();
    flow.accept(
      const ConsentDraft(memory: true, transcripts: true, locale: 'es-PE'),
    );
    await expectLater(
      flow.create(const ChildDraft(nickname: '')),
      throwsA(isA<ApiException>()),
    );
    expect(api.recorded, isEmpty);
    expect(flow.hasConsent, isTrue);
  });

  test('back clears the draft, and so does signing out', () async {
    final (_, auth, flow) = await setUpFlow();
    flow.accept(
      const ConsentDraft(memory: false, transcripts: false, locale: 'es-PE'),
    );
    flow.cancel();
    expect(flow.consent, isNull);
    flow.accept(
      const ConsentDraft(memory: false, transcripts: false, locale: 'es-PE'),
    );
    await auth.signOut();
    expect(flow.hasConsent, isFalse);
  });
}
