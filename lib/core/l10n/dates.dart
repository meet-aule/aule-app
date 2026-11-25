import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';

/// commonToday, commonYesterday, or a long date in the UI locale. [inline]
/// gives the lower-case "hoy" and "ayer" for use after a colon, as in
/// "Última sesión: hoy".
String dayLabel(BuildContext context, DateTime at, {bool inline = false}) =>
    formatDay(
      context.l10n,
      Localizations.localeOf(context).languageCode,
      at,
      DateTime.now(),
      inline: inline,
    );

/// HH:mm in Spanish, h:mm a in English, in the phone's time zone.
String timeLabel(BuildContext context, DateTime at) =>
    formatTime(Localizations.localeOf(context).languageCode, at);

/// A long date without "today" or "yesterday", such as "lunes 23 de
/// noviembre" or "Monday, November 23". The year is added when it is not
/// this year.
String longDateLabel(BuildContext context, DateTime at) => formatLongDate(
  Localizations.localeOf(context).languageCode,
  at,
  DateTime.now(),
);

/// The body of [dayLabel], with the clock passed in so tests can fix it.
@visibleForTesting
String formatDay(
  AppLocalizations l10n,
  String language,
  DateTime at,
  DateTime now, {
  bool inline = false,
}) {
  final local = at.toLocal();
  final clock = now.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(clock.year, clock.month, clock.day);
  if (day == today) return inline ? l10n.commonTodayInline : l10n.commonToday;
  if (day == DateTime(clock.year, clock.month, clock.day - 1)) {
    return inline ? l10n.commonYesterdayInline : l10n.commonYesterday;
  }
  return formatLongDate(language, local, clock);
}

@visibleForTesting
String formatLongDate(String language, DateTime at, DateTime now) {
  final local = at.toLocal();
  final sameYear = local.year == now.toLocal().year;
  final english = language == 'en';
  final pattern = english
      ? (sameYear ? 'EEEE, MMMM d' : 'EEEE, MMMM d, y')
      : (sameYear ? "EEEE d 'de' MMMM" : "EEEE d 'de' MMMM 'de' y");
  return _format(pattern, english ? 'en' : 'es', local);
}

@visibleForTesting
String formatTime(String language, DateTime at) {
  final english = language == 'en';
  return _format(english ? 'h:mm a' : 'HH:mm', english ? 'en' : 'es', at);
}

String _format(String pattern, String locale, DateTime at) {
  final local = at.toLocal();
  try {
    return DateFormat(pattern, locale).format(local);
  } on Object {
    // The date symbols come with the Material localizations. If they were
    // ever missing, a numeric date is better than a broken screen.
    return DateFormat('yyyy-MM-dd HH:mm').format(local);
  }
}
