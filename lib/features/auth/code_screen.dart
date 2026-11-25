import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/code_boxes.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/snack.dart';

/// /sign-in/code: the six digits that were emailed.
class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});

  static const codeLength = 6;

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  String _code = '';
  String? _error;
  bool _busy = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Reached without an address (an old link): start over.
      if (mounted && context.read<AuthController>().pendingEmail == null) {
        context.go(Routes.signInEmail);
      }
    });
  }

  Future<void> _continue() async {
    final l10n = context.l10n;
    if (_code.length < CodeScreen.codeLength) {
      setState(() => _error = l10n.codeIncomplete);
      return;
    }
    if (_busy) return;
    final auth = context.read<AuthController>();
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await auth.verifyCode(_code);
      if (!mounted) return;
      setState(() => _busy = false);
      // Signed in: the router moves on by itself (§3.2).
      if (outcome == SignInOutcome.needsName) router.push(Routes.signInName);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (error.kind) {
          ApiErrorKind.forbidden => l10n.codeWrong,
          ApiErrorKind.network ||
          ApiErrorKind.unavailable => l10n.codeCheckFailed,
          _ => errorText(context, error),
        };
      });
    } on StateError {
      if (mounted) context.go(Routes.signInEmail);
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthController>();
    final email = auth.pendingEmail;
    if (email == null || _resending) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _resending = true);
    try {
      await auth.startEmailSignIn(email);
      showNoticeOn(messenger, l10n.codeResent);
    } on ApiException {
      showNoticeOn(messenger, l10n.codeSendFailed);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final email = context.watch<AuthController>().pendingEmail ?? '';
    final demo = context.read<AppConfig>().demo;
    final complete = _code.length == CodeScreen.codeLength;
    final error = _error;
    return AulePage(
      title: l10n.codeTitle,
      help: l10n.codeHelp(email),
      children: <Widget>[
        CodeBoxes(
          length: CodeScreen.codeLength,
          allowed: RegExp('[0-9]'),
          keyboardType: TextInputType.number,
          autofillHints: const <String>[AutofillHints.oneTimeCode],
          semanticLabel: l10n.codeLabel,
          hasError: error != null,
          onChanged: (value) => setState(() {
            _code = value;
            _error = null;
          }),
        ),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: theme.textTheme.bodySmall!.copyWith(
                color: AuleColors.danger,
              ),
            ),
          ),
        if (demo) Text(l10n.codeDemoHint, style: theme.textTheme.bodySmall),
        Wrap(
          spacing: AuleSpace.l,
          runSpacing: AuleSpace.xs,
          children: <Widget>[
            LinkButton(
              label: l10n.codeResend,
              onPressed: _resending || _busy ? null : _resend,
            ),
            LinkButton(
              label: l10n.codeMissing,
              onPressed: () => context.push(Routes.signInHelp),
            ),
          ],
        ),
      ],
      footer: <Widget>[
        // Disabled below six digits; a tap on it then says why.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: complete || _busy ? null : _continue,
          child: PrimaryButton(
            label: l10n.commonContinue,
            busy: _busy,
            onPressed: complete ? _continue : null,
          ),
        ),
      ],
    );
  }
}
