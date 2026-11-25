import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/l10n/l10n.dart';
import '../../core/links.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import 'email_rules.dart';

/// /sign-in/help: the email is not arriving.
class EmailHelpScreen extends StatelessWidget {
  const EmailHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final email = context.watch<AuthController>().pendingEmail;
    return AulePage(
      title: l10n.emailHelpTitle,
      help: l10n.emailHelpBody,
      children: <Widget>[
        if (email != null)
          Text(
            l10n.emailHelpSentTo(maskEmail(email)),
            style: theme.textTheme.bodyLarge,
          ),
        Text(l10n.emailHelpStillMissing, style: theme.textTheme.bodySmall),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: LinkButton(
            label: l10n.commonWriteUs,
            onPressed: () => openSupportMail(context),
          ),
        ),
      ],
      footer: <Widget>[
        PrimaryButton(
          label: l10n.emailHelpOtherEmail,
          // A fresh email screen, so its field starts empty.
          onPressed: () => context.go(Routes.signInEmail),
        ),
      ],
    );
  }
}
