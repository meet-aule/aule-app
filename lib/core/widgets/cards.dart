import 'package:material_ui/material_ui.dart';

import '../theme/aule_colors.dart';

/// A surface card with a 1 px line border. An accent card adds a 3 px copper
/// left edge, for what needs the parent's attention.
class AuleCard extends StatelessWidget {
  const AuleCard({
    super.key,
    required this.child,
    this.onTap,
    this.accent = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool accent; // copper left edge

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    Widget content = Padding(
      padding: const EdgeInsets.all(AuleSpace.l),
      child: Row(
        children: <Widget>[
          Expanded(child: child),
          if (tap != null) ...<Widget>[
            const SizedBox(width: AuleSpace.s),
            const ExcludeSemantics(
              child: Icon(Icons.chevron_right, color: AuleColors.muted),
            ),
          ],
        ],
      ),
    );
    if (accent) {
      content = DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AuleColors.copper, width: 3)),
        ),
        child: content,
      );
    }
    return Material(
      color: AuleColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(auleRadius),
        side: const BorderSide(color: AuleColors.line, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: tap == null
          ? content
          : InkWell(
              onTap: tap,
              child: MergeSemantics(
                child: Semantics(button: true, child: content),
              ),
            ),
    );
  }
}
