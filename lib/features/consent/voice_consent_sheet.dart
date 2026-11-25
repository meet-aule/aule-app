import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/links.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/check_row.dart';
import '../../core/widgets/sheets.dart';

/// Asks for voice consent again, with the same text as the consent screen
/// and the box unticked. True when the parent ticked it and agreed.
Future<bool> showVoiceConsentSheet(
  BuildContext context, {
  required String nickname,
}) async {
  final agreed = await showAuleSheet<bool>(
    context,
    builder: (context) => _VoiceConsentSheet(nickname: nickname),
  );
  return agreed ?? false;
}

class _VoiceConsentSheet extends StatefulWidget {
  const _VoiceConsentSheet({required this.nickname});

  final String nickname;

  @override
  State<_VoiceConsentSheet> createState() => _VoiceConsentSheetState();
}

class _VoiceConsentSheetState extends State<_VoiceConsentSheet> {
  bool _ticked = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SheetBody(
      title: l10n.grantVoiceTitle(widget.nickname),
      children: <Widget>[
        CheckRow(
          boxed: true,
          value: _ticked,
          onChanged: (value) => setState(() => _ticked = value),
          label: l10n.consentVoice,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: LinkButton(
            label: l10n.commonPrivacyPolicy,
            onPressed: () => openPrivacyPolicy(context),
          ),
        ),
      ],
      actions: <Widget>[
        PrimaryButton(
          label: l10n.consentAgree,
          onPressed: _ticked ? () => Navigator.of(context).pop(true) : null,
        ),
        Center(
          child: LinkButton(
            label: l10n.commonCancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
    );
  }
}
