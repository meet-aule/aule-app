import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/theme/aule_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_text.dart';

/// /loading: the wordmark while the session is restored. It is never shown
/// for longer than that call, except to offer a retry when it failed.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthController>();
    final error = auth.restoreError;
    return Scaffold(
      backgroundColor: AuleColors.paper,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AuleSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(l10n.appTitle, style: AuleText.serif(28, 34, 600)),
                const SizedBox(height: AuleSpace.xl),
                if (error == null)
                  SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      semanticsLabel: l10n.commonLoading,
                    ),
                  )
                else ...<Widget>[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      errorText(context, error),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: AuleSpace.l),
                  SmallButton(
                    label: l10n.commonRetry,
                    onPressed: () => auth.restore(),
                  ),
                  LinkButton(
                    label: l10n.resourcesTitle,
                    onPressed: () => context.push(Routes.resources),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
