import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/app_config.dart';
import 'l10n/l10n.dart';
import 'log/app_log.dart';
import 'widgets/snack.dart';

/// Opens the privacy policy, in the UI language, in the system browser,
/// never in a web view.
Future<void> openPrivacyPolicy(BuildContext context) {
  final config = context.read<AppConfig>();
  final language = Localizations.localeOf(context).languageCode;
  return _open(context, Uri.parse(config.privacyPolicyFor(language)));
}

/// Opens the mail app with a message to Aule's support address.
Future<void> openSupportMail(BuildContext context) {
  final config = context.read<AppConfig>();
  return _open(context, Uri(scheme: 'mailto', path: config.supportEmail));
}

Future<void> _open(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = context.l10n.errorGeneric;
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    opened = false;
  }
  if (!opened) {
    AppLog.warn('link.failed', <String, Object>{'scheme': uri.scheme});
    if (messenger != null) showNoticeOn(messenger, failed);
  }
}
