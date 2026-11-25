import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/api/fake/demo_data.dart';
import 'package:aule/core/api/fake/fake_aule_api.dart';
import 'package:aule/core/api/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

Matcher throwsKind(ApiErrorKind kind) =>
    throwsA(isA<ApiException>().having((error) => error.kind, 'kind', kind));

ConsentAnswer answer(ConsentPurpose purpose, bool granted) => ConsentAnswer(
  purpose: purpose,
  granted: granted,
  policyVersion: 'app-2026-11-v1',
  locale: 'es-PE',
);

void main() {
  group('sign-in', () {
    test('the existing account signs in with 123456', () async {
      final api = instantApi(signedIn: false);
      await api.startEmailSignIn(email: ' Ana@Example.com ', language: 'es');
      final grant = await api.verifyEmailCode(
        email: 'ana@example.com',
        code: DemoData.signInCode,
        language: 'es',
      );
      expect(grant.token, FakeAuleApi.token);
      expect(grant.newAccount, isFalse);
      expect(grant.familyId, DemoData.familyId);
      final me = await api.me();
      expect(me.guardian.name, DemoData.guardianName);
      expect(me.children.map((child) => child.nickname), <String>[
        'Mati',
        'Lu',
      ]);
    });

    test('a wrong code, or no code sent, is forbidden', () async {
      final api = instantApi(signedIn: false);
      await expectLater(
        api.verifyEmailCode(
          email: 'ana@example.com',
          code: DemoData.signInCode,
          language: 'es',
        ),
        throwsKind(ApiErrorKind.forbidden),
      );
      await api.startEmailSignIn(email: 'ana@example.com', language: 'es');
      await expectLater(
        api.verifyEmailCode(
          email: 'ana@example.com',
          code: '000000',
          language: 'es',
        ),
        throwsKind(ApiErrorKind.forbidden),
      );
    });

    test('a new address needs a name, and the code survives that', () async {
      final api = instantApi(signedIn: false);
      await api.startEmailSignIn(email: 'rosa@example.com', language: 'en');
      await expectLater(
        api.verifyEmailCode(
          email: 'rosa@example.com',
          code: DemoData.signInCode,
          language: 'en',
        ),
        throwsKind(ApiErrorKind.badRequest),
      );
      final grant = await api.verifyEmailCode(
        email: 'rosa@example.com',
        code: DemoData.signInCode,
        name: 'Rosa',
        language: 'en',
      );
      expect(grant.newAccount, isTrue);
      final me = await api.me();
      expect(me.guardian.name, 'Rosa');
      expect(me.guardian.language, 'en');
      expect(me.children, isEmpty);
      expect(me.unreadNotices, 0);
    });

    test('error@example.com shows the unavailable state', () async {
      final api = instantApi(signedIn: false);
      await expectLater(
        api.startEmailSignIn(email: 'error@example.com', language: 'es'),
        throwsKind(ApiErrorKind.unavailable),
      );
    });

    test('an address the server would refuse is badRequest', () async {
      final api = instantApi(signedIn: false);
      for (final email in <String>[
        'ana',
        'ana@example',
        'a b@example.com',
        '@example.com',
        'ana@@example.com',
        'ana@.example.com',
        'ana@example.com.',
      ]) {
        await expectLater(
          api.startEmailSignIn(email: email, language: 'es'),
          throwsKind(ApiErrorKind.badRequest),
          reason: email,
        );
      }
    });

    test('signed out, the guardian routes answer 401', () async {
      final api = instantApi();
      await api.signOut();
      await expectLater(api.me(), throwsKind(ApiErrorKind.unauthorized));
    });
  });

  group('children and consent', () {
    test('createChild validates as the server does', () async {
      final api = instantApi();
      await expectLater(
        api.createChild(
          familyId: DemoData.familyId,
          draft: const ChildDraft(nickname: ' '),
        ),
        throwsKind(ApiErrorKind.badRequest),
      );
      await expectLater(
        api.createChild(
          familyId: 'another-family',
          draft: const ChildDraft(nickname: 'Pía'),
        ),
        throwsKind(ApiErrorKind.notFound),
      );
      final child = await api.createChild(
        familyId: DemoData.familyId,
        draft: const ChildDraft(nickname: ' Pía ', relationship: 'GRMTH'),
      );
      expect(child.nickname, 'Pía');
      final detail = await api.child(child.id);
      expect(detail.relationship, 'GRMTH');
      // No consent yet: nothing is granted.
      expect(detail.consent.voice, isFalse);
    });

    test('the current consent is the latest answer per purpose', () async {
      final api = instantApi();
      final mati = await api.child(DemoData.childMati);
      expect(mati.consent.voice, isTrue);
      expect(mati.consent.memory, isTrue);
      expect(mati.consent.transcripts, isFalse);
      final state = await api.recordConsent(
        DemoData.childMati,
        answer(ConsentPurpose.transcripts, true),
      );
      expect(state.transcripts, isTrue);
      expect(state.voice, isTrue);
    });

    test('withdrawing memory empties what Aule remembers', () async {
      final api = instantApi();
      expect(await api.memories(DemoData.childMati), hasLength(4));
      await api.recordConsent(
        DemoData.childMati,
        answer(ConsentPurpose.memory, false),
      );
      expect(await api.memories(DemoData.childMati), isEmpty);
    });

    test('withdrawing voice ends the live session', () async {
      final api = instantApi();
      final before = await api.session(DemoData.liveSessionId);
      expect(before.isLive, isTrue);
      await api.recordConsent(
        DemoData.childMati,
        answer(ConsentPurpose.voice, false),
      );
      final after = await api.session(DemoData.liveSessionId);
      expect(after.status, 'ended');
      expect(after.endReason, 'parent_ended');
    });

    test('deleting a child takes its notices too', () async {
      final api = instantApi();
      await api.deleteChild(DemoData.childLu);
      final notices = await api.notices();
      expect(notices.where((n) => n.childId == DemoData.childLu), isEmpty);
      await expectLater(
        api.child(DemoData.childLu),
        throwsKind(ApiErrorKind.notFound),
      );
      expect((await api.me()).children, hasLength(1));
    });

    test('an update keeps the birth year and the team notes', () async {
      final api = instantApi();
      final detail = await api.child(DemoData.childMati);
      final updated = await api.updateChild(
        DemoData.childMati,
        ChildDraft.fromDetail(detail).copyWith(nickname: 'Matías'),
      );
      expect(updated.nickname, 'Matías');
      expect(updated.birthYear, detail.child.birthYear);
      expect(updated.notes, detail.child.notes);
    });
  });

  group('progress', () {
    test('the seed of Appendix B', () async {
      final api = instantApi();
      final reviews = await api.reviews(DemoData.childMati);
      expect(reviews, hasLength(3));
      expect(reviews[1].flags, <String>['struggling']);
      final skills = await api.skills(DemoData.childMati);
      expect(skills.masteredCount, 3);
      expect(skills.practisingCount, 2);
      expect(skills.next.map((next) => next.reason), <String>[
        'in_progress',
        'ready',
        'review_due',
      ]);
      final lu = await api.skills(DemoData.childLu);
      expect(lu.masteredCount, 1);
      final notices = await api.notices();
      expect(notices.map((n) => n.kind), <String>[
        'attention',
        'session_summary',
        'session_stopped',
      ]);
      expect(notices.first.unread, isTrue);
      expect((await api.me()).unreadNotices, 1);
    });

    test('notices follow the guardian language', () async {
      final api = instantApi();
      expect((await api.notices()).first.title, 'Mati puede necesitarte');
      await api.updateSettings(language: 'en');
      expect((await api.notices()).first.title, 'Mati may need you');
    });

    test('marking a notice read is safe to repeat', () async {
      final api = instantApi();
      final first = (await api.notices()).first;
      await api.markNoticeRead(first.id);
      await api.markNoticeRead(first.id);
      expect((await api.me()).unreadNotices, 0);
      await expectLater(
        api.markNoticeRead('missing'),
        throwsKind(ApiErrorKind.notFound),
      );
    });

    test('the live session counts down, and the demo renews it', () async {
      var now = DateTime.utc(2026, 11, 25, 10);
      final api = instantApi(clock: () => now);
      expect((await api.session(DemoData.liveSessionId)).remainingSeconds, 840);
      now = now.add(const Duration(seconds: 100));
      expect((await api.session(DemoData.liveSessionId)).remainingSeconds, 740);
      // Out of time: there is still a session to listen to in the demo.
      now = now.add(const Duration(minutes: 20));
      final status = await api.session(DemoData.liveSessionId);
      expect(status.status, 'active');
      expect(status.remainingSeconds, 840);
    });

    test("notices come in the guardian's language", () async {
      final api = instantApi();
      await api.updateSettings(language: 'en');
      final summary = (await api.notices()).firstWhere(
        (notice) => notice.kind == 'session_summary',
      );
      expect(summary.title, "Mati's session");
      expect(summary.body, startsWith('Mati practiced'));
    });

    test('ending a session from the app is parent_ended', () async {
      final api = instantApi();
      await api.endSession(DemoData.liveSessionId);
      final facts = await api.sessions(DemoData.childMati);
      final live = facts.firstWhere((s) => s.id == DemoData.liveSessionId);
      expect(live.isLive, isFalse);
      expect(live.endReason, 'parent_ended');
    });
  });

  group('account', () {
    test(
      'deleting checks the email, then resets to the signed-out seed',
      () async {
        final api = instantApi();
        await expectLater(
          api.deleteAccount(confirmEmail: 'otra@example.com'),
          throwsKind(ApiErrorKind.badRequest),
        );
        await api.deleteAccount(confirmEmail: ' ANA@example.com ');
        await expectLater(api.me(), throwsKind(ApiErrorKind.unauthorized));
        // The seed is back for the next sign-in.
        await api.startEmailSignIn(email: 'ana@example.com', language: 'es');
        await api.verifyEmailCode(
          email: 'ana@example.com',
          code: DemoData.signInCode,
          language: 'es',
        );
        expect((await api.me()).children, hasLength(2));
      },
    );
  });
}
