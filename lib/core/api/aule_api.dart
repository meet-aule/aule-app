import 'models/models.dart';

/// Everything the family app asks the platform, as the signed-in guardian.
abstract interface class AuleApi {
  // Sign-in. No token needed.
  Future<void> startEmailSignIn({
    required String email,
    required String language,
  });
  Future<TokenGrant> verifyEmailCode({
    required String email,
    required String code,
    String? name,
    required String language,
  });
  Future<String> googleClientId();
  Future<TokenGrant> signInWithGoogle({
    required String idToken,
    String? name,
    required String language,
  });

  // The signed-in guardian.
  Future<void> signOut();
  Future<Me> me();
  Future<void> updateSettings({String? language, bool? noticesByEmail});
  Future<void> deleteAccount({required String confirmEmail});

  // Children and consent.
  Future<Child> createChild({
    required String familyId,
    required ChildDraft draft,
  });
  Future<ChildDetail> child(String childId);
  Future<Child> updateChild(String childId, ChildDraft draft);
  Future<void> deleteChild(String childId);
  Future<ConsentState> recordConsent(String childId, ConsentAnswer answer);

  // Progress.
  Future<List<Review>> reviews(String childId);
  Future<SkillReport> skills(String childId);
  Future<List<SkillInfo>> skillCatalog();

  /// Gap 3. Called only when flags.sessionList is on.
  Future<List<SessionFact>> sessions(String childId, {int limit = 20});
  Future<SessionStatus> session(String sessionId);
  Future<void> endSession(String sessionId);

  // What Aule remembers.
  Future<List<Memory>> memories(String childId, {int limit = 100});
  Future<void> forgetMemory(String childId, String memoryId);

  // Notices.
  Future<List<Notice>> notices();
  Future<void> markNoticeRead(String noticeId);
}
