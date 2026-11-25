import '../api/models/session.dart';
import 'app_localizations.dart';

/// Family-facing labels for the server's codes (§4.2). Server texts are never
/// passed through here: only codes are localized.
extension AuleLabels on AppLocalizations {
  /// A grade code, P1 to P6 or S1 to S5. An unknown code is shown as it is.
  String grade(String code) => switch (code.toUpperCase()) {
    'P1' => gradeP1,
    'P2' => gradeP2,
    'P3' => gradeP3,
    'P4' => gradeP4,
    'P5' => gradeP5,
    'P6' => gradeP6,
    'S1' => gradeS1,
    'S2' => gradeS2,
    'S3' => gradeS3,
    'S4' => gradeS4,
    'S5' => gradeS5,
    _ => code,
  };

  /// A subject code; 'other' and unknown codes are "another subject".
  String subject(String code) => switch (code) {
    'matematica' => subjectMatematica,
    'comunicacion' => subjectComunicacion,
    'ciencia' => subjectCiencia,
    'personal_social' => subjectPersonalSocial,
    'ingles' => subjectIngles,
    _ => subjectOther,
  };

  String personaTitle(String code) => switch (code) {
    'jugueton' => personaJugueton,
    'aventurero' => personaAventurero,
    'tranquilo' => personaTranquilo,
    _ => personaCalido,
  };

  String personaHint(String code) => switch (code) {
    'jugueton' => personaJuguetonHint,
    'aventurero' => personaAventureroHint,
    'tranquilo' => personaTranquiloHint,
    _ => personaCalidoHint,
  };

  String relationship(String code) => switch (code) {
    'MTH' => relationshipMth,
    'FTH' => relationshipFth,
    'STPMTH' => relationshipStpmth,
    'STPFTH' => relationshipStpfth,
    'GRMTH' => relationshipGrmth,
    'GRFTH' => relationshipGrfth,
    'AUNT' => relationshipAunt,
    'UNCLE' => relationshipUncle,
    'SIB' => relationshipSib,
    'GUARD' => relationshipGuard,
    _ => relationshipFammemb,
  };

  /// Why a session ended. `error` and `provider_error` read the same, and an
  /// unknown reason is just "ended".
  String endReason(String code, String nickname) => switch (code) {
    'child_ended' => endReasonChildEnded(nickname),
    'idle' => endReasonIdle,
    'budget_reached' => endReasonBudgetReached,
    'parent_ended' => endReasonParentEnded,
    'device_offline' => endReasonDeviceOffline,
    'not_working' => endReasonNotWorking,
    'error' || 'provider_error' => endReasonError,
    _ => endReasonOther,
  };

  /// A review flag. An unknown flag is not shown, so it gives null.
  String? flag(String code) => switch (code) {
    'distress' => flagDistress,
    'safety_concern' => flagSafetyConcern,
    'struggling' => flagStruggling,
    'disengaged' => flagDisengaged,
    _ => null,
  };

  /// Why a skill comes next. An unknown reason shows no tag.
  String? nextReason(String code) => switch (code) {
    'review_due' => reasonReviewDue,
    'in_progress' => reasonInProgress,
    'ready' => reasonReady,
    'asked' => reasonAsked,
    _ => null,
  };

  String noticeKind(String kind) => switch (kind) {
    'session_summary' => noticeKindSessionSummary,
    'attention' => noticeKindAttention,
    'session_stopped' => noticeKindSessionStopped,
    _ => noticeKindOther,
  };

  /// What kind of memory it is. An unknown kind shows no tag.
  String? memoryKind(String kind) => switch (kind) {
    'fact' => memoryKindFact,
    'preference' => memoryKindPreference,
    'struggle' => memoryKindStruggle,
    'success' => memoryKindSuccess,
    'summary' => memoryKindSummary,
    _ => null,
  };

  /// "Tarea de Matemática" or "Explorar Comunicación": each kind has its own
  /// pattern, because Spanish joins them differently. Just the kind when
  /// there is no subject. An unknown kind falls back to the subject alone,
  /// or to an empty text that callers leave out.
  String objective(Objective objective) {
    final code = objective.subject;
    final subjectLabel = code == null || code.isEmpty ? null : subject(code);
    return switch ((objective.kind, subjectLabel)) {
      ('homework', null) => objectiveHomework,
      ('homework', final label?) => objectiveHomeworkIn(label),
      ('exam_prep', null) => objectiveExamPrep,
      ('exam_prep', final label?) => objectiveExamPrepIn(label),
      ('exam_review', null) => objectiveExamReview,
      ('exam_review', final label?) => objectiveExamReviewIn(label),
      ('explore', null) => objectiveExplore,
      ('explore', final label?) => objectiveExploreIn(label),
      (_, final label) => label ?? '',
    };
  }

  /// What a child masters and practises, counted as the web counts them.
  /// Callers show progressNoExercises when nothing was worked on yet.
  String skillsLine(int mastered, int practising) {
    if (mastered > 0 && practising > 0) {
      return progressSkillsLine(mastered, practising);
    }
    if (mastered > 0) return progressSkillsMastered(mastered);
    return progressSkillsPractising(practising);
  }
}
