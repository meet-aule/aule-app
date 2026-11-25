import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

// app_localizations.dart is generated from app_en.arb and app_es.arb by
// gen-l10n on the first `flutter pub get`. It is never written by hand.
export 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The locale recorded with a consent answer: 'es-PE' or 'en', by the
/// language the text was shown in.
String consentLocaleOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'es-PE';
