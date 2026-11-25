import 'package:aule/core/api/fake/demo_data.dart';
import 'package:aule/core/api/models/models.dart';
import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/features/children/child_form.dart';
import 'package:aule/features/children/children_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/harness.dart';

ChildDetail matiDetail() => ChildDetail(
  child: Child(
    id: 'c1',
    familyId: 'f1',
    nickname: 'Mati',
    birthYear: 2018,
    grade: 'P3',
    language: 'es',
    interests: const <String>['fútbol'],
    subjects: const <String>['matematica'],
    notes: 'From the team.',
    tutorName: 'Aule',
    tutorPersona: 'calido',
    createdAt: DateTime.utc(2026, 10),
  ),
  consent: ConsentState.none,
  relationship: 'MTH',
);

void main() {
  group('ChildFormValues', () {
    test('an edit keeps what the form does not show', () {
      final values = ChildFormValues(ChildDraft.fromDetail(matiDetail()));
      values.nickname.text = ' Matías ';
      values.grade = 'P4';
      values.persona = 'aventurero';
      final draft = values.toDraft();
      expect(draft.nickname, 'Matías');
      expect(draft.grade, 'P4');
      expect(draft.tutorPersona, 'aventurero');
      expect(draft.birthYear, 2018);
      expect(draft.notes, 'From the team.');
      expect(draft.relationship, 'MTH');
      values.dispose();
    });

    test('interests are trimmed, unique, and at most ten', () {
      final values = ChildFormValues(const ChildDraft(nickname: 'Lu'));
      expect(values.toggleInterest(' cuentos '), isTrue);
      expect(values.toggleInterest('Cuentos'), isTrue); // removes it
      expect(values.interests, isEmpty);
      for (var i = 0; i < 10; i++) {
        expect(values.toggleInterest('cosa $i'), isTrue);
      }
      expect(values.toggleInterest('una más'), isFalse);
      expect(values.toDraft().interests, hasLength(10));
      values.dispose();
    });

    test('"rather not say" removes the grade and the relationship', () {
      final values = ChildFormValues(ChildDraft.fromDetail(matiDetail()));
      values.grade = null;
      values.relationship = null;
      final json = values.toDraft().toJson();
      expect(json['grade'], isNull);
      expect(json['relationship'], '');
      values.dispose();
    });

    test('the note becomes one line', () {
      final values = ChildFormValues(const ChildDraft(nickname: 'Lu'));
      values.note.text = 've\ndespacio';
      expect(values.toDraft().tutorPersonaNote, 've despacio');
      values.dispose();
    });

    test('problems land under their field', () {
      final values = ChildFormValues(const ChildDraft(nickname: ''));
      expect(values.showProblem(ChildProblem.nicknameMissing, es), isTrue);
      expect(values.nameError, es.childNameMissing);
      expect(values.showProblem(ChildProblem.unknownCode, es), isFalse);
      values.clearErrors();
      expect(values.nameError, isNull);
      values.dispose();
    });
  });

  group('ChildrenStore', () {
    test('loads each child of me, with their consent', () async {
      final api = instantApi();
      final auth = await signedInAuth(api);
      final store = ChildrenStore(api: api, auth: auth);
      await store.loadAll();
      expect(store.detail(DemoData.childMati)!.consent.memory, isTrue);
      expect(store.detail(DemoData.childLu)!.consent.memory, isFalse);
      expect(store.detail(DemoData.childMati)!.relationship, 'MTH');
    });

    test('an update sends the whole record and refreshes me', () async {
      final api = instantApi();
      final auth = await signedInAuth(api);
      final store = ChildrenStore(api: api, auth: auth);
      final detail = await store.load(DemoData.childMati);
      await store.update(
        DemoData.childMati,
        ChildDraft.fromDetail(detail).copyWith(nickname: 'Matías'),
      );
      expect(store.detail(DemoData.childMati)!.child.nickname, 'Matías');
      expect(
        store.detail(DemoData.childMati)!.child.birthYear,
        detail.child.birthYear,
      );
      expect(auth.children.first.nickname, 'Matías');
    });

    test('deleting a child drops it here and from me', () async {
      final api = instantApi();
      final auth = await signedInAuth(api);
      final store = ChildrenStore(api: api, auth: auth);
      await store.loadAll();
      await store.delete(DemoData.childLu);
      expect(store.detail(DemoData.childLu), isNull);
      expect(auth.children.map((child) => child.id), <String>[
        DemoData.childMati,
      ]);
    });

    test('a child added later is loaded for Privacy at once', () async {
      final api = instantApi();
      final auth = await signedInAuth(api);
      final store = ChildrenStore(api: api, auth: auth);
      await store.loadAll();
      final created = await api.createChild(
        familyId: auth.me!.familyId,
        draft: const ChildDraft(nickname: 'Pía'),
      );
      await auth.refreshMe();
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(store.detail(created.id)!.child.nickname, 'Pía');
    });

    test('signing out forgets every child', () async {
      final api = instantApi();
      final auth = await signedInAuth(api);
      final store = ChildrenStore(api: api, auth: auth);
      await store.loadAll();
      await auth.signOut();
      expect(auth.state, AuthState.signedOut);
      expect(store.detail(DemoData.childMati), isNull);
      expect(store.detail(DemoData.childLu), isNull);
    });
  });
}
