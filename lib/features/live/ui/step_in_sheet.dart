import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/widgets/sheets.dart';
import 'package:material_ui/material_ui.dart';

/// Before the microphone goes on: Aule pauses and tells the child. True
/// when the parent confirmed.
Future<bool> showStepInSheet(BuildContext context, {required String nickname}) {
  final l10n = context.l10n;
  return showConfirmSheet(
    context,
    title: l10n.liveStepInTitle(nickname),
    body: l10n.liveStepInBody(nickname),
    confirmLabel: l10n.liveStepInConfirm,
  );
}

/// The OS refused the microphone. True when the parent wants the phone's
/// settings.
Future<bool> showMicDeniedSheet(
  BuildContext context, {
  required String nickname,
}) {
  final l10n = context.l10n;
  return showConfirmSheet(
    context,
    title: l10n.liveStepInTitle(nickname),
    body: l10n.liveMicDenied,
    confirmLabel: l10n.commonOpenSettings,
  );
}

/// The end of the session, for the child and for Aule. True when confirmed.
Future<bool> showEndSheet(BuildContext context, {required String nickname}) {
  final l10n = context.l10n;
  return showConfirmSheet(
    context,
    title: l10n.liveEndTitle(nickname),
    body: l10n.liveEndBody(nickname),
    confirmLabel: l10n.liveEndConfirm,
    cancelLabel: l10n.liveEndKeep,
    danger: true,
  );
}
