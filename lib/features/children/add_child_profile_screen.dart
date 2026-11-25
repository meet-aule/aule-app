import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/snack.dart';
import '../consent/add_child_flow.dart';
import 'child_form.dart';

/// /add-child/profile, step 2 of 2. The router lets nobody here without a
/// consent draft in memory (§3.2).
class AddChildProfileScreen extends StatefulWidget {
  const AddChildProfileScreen({super.key});

  @override
  State<AddChildProfileScreen> createState() => _AddChildProfileScreenState();
}

class _AddChildProfileScreenState extends State<AddChildProfileScreen> {
  late final ChildFormValues _values;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The session language defaults to the UI language.
    final language = context.read<AuthController>().language;
    _values = ChildFormValues(ChildDraft(nickname: '', language: language));
  }

  @override
  void dispose() {
    _values.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final l10n = context.l10n;
    _values.clearErrors();
    final draft = _values.toDraft();
    final problem = draft.validate();
    if (problem != null) {
      final shown = _values.showProblem(problem, l10n);
      setState(() => _error = shown ? null : l10n.profileCreateFailed);
      return;
    }
    final flow = context.read<AddChildFlow>();
    // Captured now: the router may replace this screen while it waits.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await flow.create(draft);
      router.go(Routes.addChildDone(result.childId));
      if (!result.allChoicesSaved) {
        showNoticeOn(messenger, l10n.profileChoiceFailed);
      }
    } on ConsentNotRecorded catch (failure) {
      if (!mounted) return;
      final kept = flow.pendingChild;
      setState(() {
        _busy = false;
        // Kept: the profile exists without permission, and the screen says
        // so, with a way to delete it.
        _error = failure.childKept && kept != null
            ? l10n.profileConsentKept(kept.nickname)
            : l10n.profileConsentFailed;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.profileCreateFailed;
      });
    }
  }

  /// Deletes the profile a failed attempt left without consent.
  Future<void> _discard(ChildRef kept) async {
    if (_busy) return;
    final flow = context.read<AddChildFlow>();
    final messenger = ScaffoldMessenger.of(context);
    final deleted = context.l10n.profileKeptDeleted(kept.nickname);
    setState(() => _busy = true);
    try {
      await flow.discardPending();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = null;
      });
      showNoticeOn(messenger, deleted);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showNoticeOn(messenger, errorText(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final error = _error;
    // A profile an earlier attempt created but could not give consent to:
    // the form stays as it was sent, and Save records the consent for it.
    final kept = context.select<AddChildFlow, ChildRef?>(
      (flow) => flow.pendingChild,
    );
    return AulePage(
      step: l10n.profileStep,
      title: l10n.profileTitle,
      help: l10n.profileHelp,
      children: <Widget>[
        ChildForm(values: _values, enabled: !_busy && kept == null),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: AuleColors.danger,
              ),
            ),
          ),
      ],
      footer: <Widget>[
        PrimaryButton(
          label: _busy ? l10n.commonSaving : l10n.commonSave,
          busy: _busy,
          onPressed: _save,
        ),
        if (kept != null)
          Center(
            child: LinkButton(
              label: l10n.profileKeptDelete(kept.nickname),
              danger: true,
              onPressed: _busy ? null : () => _discard(kept),
            ),
          ),
      ],
    );
  }
}
