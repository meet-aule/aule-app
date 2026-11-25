import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/aule_colors.dart';

/// A thin strip over every screen in demo mode: nothing leaves this phone.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: AuleColors.picked,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuleSpace.l,
                vertical: AuleSpace.xs,
              ),
              child: Text(
                context.l10n.demoBanner,
                textAlign: TextAlign.center,
                style: small.copyWith(color: AuleColors.ink),
              ),
            ),
          ),
        ),
        Expanded(
          // The strip already covers the status bar.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
