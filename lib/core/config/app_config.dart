/// Features that need server or firmware work first (§10). In demo mode
/// every flag but [googleSignIn] is on, because the fakes implement the
/// proposed contracts.
class FeatureFlags {
  const FeatureFlags({
    required this.googleSignIn,
    required this.sessionList,
    required this.liveJoin,
    required this.deviceLink,
    required this.bleWifi,
  });

  /// Google sign-in, shown on Android only in v0.
  final bool googleSignIn;

  /// GET /v1/children/{id}/sessions (gap 3): session facts, live detection.
  final bool sessionList;

  /// POST and PUT /v1/sessions/{id}/join (gaps 4 and 5). Needs [sessionList].
  final bool liveJoin;

  /// The devices section and linking with a code (gap 8, firmware).
  final bool deviceLink;

  /// Wi-Fi over Bluetooth with BluFi (firmware: BluFi on for aule-v0.2).
  final bool bleWifi;
}

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.demo,
    required this.flags,
    required this.googleServerClientId,
    required this.googleIosClientId,
    required this.privacyPolicyUrl,
    required this.privacyPolicyUrlEn,
    required this.supportEmail,
    required this.version,
    this.playgroundUrl = '',
  });

  factory AppConfig.fromEnvironment() {
    const base = String.fromEnvironment('AULE_API_BASE');
    const demo = bool.fromEnvironment('AULE_DEMO') || base == '';
    return AppConfig(
      apiBaseUrl: demo ? '' : base,
      playgroundUrl: const String.fromEnvironment('AULE_PLAYGROUND_URL'),
      demo: demo,
      flags: demo
          ? const FeatureFlags(
              googleSignIn: false,
              sessionList: true,
              liveJoin: true,
              deviceLink: true,
              bleWifi: true,
            )
          : const FeatureFlags(
              googleSignIn: bool.fromEnvironment('AULE_FF_GOOGLE'),
              sessionList: bool.fromEnvironment('AULE_FF_SESSIONS'),
              liveJoin: bool.fromEnvironment('AULE_FF_LIVE'),
              deviceLink: bool.fromEnvironment('AULE_FF_DEVICE_LINK'),
              bleWifi: bool.fromEnvironment('AULE_FF_BLE_WIFI'),
            ),
      googleServerClientId: const String.fromEnvironment(
        'AULE_GOOGLE_SERVER_CLIENT_ID',
      ),
      googleIosClientId: const String.fromEnvironment(
        'AULE_GOOGLE_IOS_CLIENT_ID',
      ),
      privacyPolicyUrl: const String.fromEnvironment(
        'AULE_PRIVACY_URL',
        defaultValue: 'https://meetaule.com/legal/privacy',
      ),
      privacyPolicyUrlEn: const String.fromEnvironment(
        'AULE_PRIVACY_URL_EN',
        defaultValue: 'https://meetaule.com/en/legal/privacy',
      ),
      supportEmail: 'admin@meetaule.com',
      version: const String.fromEnvironment(
        'AULE_VERSION',
        defaultValue: '0.1.0',
      ),
    );
  }

  /// Ends in /v1, with no trailing slash. Empty in demo mode.
  final String apiBaseUrl;
  final bool demo;
  final FeatureFlags flags;

  /// The web OAuth client the platform checks ID tokens against. When empty,
  /// it is fetched from GET /v1/auth/google.
  final String googleServerClientId;
  final String googleIosClientId;

  /// The privacy policy in Spanish, the default.
  final String privacyPolicyUrl;

  /// The same policy in English.
  final String privacyPolicyUrlEn;
  final String supportEmail;
  final String version;
  final String playgroundUrl;

  /// Public worksheet URLs carry only a catalog ID and a language. A direct
  /// platform installation can supply its browser playground separately.
  Uri? resourceLink(String id, String language, {required bool practice}) {
    if (demo || !RegExp(r'^[a-z0-9-]+$').hasMatch(id)) return null;
    final explicit = playgroundUrl.isNotEmpty;
    final uri = Uri.tryParse(explicit ? playgroundUrl : apiBaseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    var base = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (!explicit) {
      if (!base.endsWith('/api/v1')) return null;
      base = base.substring(0, base.length - '/api/v1'.length);
    }
    return uri.replace(
      path: practice ? '$base/' : '$base/resources',
      queryParameters: {
        (practice ? 'practice' : 'activity'): id,
        'lang': language == 'en' ? 'en' : 'es',
      },
    );
  }

  /// The policy in the UI language: 'en' or anything else (Spanish).
  String privacyPolicyFor(String language) =>
      language == 'en' ? privacyPolicyUrlEn : privacyPolicyUrl;
}
