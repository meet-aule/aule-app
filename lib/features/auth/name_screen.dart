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

/// /sign-in/name: the first sign-in with an address creates the account.
class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  static const maxNameChars = 120;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty || name.runes.length > NameScreen.maxNameChars) {
      setState(() => _error = l10n.nameMissing);
      return;
    }
    final auth = context.read<AuthController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Signed in: the router moves on by itself (§3.2).
      await auth.completeWithName(name);
      if (mounted) setState(() => _busy = false);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (error.kind) {
          ApiErrorKind.badRequest => l10n.nameMissing,
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AulePage(
      title: l10n.nameTitle,
      help: l10n.nameHelp,
      children: <Widget>[
        LineField(
          controller: _name,
          label: l10n.nameLabel,
          hint: l10n.nameHint,
          error: _error,
          maxLength: NameScreen.maxNameChars,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _create(),
          autofillHints: const <String>[AutofillHints.name],
          autofocus: true,
          enabled: !_busy,
        ),
      ],
      footer: <Widget>[
        PrimaryButton(label: l10n.nameCreate, busy: _busy, onPressed: _create),
      ],
    );
  }
}
