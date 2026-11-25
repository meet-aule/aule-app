import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import 'children_store.dart';

/// /add-child/done?child=<id>: the child is in the family.
class AddChildDoneScreen extends StatefulWidget {
  const AddChildDoneScreen({super.key, required this.childId});

  final String childId;

  @override
  State<AddChildDoneScreen> createState() => _AddChildDoneScreenState();
}

class _AddChildDoneScreenState extends State<AddChildDoneScreen> {
  @override
  void initState() {
    super.initState();
    final known = context.read<AuthController>().children.any(
      (child) => child.id == widget.childId,
    );
    // `me` may have failed to refresh; the record still has the nickname.
    if (!known && widget.childId.isNotEmpty) {
      context.read<ChildrenStore>().load(widget.childId).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final flags = context.read<AppConfig>().flags;
    final auth = context.watch<AuthController>();
    final store = context.watch<ChildrenStore>();
    final ref = auth.children.where((child) => child.id == widget.childId);
    final nickname = ref.isNotEmpty
        ? ref.first.nickname
        : store.detail(widget.childId)?.child.nickname;
    return PopScope<Object?>(
      // The child is created: back goes home, not to the form.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(Routes.progress);
      },
      child: AulePage(
        showBack: false,
        step: nickname == null ? null : l10n.addDoneStep,
        title: nickname == null
            ? l10n.addDoneStep
            : l10n.addDoneTitle(nickname),
        help: l10n.addDoneHelp,
        footer: <Widget>[
          PrimaryButton(
            label: l10n.addDoneHome,
            onPressed: () => context.go(Routes.progress),
          ),
          if (flags.deviceLink && widget.childId.isNotEmpty)
            OptionButton(
              label: l10n.addDoneSetUpDevice,
              onPressed: () =>
                  context.push(Routes.deviceSetup(childId: widget.childId)),
            ),
        ],
      ),
    );
  }
}
