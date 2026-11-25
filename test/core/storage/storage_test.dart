import 'package:aule/core/storage/app_prefs.dart';
import 'package:aule/core/storage/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TokenStore', () {
    test('keeps one token under its key, demo or not', () async {
      final secrets = MemorySecretStore();
      final real = TokenStore(demo: false, store: secrets);
      final demo = TokenStore(demo: true, store: secrets);
      await real.write('real-token');
      await demo.write('demo-token');
      expect(secrets.values, <String, String>{
        'aule.session': 'real-token',
        'aule.demo.session': 'demo-token',
      });
      expect(await real.read(), 'real-token');
      await real.clear();
      expect(await real.read(), isNull);
      expect(secrets.values.containsKey('aule.session'), isFalse);
    });

    test('a fresh install wipes everything', () async {
      final secrets = MemorySecretStore()
        ..values['aule.session'] = 'left from before'
        ..values['other'] = 'x';
      final tokens = TokenStore(demo: false, store: secrets);
      await tokens.wipeAll();
      expect(secrets.values, isEmpty);
      expect(await tokens.read(), isNull);
    });

    test('reads come from memory after the first one', () async {
      final secrets = MemorySecretStore()..values['aule.session'] = 'kept';
      final tokens = TokenStore(demo: false, store: secrets);
      expect(await tokens.read(), 'kept');
      secrets.values.clear();
      expect(await tokens.read(), 'kept');
    });
  });

  group('AppPrefs', () {
    test('only the install flag and the UI language', () async {
      final prefs = AppPrefs.memory(installed: false);
      expect(prefs.installed, isFalse);
      expect(prefs.uiLanguage, isNull);
      await prefs.markInstalled();
      await prefs.setUiLanguage('en');
      expect(prefs.installed, isTrue);
      expect(prefs.uiLanguage, 'en');
      await prefs.setUiLanguage('fr');
      expect(prefs.uiLanguage, 'es');
    });
  });
}
