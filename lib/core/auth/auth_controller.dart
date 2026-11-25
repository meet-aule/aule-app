import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../api/aule_api.dart';
import '../api/models/models.dart';
import '../config/app_config.dart';
import '../log/app_log.dart';
import '../storage/app_prefs.dart';
import '../storage/token_store.dart';
import 'google_auth.dart';

enum AuthState { unknown, signedOut, signedIn }

enum SignInOutcome { signedIn, needsName }

/// The public surface of [AuthController] (§6.9). B2 uses [state], [me],
/// [children] and [language].
abstract class AuthControllerSurface extends ChangeNotifier {
  AuthState get state;

  /// Set when restore() failed on the network; /loading offers a retry.
  ApiException? get restoreError;
  Me? get me;
  List<ChildRef> get children; // me?.children ?? const []
  String get language; // 'es' or 'en'
  Locale get locale;

  /// The address being signed in with, between the email and code screens.
  String? get pendingEmail;

  /// One message for the sign-in screen: 'expired' or 'accountDeleted'.
  String? takeFlash();

  Future<void> restore();
  Future<void> startEmailSignIn(String email);
  Future<SignInOutcome> verifyCode(String code);

  /// Repeats the pending code or Google credential with the parent's name.
  Future<void> completeWithName(String name);
  Future<SignInOutcome> signInWithGoogle();
  Future<void> refreshMe();
  Future<void> setLanguage(String language);
  Future<void> setNoticesByEmail(bool value);
  Future<void> signOut();
  Future<void> deleteAccount(String confirmEmail);

  /// Called by the transport on any 401.
  void handleUnauthorized();
}

/// The signed-in guardian: the session, `me` and the UI language.
class AuthController extends AuthControllerSurface {
  AuthController({
    required AuleApi api,
    required TokenStore tokens,
    required AppPrefs prefs,
    required AppConfig config,
    GoogleAuth? google,
    Locale? deviceLocale,
  }) : _api = api,
       _tokens = tokens,
       _prefs = prefs,
       _config = config,
       _google = google {
    final device = deviceLocale ?? PlatformDispatcher.instance.locale;
    _language = prefs.uiLanguage ?? (device.languageCode == 'en' ? 'en' : 'es');
  }

  static const flashExpired = 'expired';
  static const flashAccountDeleted = 'accountDeleted';

  final AuleApi _api;
  final TokenStore _tokens;
  final AppPrefs _prefs;
  final AppConfig _config;
  final GoogleAuth? _google;

  AuthState _state = AuthState.unknown;
  ApiException? _restoreError;
  Me? _me;
  late String _language;
  String? _pendingEmail;
  String? _pendingCode;
  String? _pendingGoogleToken;
  String? _flash;
  bool _startDismissed = false;
  bool _disposed = false;

  @override
  AuthState get state => _state;

  @override
  ApiException? get restoreError => _restoreError;

  @override
  Me? get me => _me;

  @override
  List<ChildRef> get children => _me?.children ?? const <ChildRef>[];

  @override
  String get language => _language;

  @override
  Locale get locale => Locale(_language);

  @override
  String? get pendingEmail => _pendingEmail;

  /// Whether this build offers Google sign-in (flag on, Android only).
  bool get canUseGoogle => _google != null && _config.flags.googleSignIn;

  /// Whether a Google credential waits for the parent's name.
  bool get pendingGoogle => _pendingGoogleToken != null;

  /// Set by "Ahora no" on /start; kept in memory only, so a family with no
  /// children sees /start again on the next launch.
  bool get startDismissed => _startDismissed;

  void dismissStart() {
    if (_startDismissed) return;
    _startDismissed = true;
    _notify();
  }

  @override
  String? takeFlash() {
    final flash = _flash;
    _flash = null;
    return flash;
  }

  @override
  Future<void> restore() async {
    if (_state == AuthState.signedIn) return;
    if (_restoreError != null) {
      _restoreError = null;
      _notify();
    }
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      _state = AuthState.signedOut;
      _notify();
      return;
    }
    try {
      final me = await _api.me();
      _applyMe(me);
      _state = AuthState.signedIn;
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.unauthorized) {
        await _tokens.clear();
        _me = null;
        _state = AuthState.signedOut;
      } else {
        // Kept unknown: /loading shows the error and a retry.
        _restoreError = error;
      }
    }
    _notify();
  }

  @override
  Future<void> startEmailSignIn(String email) async {
    final address = email.trim().toLowerCase();
    await _api.startEmailSignIn(email: address, language: _language);
    _pendingEmail = address;
    _pendingCode = null;
    _pendingGoogleToken = null;
    _notify();
  }

  @override
  Future<SignInOutcome> verifyCode(String code) async {
    final email = _pendingEmail;
    if (email == null) {
      throw StateError('verifyCode needs startEmailSignIn first');
    }
    try {
      final grant = await _api.verifyEmailCode(
        email: email,
        code: code,
        language: _language,
      );
      await _enter(grant);
      return SignInOutcome.signedIn;
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.badRequest) {
        // A new address: the server keeps the code until it gets a name.
        _pendingCode = code;
        _notify();
        return SignInOutcome.needsName;
      }
      rethrow;
    }
  }

  @override
  Future<void> completeWithName(String name) async {
    final given = name.trim();
    final googleToken = _pendingGoogleToken;
    if (googleToken != null) {
      final grant = await _api.signInWithGoogle(
        idToken: googleToken,
        name: given,
        language: _language,
      );
      await _enter(grant);
      return;
    }
    final email = _pendingEmail;
    final code = _pendingCode;
    if (email == null || code == null) {
      throw StateError('completeWithName needs a pending sign-in');
    }
    final grant = await _api.verifyEmailCode(
      email: email,
      code: code,
      name: given,
      language: _language,
    );
    await _enter(grant);
  }

  @override
  Future<SignInOutcome> signInWithGoogle() async {
    final google = _google;
    if (google == null) throw StateError('Google sign-in is off');
    final idToken = await google.idToken();
    try {
      final grant = await _api.signInWithGoogle(
        idToken: idToken,
        language: _language,
      );
      await _enter(grant);
      return SignInOutcome.signedIn;
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.badRequest) {
        _pendingGoogleToken = idToken;
        _pendingEmail = null;
        _pendingCode = null;
        _notify();
        return SignInOutcome.needsName;
      }
      rethrow;
    }
  }

  @override
  Future<void> refreshMe() async {
    if (_state != AuthState.signedIn) return;
    try {
      final me = await _api.me();
      if (_state != AuthState.signedIn) return;
      _applyMe(me);
      _notify();
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.unauthorized) {
        handleUnauthorized();
      } else {
        AppLog.warn('auth.refresh_failed', <String, Object>{
          'kind': error.kind,
        });
      }
    }
  }

  @override
  Future<void> setLanguage(String language) async {
    final next = language == 'en' ? 'en' : 'es';
    if (_state == AuthState.signedIn) {
      await _api.updateSettings(language: next);
      final me = _me;
      if (me != null) {
        _me = me.copyWith(guardian: me.guardian.copyWith(language: next));
      }
    }
    _language = next;
    await _prefs.setUiLanguage(next);
    _notify();
  }

  @override
  Future<void> setNoticesByEmail(bool value) async {
    await _api.updateSettings(noticesByEmail: value);
    final me = _me;
    if (me != null) {
      _me = me.copyWith(guardian: me.guardian.copyWith(noticesByEmail: value));
    }
    _notify();
  }

  @override
  Future<void> signOut() async {
    try {
      await _api.signOut();
    } on Exception {
      // Signing out on the phone never fails.
    }
    await _tokens.clear();
    _clear(flash: null);
  }

  @override
  Future<void> deleteAccount(String confirmEmail) async {
    await _api.deleteAccount(confirmEmail: confirmEmail.trim());
    await _tokens.clear();
    _clear(flash: flashAccountDeleted);
  }

  @override
  void handleUnauthorized() {
    // During restore and sign-in, the callers handle a 401 themselves.
    if (_state != AuthState.signedIn) return;
    unawaited(_tokens.clear());
    _clear(flash: flashExpired);
  }

  /// Stores the token, loads `me`, and signs in. If `me` cannot be loaded,
  /// the token is kept and /loading offers a retry, because the code is
  /// already used up.
  Future<void> _enter(TokenGrant grant) async {
    await _tokens.write(grant.token);
    _pendingEmail = null;
    _pendingCode = null;
    _pendingGoogleToken = null;
    try {
      final me = await _api.me();
      _applyMe(me);
      _restoreError = null;
      _state = AuthState.signedIn;
    } on ApiException catch (error) {
      _restoreError = error;
      _state = AuthState.unknown;
    }
    _notify();
  }

  void _applyMe(Me me) {
    _me = me;
    final language = me.guardian.language == 'en' ? 'en' : 'es';
    if (language != _language) _language = language;
    unawaited(_prefs.setUiLanguage(language));
  }

  /// Forgets everything about the session. The stores watch [state] and
  /// clear themselves when it leaves signedIn.
  void _clear({required String? flash}) {
    _me = null;
    _pendingEmail = null;
    _pendingCode = null;
    _pendingGoogleToken = null;
    _restoreError = null;
    _startDismissed = false;
    _flash = flash;
    _state = AuthState.signedOut;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
