import 'package:shared_preferences/shared_preferences.dart';

/// Plain preferences. Nothing about a child, and no token, ever goes here.
abstract interface class PrefsBackend {
  bool? getBool(String key);
  String? getString(String key);
  Future<void> setBool(String key, bool value);
  Future<void> setString(String key, String value);
}

/// The only two preferences the app keeps (§6.9): whether this install has
/// run before, and the UI language before sign-in.
class AppPrefs {
  AppPrefs(this._backend);

  /// Preferences in memory only, for tests.
  factory AppPrefs.memory({bool installed = true, String? uiLanguage}) {
    final backend = _MemoryBackend();
    backend.values[installedKey] = installed;
    if (uiLanguage != null) backend.values[uiLanguageKey] = uiLanguage;
    return AppPrefs(backend);
  }

  static const installedKey = 'aule.installed';
  static const uiLanguageKey = 'aule.ui_language';

  final PrefsBackend _backend;

  /// Loads the platform's preferences, allowing only the two keys above.
  static Future<AppPrefs> load() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: <String>{installedKey, uiLanguageKey},
      ),
    );
    return AppPrefs(_PlatformBackend(prefs));
  }

  /// False on the first launch after an install.
  bool get installed => _backend.getBool(installedKey) ?? false;

  Future<void> markInstalled() => _backend.setBool(installedKey, true);

  /// 'es', 'en', or null when never set.
  String? get uiLanguage {
    final value = _backend.getString(uiLanguageKey);
    return value == 'es' || value == 'en' ? value : null;
  }

  Future<void> setUiLanguage(String language) =>
      _backend.setString(uiLanguageKey, language == 'en' ? 'en' : 'es');
}

class _PlatformBackend implements PrefsBackend {
  _PlatformBackend(this._prefs);

  final SharedPreferencesWithCache _prefs;

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}

class _MemoryBackend implements PrefsBackend {
  final Map<String, Object> values = <String, Object>{};

  @override
  bool? getBool(String key) {
    final value = values[key];
    return value is bool ? value : null;
  }

  @override
  String? getString(String key) {
    final value = values[key];
    return value is String ? value : null;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
