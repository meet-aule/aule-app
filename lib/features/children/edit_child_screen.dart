import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/snack.dart';
import '../../core/widgets/states.dart';
import 'child_form.dart';
import 'children_store.dart';

/// /family/child/:childId: a child's settings. The PUT always sends the
/// whole record, starting from what the server has.
class EditChildScreen extends StatefulWidget {
  const EditChildScreen({super.key, required this.childId});

  final String childId;

  @override
  State<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends State<EditChildScreen> {
  ChildFormValues? _values;
  String _nickname = '';
  Object? _loadError;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ref = context.read<AuthController>().children.where(
      (child) => child.id == widget.childId,
    );
    if (ref.isNotEmpty) _nickname = ref.first.nickname;
    _load();
  }

  @override
  void dispose() {
    _values?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = context.read<ChildrenStore>();
    final navigator = Navigator.of(context);
    if (_loadError != null) setState(() => _loadError = null);
    try {
      // Always fresh: the whole record goes back on save.
      final detail = await store.load(widget.childId, force: true);
      if (!mounted) return;
      setState(() {
        _nickname = detail.child.nickname;
        _values?.dispose();
        _values = ChildFormValues(ChildDraft.fromDetail(detail));
      });
    } on Exception catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.kind == ApiErrorKind.notFound) {
        // Gone: the store refreshes `me`; this screen leaves.
        navigator.maybePop();
        return;
      }
      setState(() => _loadError = error);
    }
  }

  Future<void> _save() async {
    final values = _values;
    if (values == null || _busy) return;
    final l10n = context.l10n;
    values.clearErrors();
    final draft = values.toDraft();
    final problem = draft.validate();
    if (problem != null) {
      final shown = values.showProblem(problem, l10n);
      setState(() => _error = shown ? null : l10n.editSaveFailed);
      return;
    }
    final store = context.read<ChildrenStore>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.update(widget.childId, draft);
      showNoticeOn(messenger, l10n.commonSaved);
      if (mounted) navigator.maybePop();
    } on Exception {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.editSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final subjects = context.select<AuthController, List<String>>(
      (auth) => auth.me?.subjects ?? const <String>[],
    );
    final values = _values;
    final loadError = _loadError;
    final error = _error;
    return AulePage(
      title: l10n.editTitle(_nickname),
      children: <Widget>[
        if (values == null)
          loadError == null
              ? const LoadingView()
              : ErrorView(error: loadError, onRetry: _load)
        else ...<Widget>[
          ChildForm(
            values: values,
            full: true,
            subjectCodes: subjects,
            enabled: !_busy,
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LinkButton(
              label: l10n.editPrivacyLink(_nickname),
              onPressed: () => context.go(Routes.childPrivacy(widget.childId)),
            ),
          ),
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
      ],
      footer: <Widget>[
        if (values != null)
          PrimaryButton(
            label: _busy ? l10n.commonSaving : l10n.commonSave,
            busy: _busy,
            onPressed: _save,
          ),
      ],
    );
  }
}
