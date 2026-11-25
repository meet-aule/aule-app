import 'package:material_ui/material_ui.dart';

import '../theme/aule_colors.dart';
import '../theme/aule_text.dart';

/// The main action of a screen: ink fill, surface text, full width.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed; // null disables
  final bool busy; // spinner in place of the label; not pressable
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final disabledLook = onPressed == null && !busy;
    final fill = disabledLook
        ? AuleColors.line
        : (danger ? AuleColors.danger : AuleColors.ink);
    final textColor = disabledLook ? AuleColors.muted : AuleColors.surface;
    final style = Theme.of(context).textTheme.labelLarge!
        .copyWith(color: textColor);
    return SizedBox(
      width: double.infinity,
      child: _Pressable(
        semanticLabel: label,
        onTap: enabled ? onPressed : null,
        fill: fill,
        minHeight: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: busy
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: textColor,
                ),
              )
            : Text(label, textAlign: TextAlign.center, style: style),
      ),
    );
  }
}

/// One choice among several: a 1.5 px ink border; picked fill and a check
/// when selected.
class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.subtitle,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final color = enabled ? AuleColors.ink : AuleColors.muted;
    final hint = subtitle;
    return SizedBox(
      width: double.infinity,
      child: _Pressable(
        semanticLabel: hint == null ? label : '$label. $hint',
        selected: selected,
        onTap: onPressed,
        fill: selected ? AuleColors.picked : AuleColors.surface,
        border: BorderSide(
          color: enabled ? AuleColors.ink : AuleColors.line,
          width: 1.5,
        ),
        minHeight: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.titleMedium!.copyWith(color: color),
                  ),
                  if (hint != null) ...<Widget>[
                    const SizedBox(height: 2),
                    // Muted on the picked fill would be 4.2:1; ink reads.
                    Text(
                      hint,
                      style: selected && enabled
                          ? theme.textTheme.bodySmall!.copyWith(
                              color: AuleColors.ink,
                            )
                          : theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: AuleSpace.m),
              const Icon(Icons.check, color: AuleColors.ink, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

/// A secondary action of its own size: a 1.5 px ink border, 44 px tall.
class SmallButton extends StatelessWidget {
  const SmallButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final style = AuleText.sans(
      15,
      20,
      600,
      color: enabled ? AuleColors.ink : AuleColors.muted,
    );
    return _Pressable(
      semanticLabel: label,
      onTap: onPressed,
      fill: AuleColors.surface,
      border: BorderSide(
        color: enabled ? AuleColors.ink : AuleColors.line,
        width: 1.5,
      ),
      minHeight: 44,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(label, textAlign: TextAlign.center, style: style),
    );
  }
}

/// An underlined text action with a 44 px target, in ink or danger.
class LinkButton extends StatelessWidget {
  const LinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? AuleColors.muted
        : (danger ? AuleColors.danger : AuleColors.ink);
    final style = AuleText.sans(
      15,
      22,
      500,
      color: color,
    ).copyWith(decoration: TextDecoration.underline, decorationColor: color);
    return _Pressable(
      semanticLabel: label,
      onTap: onPressed,
      fill: const Color(0x00000000),
      minHeight: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(label, style: style),
    );
  }
}

/// The shared press target: one semantics node with the label and the tap,
/// ink feedback, a 3 px copper focus ring and the app's radius.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.semanticLabel,
    required this.onTap,
    required this.fill,
    required this.minHeight,
    required this.padding,
    required this.child,
    this.border,
    this.selected,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final String semanticLabel;
  final VoidCallback? onTap;
  final Color fill;
  final BorderSide? border;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final bool? selected;
  final AlignmentGeometry alignment;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(auleRadius);
    final onTap = widget.onTap;
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      selected: widget.selected,
      label: widget.semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Container(
        foregroundDecoration: _focused
            ? BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: AuleColors.copper, width: 3),
              )
            : null,
        child: Material(
          color: widget.fill,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: widget.border ?? BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              child: Padding(
                padding: widget.padding,
                child: Align(
                  alignment: widget.alignment,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
