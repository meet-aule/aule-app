import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../log/app_log.dart';

/// Where secrets live: the Keychain on iOS and the cipher store on Android.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// The platform's secure storage (§6.9).
class SecureSecretStore implements SecretStore {
  SecureSecretStore()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// Secrets in memory only, for tests.
class MemorySecretStore implements SecretStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }
}

/// The guardian's token, and nothing else. It never goes to preferences,
/// files, logs or URLs. A copy is kept in memory while the app runs, so each
/// request does not reach the Keychain.
class TokenStore {
  TokenStore({required bool demo, SecretStore? store})
    : _key = demo ? 'aule.demo.session' : 'aule.session',
      _store = store ?? SecureSecretStore();

  /// A store in memory only, for tests.
  TokenStore.memory({bool demo = false})
    : this(demo: demo, store: MemorySecretStore());

  final String _key;
  final SecretStore _store;
  String? _cached;
  bool _loaded = false;

  Future<String?> read() async {
    if (_loaded) return _cached;
    try {
      _cached = await _store.read(_key);
    } on Exception {
      AppLog.warn('token.read_failed');
      _cached = null;
    }
    _loaded = true;
    return _cached;
  }

  Future<void> write(String token) async {
    _cached = token;
    _loaded = true;
    try {
      await _store.write(_key, token);
    } on Exception {
      // The session still works until the app closes.
      AppLog.warn('token.write_failed');
    }
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    try {
      await _store.delete(_key);
    } on Exception {
      AppLog.warn('token.clear_failed');
    }
  }

  /// Everything this app ever put in secure storage. The Keychain survives
  /// an uninstall, so a fresh install calls this first.
  Future<void> wipeAll() async {
    _cached = null;
    _loaded = true;
    try {
      await _store.deleteAll();
    } on Exception {
      AppLog.warn('token.wipe_failed');
    }
  }
}
