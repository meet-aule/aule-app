import 'package:aule/core/l10n/dates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../harness.dart';

void main() {
  // In the app the Material localizations load these symbols.
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });

  // Wednesday, 25 November 2026, at noon on the phone's clock.
  final now = DateTime(2026, 11, 25, 12);

  test('today and yesterday by the calendar day, not by 24 hours', () {
    expect(formatDay(es, 'es', DateTime(2026, 11, 25, 0, 5), now), 'Hoy');
    expect(formatDay(es, 'es', DateTime(2026, 11, 24, 23, 59), now), 'Ayer');
    expect(formatDay(en, 'en', DateTime(2026, 11, 24, 0, 1), now), 'Yesterday');
  });

  test('after a colon, today and yesterday are lower case', () {
    final today = DateTime(2026, 11, 25, 9);
    final yesterday = DateTime(2026, 11, 24, 9);
    expect(formatDay(es, 'es', today, now, inline: true), 'hoy');
    expect(formatDay(es, 'es', yesterday, now, inline: true), 'ayer');
    expect(formatDay(en, 'en', today, now, inline: true), 'today');
    expect(
      es.progressLastSession(formatDay(es, 'es', today, now, inline: true)),
      'Última sesión: hoy',
    );
  });

  test('older days as a long date in the UI language', () {
    final monday = DateTime(2026, 11, 23, 16, 40);
    expect(formatDay(es, 'es', monday, now), 'lunes 23 de noviembre');
    expect(formatDay(en, 'en', monday, now), 'Monday, November 23');
  });

  test('another year shows the year', () {
    final last = DateTime(2025, 12, 31, 9);
    expect(formatDay(es, 'es', last, now), contains('2025'));
    expect(formatDay(en, 'en', last, now), contains('2025'));
  });

  test('times: 24-hour in Spanish, h:mm a in English', () {
    final at = DateTime(2026, 11, 23, 16, 5);
    expect(formatTime('es', at), '16:05');
    expect(formatTime('en', at), '4:05 PM');
  });

  test('a UTC time from the server is shown on the phone clock', () {
    final utc = DateTime.utc(2026, 11, 23, 21, 5);
    expect(formatTime('es', utc), formatTime('es', utc.toLocal()));
  });
}
