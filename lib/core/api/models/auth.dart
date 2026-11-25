import '../json.dart';

class TokenGrant {
  const TokenGrant({
    required this.token,
    required this.guardianId,
    required this.familyId,
    required this.newAccount,
    required this.expiresInDays,
  });

  factory TokenGrant.fromJson(Json json) => TokenGrant(
    token: jString(json, 'token'),
    guardianId: jString(json, 'guardian_id'),
    familyId: jString(json, 'family_id'),
    newAccount: jBool(json, 'new_account'),
    expiresInDays: jInt(json, 'expires_in_days', fallback: 30),
  );

  /// 64 lower-case hex characters. Secure storage only.
  final String token;
  final String guardianId;
  final String familyId;
  final bool newAccount;
  final int expiresInDays;

  @override
  String toString() => 'TokenGrant(<redacted>)';
}
