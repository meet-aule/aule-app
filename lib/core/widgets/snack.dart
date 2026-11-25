import 'package:material_ui/material_ui.dart';

/// A short message at the bottom: ink fill, surface text (§5).
void showNotice(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  showNoticeOn(messenger, text);
}

/// The same, on a messenger captured before an await or a navigation, so
/// the message can show on the next screen.
void showNoticeOn(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
