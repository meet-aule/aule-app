import 'dart:convert';
import 'dart:io';

import 'package:aule/features/consent/consent_texts.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads an ARB file from the package root, where `flutter test` runs.
Map<String, dynamic> readArb(String name) =>
    jsonDecode(File('lib/core/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Iterable<String> messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@'));

/// Every versioned consent text, in both languages, as one SHA-256.
String consentFingerprint(Map<String, dynamic> es, Map<String, dynamic> en) {
  final buffer = StringBuffer();
  for (final key in kConsentTextKeys) {
    buffer.write('$key\t${es[key]}\t${en[key]}\n');
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

/// The fingerprint of each consent version's wording. Changing a text in
/// kConsentTextKeys needs a new kConsentPolicyVersion and a new line here.
const consentFingerprints = <String, String>{
  'app-2026-11-v2':
      'dff738e0c1425f933e492bc3c66a278e76d28df524f88d7bc3c89dbe58c86072',
};

void main() {
  final en = readArb('app_en.arb');
  final es = readArb('app_es.arb');

  test('both languages have the same messages, every one of §4', () {
    expect(en['@@locale'], 'en');
    expect(es['@@locale'], 'es');
    expect(messageKeys(es).toSet(), messageKeys(en).toSet());
    expect(messageKeys(en).length, greaterThanOrEqualTo(416));
  });

  test('the template describes every message', () {
    for (final key in messageKeys(en)) {
      expect(en['@$key'], isA<Map<String, dynamic>>(), reason: key);
    }
  });

  test('no exclamation marks, in the web app tone', () {
    for (final arb in <Map<String, dynamic>>[en, es]) {
      for (final key in messageKeys(arb)) {
        final value = arb[key] as String;
        expect(value.contains('!'), isFalse, reason: key);
        expect(value.contains('¡'), isFalse, reason: key);
      }
    }
  });

  test('declared placeholders appear in both languages', () {
    for (final key in messageKeys(en)) {
      final meta = en['@$key'] as Map<String, dynamic>;
      final placeholders =
          (meta['placeholders'] as Map<String, dynamic>?)?.keys ??
          const <String>[];
      for (final name in placeholders) {
        expect((en[key] as String).contains('{$name'), isTrue, reason: key);
        expect((es[key] as String).contains('{$name'), isTrue, reason: key);
      }
    }
  });

  test('counts are int placeholders, for the plural forms', () {
    for (final key in <String>[
      'progressUnread',
      'progressSkillsLine',
      'progressSkillsMastered',
      'progressSkillsPractising',
      'sessionMinutes',
      'liveTimeLeft',
      'memoriesLatest',
    ]) {
      final placeholders =
          (en['@$key'] as Map<String, dynamic>)['placeholders']
              as Map<String, dynamic>;
      for (final entry in placeholders.values) {
        expect((entry as Map<String, dynamic>)['type'], 'int', reason: key);
      }
    }
  });

  test('the consent texts are the ones recorded with their version', () {
    // The web's consent text P04, in both languages.
    expect(
      es['consentVoice'],
      startsWith('Soy su padre, madre o apoderado y autorizo'),
    );
    expect(es['consentNever'], endsWith('en Privacidad.'));
    expect(
      en['consentVoice'],
      startsWith('I am their parent or legal guardian'),
    );
    // Every versioned text exists in both languages...
    for (final key in kConsentTextKeys) {
      expect(es[key], isA<String>(), reason: key);
      expect(en[key], isA<String>(), reason: key);
    }
    // ...and is the wording its version names. A failure here means a
    // consent text changed: bump kConsentPolicyVersion and add its line.
    expect(
      consentFingerprint(es, en),
      consentFingerprints[kConsentPolicyVersion],
      reason: kConsentPolicyVersion,
    );
  });

  test('the device keys live in the one ARB pair gen-l10n reads', () {
    // gen-l10n reads only lib/core/l10n (l10n.yaml); a key elsewhere would
    // never reach AppLocalizations.
    expect(en['setupBtUnsupported'], isA<String>());
    expect(es['setupBtUnsupported'], isA<String>());
    final strays = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .where((file) => !file.path.contains('lib/core/l10n/'));
    expect(strays.map((file) => file.path), isEmpty);
  });
}
