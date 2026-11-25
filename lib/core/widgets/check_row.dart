import 'package:material_ui/material_ui.dart';

import '../theme/aule_colors.dart';

/// A checkbox and its text. The box is 24 px with a 1.5 px ink border and a
/// 6 px radius; ticked, it fills with ink and shows a surface check. Boxed,
/// the row sits in a bordered panel, as the required consent does.
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.boxed = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = onChanged;
    final enabled = change != null;
    final radius = BorderRadius.circular(auleRadius);
    final row = Padding(
      padding: EdgeInsets.all(boxed ? AuleSpace.l : AuleSpace.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _Box(ticked: value, enabled: enabled),
          ),
          const SizedBox(width: AuleSpace.m),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: enabled ? AuleColors.ink : AuleColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      checked: value,
      enabled: enabled,
      label: label,
      onTap: change == null ? null : () => change(!value),
      excludeSemantics: true,
      child: Material(
        color: boxed ? AuleColors.surface : const Color(0x00000000),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: boxed
              ? const BorderSide(color: AuleColors.ink, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: change == null ? null : () => change(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: row,
          ),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.ticked, required this.enabled});

  final bool ticked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final edge = enabled ? AuleColors.ink : AuleColors.line;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: ticked ? edge : AuleColors.surface,
        border: Border.all(color: edge, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ticked
          ? const Icon(Icons.check, size: 18, color: AuleColors.surface)
          : null,
    );
  }
}
