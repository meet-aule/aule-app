import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/fields.dart';
import '../progress/progress_store.dart';

/// The check made on the phone before the server's own: trimmed, lower case.
bool confirmEmailMatches(String typed, String email) =>
    typed.trim().toLowerCase() == email.trim().toLowerCase();

/// /privacy/account/delete: deletes the whole family, after the parent
/// types the address they signed in with.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _email = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    final l10n = context.l10n;
    final auth = context.read<AuthController>();
    final email = auth.me?.guardian.email ?? '';
    final typed = _email.text;
    if (email.isEmpty || !confirmEmailMatches(typed, email)) {
      setState(() => _error = l10n.deleteAccountWrongEmail);
      return;
    }
    final sessionList = context.read<AppConfig>().flags.sessionList;
    final progress = context.read<ProgressStore>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (sessionList) {
        // A session going on now is ended first, read fresh (gap 6b). Best
        // effort: the page says it may take a few minutes to stop.
        await Future.wait(<Future<bool>>[
          for (final child in auth.children) progress.endLiveSessions(child.id),
        ]);
      }
      // On 204 the session is cleared and the router opens /sign-in,
      // which says the account was deleted.
      await auth.deleteAccount(typed.trim());
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.kind == ApiErrorKind.badRequest
            ? l10n.deleteAccountWrongEmail
            : errorText(context, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sessionList = context.read<AppConfig>().flags.sessionList;
    return AulePage(
      title: l10n.deleteAccountTitle,
      children: <Widget>[
        Text(l10n.deleteAccountBody, style: theme.textTheme.bodyLarge),
        Text(
          sessionList
              ? l10n.accountSessionCloseNote
              : l10n.accountSessionMayContinueNote,
          style: theme.textTheme.bodyMedium,
        ),
        LineField(
          controller: _email,
          label: l10n.deleteAccountLabel,
          error: _error,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const <String>[],
          maxLength: 254,
          enabled: !_busy,
        ),
      ],
      footer: <Widget>[
        PrimaryButton(
          label: l10n.deleteAccountConfirm,
          danger: true,
          busy: _busy,
          onPressed: _delete,
        ),
        Text(
          l10n.deleteAccountFinal,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
