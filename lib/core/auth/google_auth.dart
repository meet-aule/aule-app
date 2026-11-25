import 'package:google_sign_in/google_sign_in.dart';

import '../log/app_log.dart';

/// The parent cancelled the Google sheet. Callers show nothing.
class SignInCanceled implements Exception {
  const SignInCanceled();

  @override
  String toString() => 'SignInCanceled';
}

/// Google answered without an ID token, or refused the sign-in.
class GoogleSignInFailed implements Exception {
  const GoogleSignInFailed();

  @override
  String toString() => 'GoogleSignInFailed';
}

/// Native Google sign-in, Android only in v0 (§2.1). It gets one ID token
/// for the platform and keeps no Google session afterwards.
class GoogleAuth {
  GoogleAuth({
    required String serverClientId,
    required Future<String> Function() fetchClientId,
  }) : _serverClientId = serverClientId,
       _fetchClientId = fetchClientId;

  final String _serverClientId;
  final Future<String> Function() _fetchClientId;
  bool _initialized = false;

  /// Runs Google's sign-in and answers its ID token. Throws [SignInCanceled]
  /// when the parent cancels, and [GoogleSignInFailed] or the platform's
  /// error otherwise.
  Future<String> idToken() async {
    final signIn = GoogleSignIn.instance;
    if (!_initialized) {
      final id = _serverClientId.isNotEmpty
          ? _serverClientId
          : await _fetchClientId();
      await signIn.initialize(serverClientId: id);
      _initialized = true;
    }
    try {
      final account = await signIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) throw const GoogleSignInFailed();
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCanceled();
      }
      AppLog.warn('google.failed', <String, Object>{'code': error.code});
      throw const GoogleSignInFailed();
    } finally {
      // The app keeps no Google session: the platform's token is enough.
      try {
        await signIn.signOut();
      } on Exception {
        AppLog.warn('google.sign_out_failed');
      }
    }
  }
}
