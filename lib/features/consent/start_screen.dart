import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';

/// /start: the first run of a family with no children.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthController>();
    final name = auth.me?.guardian.name ?? '';
    return AulePage(
      showBack: false,
      step: name.isEmpty ? null : l10n.greeting(name),
      title: l10n.startTitle,
      help: l10n.startHelp,
      footer: <Widget>[
        PrimaryButton(
          label: l10n.startGo,
          onPressed: () => context.push(Routes.addChild),
        ),
        Center(
          child: LinkButton(
            label: l10n.startLater,
            onPressed: () {
              auth.dismissStart();
              context.go(Routes.progress);
            },
          ),
        ),
      ],
    );
  }
}
