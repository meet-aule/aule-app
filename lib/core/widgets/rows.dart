import 'package:material_ui/material_ui.dart';

import '../theme/aule_colors.dart';
import '../theme/aule_text.dart';

/// A small label on a picked background, for kinds and reasons.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.accent = false});

  final String text;

  /// For what needs the parent's attention: copper text and a copper edge on
  /// the surface color, which keeps the text at 5.1:1 (copper on the picked
  /// background would be 4.2:1, under WCAG AA for 13 px).
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: accent ? 2 : 3),
      decoration: BoxDecoration(
        color: accent ? AuleColors.surface : AuleColors.picked,
        border: accent ? Border.all(color: AuleColors.copper) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AuleText.sans(
          13,
          18,
          600,
          color: accent ? AuleColors.copper : AuleColors.ink,
        ),
      ),
    );
  }
}

/// Tags in a row that wraps.
class TagRow extends StatelessWidget {
  const TagRow(this.tags, {super.key});

  final List<Widget> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: AuleSpace.s, runSpacing: AuleSpace.s, children: tags);
  }
}

/// A switch with its label and help, as one control for screen readers.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.help,
  });

  final String label;
  final String? help;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = onChanged;
    final helpText = help;
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(auleRadius),
        onTap: change == null ? null : () => change(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AuleSpace.s),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(label, style: theme.textTheme.titleMedium),
                      if (helpText != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(helpText, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AuleSpace.m),
                Switch(value: value, onChanged: change),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A read-only line: a muted label over its value.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// A thin divider between rows.
class LineDivider extends StatelessWidget {
  const LineDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AuleColors.line);
}
