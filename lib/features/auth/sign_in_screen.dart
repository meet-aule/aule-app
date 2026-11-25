import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/google_auth.dart';
import '../../core/l10n/l10n.dart';
import '../../core/links.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/snack.dart';

/// /sign-in: how to sign in. No password, ever.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _googleBusy = false;

  @override
  void initState() {
    super.initState();
    // A message left by sign-out, a 401 or account deletion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = context.l10n;
      switch (context.read<AuthController>().takeFlash()) {
        case AuthController.flashExpired:
          showNotice(context, l10n.errorSignedOut);
        case AuthController.flashAccountDeleted:
          showNotice(context, l10n.deleteAccountDone);
      }
    });
  }

  Future<void> _google() async {
    final auth = context.read<AuthController>();
    final failed = context.l10n.signInGoogleFailed;
    setState(() => _googleBusy = true);
    try {
      final outcome = await auth.signInWithGoogle();
      if (!mounted) return;
      if (outcome == SignInOutcome.needsName) {
        context.push(Routes.signInName);
      }
    } on SignInCanceled {
      // Cancelling shows nothing.
    } on Exception {
      if (mounted) showNotice(context, failed);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthController>();
    final theme = Theme.of(context);
    return AulePage(
      showBack: false,
      step: l10n.signInGreeting,
      title: l10n.signInTitle,
      help: l10n.signInHelp,
      children: <Widget>[
        // Built only on Android with the flag on (main.dart, §2.1).
        if (auth.canUseGoogle)
          OptionButton(
            label: l10n.signInWithGoogle,
            onPressed: _googleBusy ? null : _google,
          ),
        OptionButton(
          label: l10n.signInWithEmail,
          onPressed: _googleBusy
              ? null
              : () => context.push(Routes.signInEmail),
        ),
      ],
      footer: <Widget>[
        Text(l10n.signInPrivacyNote, style: theme.textTheme.bodySmall),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: LinkButton(
            label: l10n.commonPrivacyPolicy,
            onPressed: () => openPrivacyPolicy(context),
          ),
        ),
      ],
    );
  }
}
