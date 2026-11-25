import 'package:aule/features/auth/email_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('addresses the platform accepts', () {
    for (final email in <String>[
      'ana@example.com',
      ' Ana@Example.com ',
      'a.b+c@sub.example.pe',
    ]) {
      expect(isValidEmail(email), isTrue, reason: email);
    }
  });

  test('addresses the platform refuses', () {
    for (final email in <String>[
      '',
      'ana',
      'ana@example',
      '@example.com',
      'ana@@example.com',
      'a@b@example.com',
      'ana@.example.com',
      'ana@example.com.',
      'an a@example.com',
      '${'a' * 250}@example.com',
    ]) {
      expect(isValidEmail(email), isFalse, reason: email);
    }
  });

  test('masking keeps the first character and the domain', () {
    expect(maskEmail('ana@dominio.com'), 'a•••@dominio.com');
    expect(maskEmail('x@example.com'), 'x•••@example.com');
    expect(maskEmail('not an email'), 'not an email');
  });
}
