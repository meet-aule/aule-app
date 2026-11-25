import 'package:aule/core/api/fake/demo_data.dart';
import 'package:aule/core/api/models/models.dart';
import 'package:aule/features/progress/progress_store.dart';
import 'package:aule/features/progress/widgets/sessions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/harness.dart';

/// Lets the loads that run unawaited finish (the fake answers at once).
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('refresh loads notices, each child and the catalog', () async {
    final api = instantApi();
    final auth = await signedInAuth(api);
    final store = ProgressStore(api: api, auth: auth, flags: testConfig.flags);
    await store.refresh();

    expect(store.noticesLoaded, isTrue);
    expect(store.notices.first.kind, 'attention');
    final mati = store.progressOf(DemoData.childMati);
    expect(mati.loaded, isTrue);
    expect(mati.reviews, hasLength(3));
    expect(mati.skills!.masteredCount, 3);
    expect(mati.skills!.practisingCount, 2);
    expect(store.catalogAvailable, isTrue);
    expect(store.skillName('tabla-2'), 'Tabla del 2');
    expect(
      store.liveSessions(DemoData.childMati).single.id,
      DemoData.liveSessionId,
    );
    expect(store.liveSessions(DemoData.childLu), isEmpty);
    expect(store.noticesFor(DemoData.childLu).single.kind, 'session_stopped');
  });

  test('without sessionList no session is asked for', () async {
    final api = instantApi();
    final auth = await signedInAuth(api);
    final store = ProgressStore(
      api: api,
      auth: auth,
      flags: testConfigNoSessions.flags,
    );
    await store.refresh();
    expect(store.progressOf(DemoData.childMati).sessions, isNull);
    expect(store.liveSessions(DemoData.childMati), isEmpty);
  });

  test('opening a notice marks it read and the badge falls', () async {
    final api = instantApi();
    final auth = await signedInAuth(api);
    final store = ProgressStore(api: api, auth: auth, flags: testConfig.flags);
    await store.refresh();
    expect(auth.me!.unreadNotices, 1);
    final attention = store.notices.first;
    await store.markRead(attention.id);
    expect(store.notice(attention.id)!.unread, isFalse);
    expect(auth.me!.unreadNotices, 0);
  });

  test('ending live sessions reads them fresh from the platform', () async {
    final api = instantApi();
    final auth = await signedInAuth(api);
    final store = ProgressStore(api: api, auth: auth, flags: testConfig.flags);
    // Nothing loaded yet, so a cached list would miss the live session.
    expect(store.liveSessions(DemoData.childMati), isEmpty);
    expect(await store.endLiveSessions(DemoData.childMati), isTrue);
    final facts = await api.sessions(DemoData.childMati);
    expect(facts.where((session) => session.isLive), isEmpty);
    expect(
      facts.firstWhere((s) => s.id == DemoData.liveSessionId).endReason,
      'parent_ended',
    );
  });

  test('without sessionList no session can be ended', () async {
    final api = instantApi();
    final auth = await signedInAuth(api);
    final store = ProgressStore(
      api: api,
      auth: auth,
      flags: testConfigNoSessions.flags,
    );
    expect(await store.endLiveSessions(DemoData.childMati), isFalse);
  });

  test('a child added later is loaded at once', () async {
    final api = instantApi();
    final auth = await signedInAuth(api);
    final store = ProgressStore(api: api, auth: auth, flags: testConfig.flags);
    await store.refresh();
    final created = await api.createChild(
      familyId: auth.me!.familyId,
      draft: const ChildDraft(nickname: 'Pía'),
    );
    await auth.refreshMe();
    await settle();
    expect(store.progressOf(created.id).loaded, isTrue);
  });

  test('signing out forgets everything about the children', () async {
    final api = instantApi();
    final auth = await signedInAuth(api);
    final store = ProgressStore(api: api, auth: auth, flags: testConfig.flags);
    await store.refresh();
    await auth.signOut();
    expect(store.notices, isEmpty);
    expect(store.noticesLoaded, isFalse);
    expect(store.progressOf(DemoData.childMati).loaded, isFalse);
  });

  group('sessionEntries', () {
    test('facts merged with their reviews, newest first', () async {
      final api = instantApi();
      final auth = await signedInAuth(api);
      final store = ProgressStore(
        api: api,
        auth: auth,
        flags: testConfig.flags,
      );
      await store.refreshChild(DemoData.childMati);
      final entries = sessionEntries(
        store.progressOf(DemoData.childMati),
        withFacts: true,
      );
      expect(entries, hasLength(4));
      // The live session first, with no review yet.
      expect(entries.first.sessionId, DemoData.liveSessionId);
      expect(entries.first.fact!.isLive, isTrue);
      expect(entries.first.review, isNull);
      // Every ended one has its review.
      expect(entries.skip(1).every((entry) => entry.review != null), isTrue);
      for (var i = 1; i < entries.length; i++) {
        expect(entries[i - 1].at.isAfter(entries[i].at), isTrue);
      }
    });

    test('without facts, the reviews alone', () async {
      final api = instantApi();
      final auth = await signedInAuth(api);
      final store = ProgressStore(
        api: api,
        auth: auth,
        flags: testConfigNoSessions.flags,
      );
      await store.refreshChild(DemoData.childMati);
      final entries = sessionEntries(
        store.progressOf(DemoData.childMati),
        withFacts: false,
      );
      expect(entries, hasLength(3));
      expect(entries.every((entry) => entry.fact == null), isTrue);
    });
  });
}
