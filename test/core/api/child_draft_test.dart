import 'package:aule/core/api/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

ChildDetail detail({
  String? notes = 'Written by the team.',
  int? birthYear = 2018,
}) => ChildDetail(
  child: Child(
    id: 'c1',
    familyId: 'f1',
    nickname: 'Mati',
    birthYear: birthYear,
    grade: 'P3',
    language: 'es',
    interests: const <String>['fútbol', 'dinosaurios'],
    subjects: const <String>['matematica'],
    notes: notes,
    tutorName: 'Aule',
    tutorPersona: 'jugueton',
    tutorPersonaNote: 'Va despacio',
    createdAt: DateTime.utc(2026, 10),
  ),
  consent: ConsentState.none,
  relationship: 'MTH',
);

void main() {
  group('toJson', () {
    test('sends the whole record, so PUT keeps notes and birth_year', () {
      final draft = ChildDraft.fromDetail(detail())
          .copyWith(nickname: '  Matías ', grade: 'P4');
      final json = draft.toJson();
      expect(json['nickname'], 'Matías');
      expect(json['grade'], 'P4');
      expect(json['notes'], 'Written by the team.');
      expect(json['birth_year'], 2018);
      expect(json['interests'], <String>['fútbol', 'dinosaurios']);
      expect(json['subjects'], <String>['matematica']);
      expect(json['tutor_persona'], 'jugueton');
      expect(json['tutor_persona_note'], 'Va despacio');
      expect(json['relationship'], 'MTH');
      expect(json.containsKey('tutor_name'), isFalse);
    });

    test('a null birth year and notes go as null, never dropped', () {
      final json = ChildDraft.fromDetail(detail(notes: null, birthYear: null))
          .toJson();
      expect(json.containsKey('birth_year'), isTrue);
      expect(json['birth_year'], isNull);
      expect(json.containsKey('notes'), isTrue);
      expect(json['notes'], isNull);
    });

    test(
      'the note is one line and "rather not say" removes the relationship',
      () {
        final draft = ChildDraft.fromDetail(detail()).copyWith(
          tutorPersonaNote: 'se frustra\nrápido\r\n ',
          clearRelationship: true,
          clearGrade: true,
        );
        final json = draft.toJson();
        expect(json['tutor_persona_note'], 'se frustra rápido');
        expect(json['relationship'], '');
        expect(json['grade'], isNull);
      },
    );
  });

  group('validate', () {
    test('a good draft has no problem', () {
      expect(const ChildDraft(nickname: 'Mati').validate(), isNull);
      expect(ChildDraft.fromDetail(detail()).validate(), isNull);
    });

    test('the nickname is required and at most 40 characters', () {
      expect(
        const ChildDraft(nickname: '   ').validate(),
        ChildProblem.nicknameMissing,
      );
      expect(ChildDraft(nickname: 'a' * 40).validate(), isNull);
      expect(
        ChildDraft(nickname: 'a' * 41).validate(),
        ChildProblem.nicknameTooLong,
      );
    });

    test('counts Unicode scalar values, as the server does', () {
      // Each star is one scalar value but two UTF-16 code units.
      final forty = '\u{1F31F}' * 40;
      expect(forty.length, 80);
      expect(ChildDraft(nickname: forty).validate(), isNull);
      expect(
        ChildDraft(nickname: '$forty\u{1F31F}').validate(),
        ChildProblem.nicknameTooLong,
      );
    });

    test('at most ten interests of 1 to 40 characters', () {
      expect(
        ChildDraft(
          nickname: 'Lu',
          interests: List<String>.generate(11, (i) => 'cosa $i'),
        ).validate(),
        ChildProblem.tooManyInterests,
      );
      expect(
        const ChildDraft(nickname: 'Lu', interests: <String>[' ']).validate(),
        ChildProblem.interestTooLong,
      );
      expect(
        ChildDraft(nickname: 'Lu', interests: <String>['a' * 41]).validate(),
        ChildProblem.interestTooLong,
      );
    });

    test('the note is at most 200 characters', () {
      expect(
        ChildDraft(nickname: 'Lu', tutorPersonaNote: 'a' * 201).validate(),
        ChildProblem.personaNoteTooLong,
      );
    });

    test('codes must be the platform\'s', () {
      expect(
        const ChildDraft(nickname: 'Lu', grade: 'P7').validate(),
        ChildProblem.unknownCode,
      );
      expect(
        const ChildDraft(nickname: 'Lu', language: 'fr').validate(),
        ChildProblem.unknownCode,
      );
      expect(
        const ChildDraft(nickname: 'Lu', tutorPersona: 'serio').validate(),
        ChildProblem.unknownCode,
      );
      expect(
        const ChildDraft(nickname: 'Lu', subjects: <String>['arte']).validate(),
        ChildProblem.unknownCode,
      );
      expect(
        const ChildDraft(nickname: 'Lu', relationship: 'BOSS').validate(),
        ChildProblem.unknownCode,
      );
      expect(
        const ChildDraft(nickname: 'Lu', relationship: '').validate(),
        isNull,
      );
    });
  });
}
