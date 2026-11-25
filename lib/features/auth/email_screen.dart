import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/fields.dart';
import 'email_rules.dart';

/// /sign-in/email: the address the code goes to.
class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final TextEditingController _email = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final l10n = context.l10n;
    final address = _email.text.trim();
    if (!isValidEmail(address)) {
      setState(() => _error = l10n.emailInvalid);
      return;
    }
    final auth = context.read<AuthController>();
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.startEmailSignIn(address);
      if (!mounted) return;
      setState(() => _busy = false);
      router.push(Routes.signInCode);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (error.kind) {
          ApiErrorKind.badRequest => l10n.emailInvalid,
          ApiErrorKind.unavailable ||
          ApiErrorKind.network => l10n.codeSendFailed,
          _ => errorText(context, error),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AulePage(
      title: l10n.emailTitle,
      help: l10n.emailHelp,
      children: <Widget>[
        ScreenReaderLabel(
          label: l10n.emailLabel,
          child: LineField(
            controller: _email,
            hint: l10n.emailHint,
            error: _error,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 254,
            autofillHints: const <String>[AutofillHints.email],
            autofocus: true,
            enabled: !_busy,
          ),
        ),
      ],
      footer: <Widget>[
        PrimaryButton(label: l10n.emailSend, busy: _busy, onPressed: _send),
      ],
    );
  }
}
