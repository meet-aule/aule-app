import '../json.dart';

abstract final class SessionCodes {
  static const liveStatuses = <String>{'created', 'active'};
  static const endReasons = <String>[
    'child_ended', 'idle', 'budget_reached', 'parent_ended', //
    'device_offline', 'not_working', 'error', 'provider_error',
  ];
  static const objectiveKinds = <String>[
    'homework', 'exam_prep', 'exam_review', 'explore', //
  ];
}

class Objective {
  const Objective({required this.kind, this.subject, this.topic, this.due});

  factory Objective.fromJson(Json json) => Objective(
    kind: jString(json, 'kind'),
    subject: jStringOrNull(json, 'subject'),
    topic: jStringOrNull(json, 'topic'),
    due: jStringOrNull(json, 'due'),
  );

  final String kind;

  /// A subject code, or 'other'.
  final String? subject;

  /// The family's own words, up to 200 characters. Shown as it comes.
  final String? topic;

  /// YYYY-MM-DD.
  final String? due;
}

/// One entry of GET /v1/children/{id}/sessions (gap 3).
class SessionFact {
  const SessionFact({
    required this.id,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.endReason,
    required this.engine,
    required this.language,
    this.objective,
    required this.onDevice,
    required this.reviewed,
  });

  factory SessionFact.fromJson(Json json) {
    final objective = jObjectOrNull(json, 'objective');
    return SessionFact(
      id: jString(json, 'id'),
      status: jString(json, 'status'),
      createdAt: jTime(json, 'created_at'),
      startedAt: jTimeOrNull(json, 'started_at'),
      endedAt: jTimeOrNull(json, 'ended_at'),
      endReason: jStringOrNull(json, 'end_reason'),
      engine: jBool(json, 'engine'),
      language: jStringOrNull(json, 'language') ?? 'es',
      objective: objective == null ? null : Objective.fromJson(objective),
      onDevice: jBool(json, 'on_device'),
      reviewed: jBool(json, 'reviewed'),
    );
  }

  final String id;

  /// created, active or ended.
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endReason;
  final bool engine;
  final String language;
  final Objective? objective;
  final bool onDevice;
  final bool reviewed;

  bool get isLive => SessionCodes.liveStatuses.contains(status);

  Duration? get duration {
    final end = endedAt;
    return end == null ? null : end.difference(startedAt ?? createdAt);
  }
}

/// GET /v1/sessions/{id}: the lifecycle only.
class SessionStatus {
  const SessionStatus({
    required this.status,
    this.endReason,
    required this.remainingSeconds,
    required this.canResume,
    required this.language,
    required this.engine,
  });

  factory SessionStatus.fromJson(Json json) => SessionStatus(
    status: jString(json, 'status'),
    endReason: jStringOrNull(json, 'end_reason'),
    remainingSeconds: jInt(json, 'remaining_seconds'),
    canResume: jBool(json, 'can_resume'),
    language: jStringOrNull(json, 'language') ?? 'es',
    engine: jBool(json, 'engine'),
  );

  final String status;
  final String? endReason;
  final int remainingSeconds;
  final bool canResume;
  final String language;
  final bool engine;

  bool get isLive => SessionCodes.liveStatuses.contains(status);
}
