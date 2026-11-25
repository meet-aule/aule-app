import '../json.dart';

class Review {
  const Review({
    required this.sessionId,
    required this.summary,
    this.nextStep,
    required this.flags,
    required this.createdAt,
  });

  factory Review.fromJson(Json json) => Review(
    sessionId: jString(json, 'session_id'),
    summary: jString(json, 'summary'),
    nextStep: jStringOrNull(json, 'next_step'),
    flags: jStrings(json, 'flags'),
    createdAt: jTime(json, 'created_at'),
  );

  final String sessionId;

  /// For the parent, in the child's language. Shown as it comes.
  final String summary;
  final String? nextStep;

  /// From distress, safety_concern, struggling, disengaged.
  final List<String> flags;
  final DateTime createdAt;
}

class SkillTrace {
  const SkillTrace({
    required this.skillId,
    required this.attempts,
    required this.pKnown,
    required this.pNow,
    required this.p7d,
    required this.halfLifeDays,
    this.reviewAt,
    required this.mastered,
    required this.targetDifficulty,
    required this.corrected,
  });

  factory SkillTrace.fromJson(Json json) => SkillTrace(
    skillId: jString(json, 'skill_id'),
    attempts: jInt(json, 'attempts'),
    pKnown: jDouble(json, 'p_known'),
    pNow: jDouble(json, 'p_now'),
    p7d: jDouble(json, 'p_7d'),
    halfLifeDays: jDouble(json, 'half_life_days'),
    reviewAt: jTimeOrNull(json, 'review_at'),
    mastered: jBool(json, 'mastered'),
    targetDifficulty: jDouble(json, 'target_difficulty'),
    corrected: jBool(json, 'corrected'),
  );

  final String skillId;
  final int attempts;
  final double pKnown;
  final double pNow;
  final double p7d;
  final double halfLifeDays;
  final DateTime? reviewAt;
  final bool mastered;
  final double targetDifficulty;
  final bool corrected;
}

class NextSkill {
  const NextSkill({
    required this.skillId,
    this.name,
    required this.reason,
    this.pNow,
    this.targetDifficulty,
  });

  factory NextSkill.fromJson(Json json) => NextSkill(
    skillId: jString(json, 'skill_id'),
    name: jStringOrNull(json, 'name'),
    reason: jStringOrNull(json, 'reason') ?? '',
    pNow: jDoubleOrNull(json, 'p_now'),
    targetDifficulty: jDoubleOrNull(json, 'target_difficulty'),
  );

  final String skillId;
  final String? name;

  /// review_due, in_progress, ready or asked.
  final String reason;
  final double? pNow;
  final double? targetDifficulty;
}

class SkillReport {
  const SkillReport({
    required this.ability,
    required this.skills,
    required this.next,
  });

  factory SkillReport.fromJson(Json json) => SkillReport(
    ability: jDouble(json, 'ability'),
    skills: jList(json, 'skills', SkillTrace.fromJson),
    next: jList(json, 'next', NextSkill.fromJson),
  );

  final double ability;
  final List<SkillTrace> skills;
  final List<NextSkill> next;

  /// Counted as the web counts them: skills with at least one attempt.
  Iterable<SkillTrace> get worked =>
      skills.where((skill) => skill.attempts > 0);
  int get masteredCount => worked.where((skill) => skill.mastered).length;
  int get practisingCount => worked.where((skill) => !skill.mastered).length;
}

class SkillInfo {
  const SkillInfo({
    required this.id,
    required this.subject,
    required this.name,
    this.grade,
    this.description,
    required this.prerequisites,
  });

  factory SkillInfo.fromJson(Json json) => SkillInfo(
    id: jString(json, 'id'),
    subject: jString(json, 'subject'),
    name: jString(json, 'name'),
    grade: jStringOrNull(json, 'grade'),
    description: jStringOrNull(json, 'description'),
    prerequisites: jStrings(json, 'prerequisites'),
  );

  final String id;
  final String subject;
  final String name;
  final String? grade;
  final String? description;
  final List<String> prerequisites;
}
