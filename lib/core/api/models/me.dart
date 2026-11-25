import '../json.dart';

class Guardian {
  const Guardian({
    required this.id,
    required this.email,
    required this.name,
    required this.language,
    required this.noticesByEmail,
    required this.noticesByPush,
  });

  factory Guardian.fromJson(Json json) => Guardian(
    id: jString(json, 'id'),
    email: jString(json, 'email'),
    name: jString(json, 'name'),
    language: jStringOrNull(json, 'language') ?? 'es',
    noticesByEmail: jBool(json, 'notices_by_email', fallback: true),
    noticesByPush: jBool(json, 'notices_by_push', fallback: true),
  );

  final String id;
  final String email;
  final String name;
  final String language;
  final bool noticesByEmail;
  final bool noticesByPush;

  Guardian copyWith({String? language, bool? noticesByEmail}) => Guardian(
    id: id,
    email: email,
    name: name,
    language: language ?? this.language,
    noticesByEmail: noticesByEmail ?? this.noticesByEmail,
    noticesByPush: noticesByPush,
  );
}

class ChildRef {
  const ChildRef({required this.id, required this.nickname});

  factory ChildRef.fromJson(Json json) =>
      ChildRef(id: jString(json, 'id'), nickname: jString(json, 'nickname'));

  final String id;
  final String nickname;
}

class Me {
  const Me({
    required this.guardian,
    required this.familyId,
    required this.children,
    required this.unreadNotices,
    required this.subjects,
  });

  factory Me.fromJson(Json json) => Me(
    guardian: Guardian.fromJson(jObject(json, 'guardian')),
    familyId: jString(json, 'family_id'),
    children: jList(json, 'children', ChildRef.fromJson),
    unreadNotices: jInt(json, 'unread_notices'),
    subjects: jStrings(json, 'subjects'),
  );

  final Guardian guardian;
  final String familyId;

  /// Oldest first.
  final List<ChildRef> children;
  final int unreadNotices;

  /// What a family may ask to reinforce: the five subject codes.
  final List<String> subjects;

  Me copyWith({
    Guardian? guardian,
    List<ChildRef>? children,
    int? unreadNotices,
  }) => Me(
    guardian: guardian ?? this.guardian,
    familyId: familyId,
    children: children ?? this.children,
    unreadNotices: unreadNotices ?? this.unreadNotices,
    subjects: subjects,
  );
}
