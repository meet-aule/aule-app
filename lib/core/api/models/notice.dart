import '../json.dart';

class Notice {
  const Notice({
    required this.id,
    this.childId,
    this.sessionId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory Notice.fromJson(Json json) => Notice(
    id: jString(json, 'id'),
    childId: jStringOrNull(json, 'child_id'),
    sessionId: jStringOrNull(json, 'session_id'),
    kind: jString(json, 'kind'),
    title: jString(json, 'title'),
    body: jString(json, 'body'),
    createdAt: jTime(json, 'created_at'),
    readAt: jTimeOrNull(json, 'read_at'),
  );

  final String id;
  final String? childId;
  final String? sessionId;

  /// session_summary, attention or session_stopped.
  final String kind;

  /// Written by the server in the family's language. Shown as it comes.
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  Notice markedRead(DateTime at) => Notice(
    id: id,
    childId: childId,
    sessionId: sessionId,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    readAt: readAt ?? at,
  );
}
