import '../json.dart';

class Memory {
  const Memory({
    required this.id,
    required this.kind,
    required this.content,
    required this.createdAt,
  });

  factory Memory.fromJson(Json json) => Memory(
    id: jString(json, 'id'),
    kind: jString(json, 'kind'),
    content: jString(json, 'content'),
    createdAt: jTime(json, 'created_at'),
  );

  final String id;

  /// fact, preference, struggle, success or summary.
  final String kind;
  final String content;
  final DateTime createdAt;
}
