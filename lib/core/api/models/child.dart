import '../json.dart';
import 'consent.dart';

abstract final class ChildCodes {
  static const grades = <String>[
    'P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'S1', 'S2', 'S3', 'S4', 'S5', //
  ];
  static const subjects = <String>[
    'matematica', 'comunicacion', 'ciencia', 'personal_social', 'ingles', //
  ];
  static const personas = <String>[
    'calido',
    'jugueton',
    'aventurero',
    'tranquilo',
  ];
  static const relationships = <String>[
    'MTH', 'FTH', 'STPMTH', 'STPFTH', 'GRMTH', 'GRFTH', //
    'AUNT', 'UNCLE', 'SIB', 'GUARD', 'FAMMEMB',
  ];
  static const languages = <String>['es', 'en'];
  static const defaultPersona = 'calido';
  static const maxNicknameChars = 40;
  static const maxInterests = 10;
  static const maxInterestChars = 40;
  static const maxPersonaNoteChars = 200;
}

class Child {
  const Child({
    required this.id,
    required this.familyId,
    required this.nickname,
    this.birthYear,
    this.grade,
    required this.language,
    required this.interests,
    required this.subjects,
    this.notes,
    required this.tutorName,
    required this.tutorPersona,
    this.tutorPersonaNote,
    required this.createdAt,
  });

  factory Child.fromJson(Json json) => Child(
    id: jString(json, 'id'),
    familyId: jString(json, 'family_id'),
    nickname: jString(json, 'nickname'),
    birthYear: jIntOrNull(json, 'birth_year'),
    grade: jStringOrNull(json, 'grade'),
    language: jStringOrNull(json, 'language') ?? 'es',
    interests: jStrings(json, 'interests'),
    subjects: jStrings(json, 'subjects'),
    notes: jStringOrNull(json, 'notes'),
    tutorName: jStringOrNull(json, 'tutor_name') ?? 'Aule',
    tutorPersona:
        jStringOrNull(json, 'tutor_persona') ?? ChildCodes.defaultPersona,
    tutorPersonaNote: jStringOrNull(json, 'tutor_persona_note'),
    createdAt: jTime(json, 'created_at'),
  );

  final String id;
  final String familyId;
  final String nickname;
  final int? birthYear;
  final String? grade;
  final String language;
  final List<String> interests;
  final List<String> subjects;

  /// Written by Aule's team for the supervisor. Never shown; kept on PUT.
  final String? notes;

  /// Always "Aule": families do not change it, and the app never sends it.
  final String tutorName;
  final String tutorPersona;
  final String? tutorPersonaNote;
  final DateTime createdAt;
}

class ChildDetail {
  const ChildDetail({
    required this.child,
    required this.consent,
    this.relationship,
  });

  factory ChildDetail.fromJson(Json json) => ChildDetail(
    child: Child.fromJson(jObject(json, 'child')),
    consent: ConsentState.fromJson(
      jObjectOrNull(json, 'consent') ?? const <String, dynamic>{},
    ),
    relationship: jStringOrNull(json, 'relationship'),
  );

  final Child child;
  final ConsentState consent;

  /// What the signed-in guardian is to the child.
  final String? relationship;
}

enum ChildProblem {
  nicknameMissing,
  nicknameTooLong,
  tooManyInterests,
  interestTooLong,
  personaNoteTooLong,
  unknownCode,
}

/// The child as the forms edit it. PUT replaces the whole record, so a
/// draft for an existing child always starts from ChildDraft.fromDetail.
class ChildDraft {
  const ChildDraft({
    required this.nickname,
    this.birthYear,
    this.grade,
    this.language = 'es',
    this.interests = const <String>[],
    this.subjects = const <String>[],
    this.notes,
    this.tutorPersona = ChildCodes.defaultPersona,
    this.tutorPersonaNote = '',
    this.relationship,
  });

  factory ChildDraft.fromDetail(ChildDetail detail) => ChildDraft(
    nickname: detail.child.nickname,
    birthYear: detail.child.birthYear,
    grade: detail.child.grade,
    language: detail.child.language,
    interests: detail.child.interests,
    subjects: detail.child.subjects,
    notes: detail.child.notes,
    tutorPersona: detail.child.tutorPersona,
    tutorPersonaNote: detail.child.tutorPersonaNote ?? '',
    relationship: detail.relationship,
  );

  final String nickname;
  final int? birthYear;
  final String? grade;
  final String language;
  final List<String> interests;
  final List<String> subjects;
  final String? notes;
  final String tutorPersona;

  /// One line; empty removes the note.
  final String tutorPersonaNote;

  /// Null or empty is "I'd rather not say" and removes it.
  final String? relationship;

  /// The first problem, counted in Unicode scalar values as the server does.
  ChildProblem? validate() {
    final name = nickname.trim();
    if (name.isEmpty) return ChildProblem.nicknameMissing;
    if (name.runes.length > ChildCodes.maxNicknameChars) {
      return ChildProblem.nicknameTooLong;
    }
    if (interests.length > ChildCodes.maxInterests) {
      return ChildProblem.tooManyInterests;
    }
    for (final interest in interests) {
      final text = interest.trim();
      if (text.isEmpty || text.runes.length > ChildCodes.maxInterestChars) {
        return ChildProblem.interestTooLong;
      }
    }
    if (tutorPersonaNote.trim().runes.length > ChildCodes.maxPersonaNoteChars) {
      return ChildProblem.personaNoteTooLong;
    }
    final relation = relationship;
    final known =
        (grade == null || ChildCodes.grades.contains(grade)) &&
        ChildCodes.languages.contains(language) &&
        ChildCodes.personas.contains(tutorPersona) &&
        subjects.every(ChildCodes.subjects.contains) &&
        (relation == null ||
            relation.isEmpty ||
            ChildCodes.relationships.contains(relation));
    return known ? null : ChildProblem.unknownCode;
  }

  /// The whole record, for POST /families/{id}/children and PUT /children/{id}.
  /// Interests are trimmed and de-duplicated by the form before this.
  Json toJson() => <String, dynamic>{
    'nickname': nickname.trim(),
    'birth_year': birthYear,
    'grade': grade,
    'language': language,
    'interests': interests,
    'subjects': subjects,
    'notes': notes,
    'tutor_persona': tutorPersona,
    'tutor_persona_note': tutorPersonaNote
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .trim(),
    'relationship': relationship ?? '',
  };

  /// The same draft with some fields changed. Fields not named keep their
  /// value, so the birth year and the team's notes survive an edit.
  ChildDraft copyWith({
    String? nickname,
    String? grade,
    bool clearGrade = false,
    String? language,
    List<String>? interests,
    List<String>? subjects,
    String? tutorPersona,
    String? tutorPersonaNote,
    String? relationship,
    bool clearRelationship = false,
  }) => ChildDraft(
    nickname: nickname ?? this.nickname,
    birthYear: birthYear,
    grade: clearGrade ? null : (grade ?? this.grade),
    language: language ?? this.language,
    interests: interests ?? this.interests,
    subjects: subjects ?? this.subjects,
    notes: notes,
    tutorPersona: tutorPersona ?? this.tutorPersona,
    tutorPersonaNote: tutorPersonaNote ?? this.tutorPersonaNote,
    relationship: clearRelationship
        ? null
        : (relationship ?? this.relationship),
  );
}
