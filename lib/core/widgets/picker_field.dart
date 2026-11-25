import 'package:material_ui/material_ui.dart';

import '../theme/aule_colors.dart';
import '../theme/aule_text.dart';
import 'buttons.dart';
import 'sheets.dart';

/// One choice of a [PickerField]. [value] may be null, for "I'd rather not
/// say".
class PickerOption<T> {
  const PickerOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// A labelled line that shows the current choice and opens a sheet of
/// option buttons.
class PickerField<T> extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<PickerOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null && options.isNotEmpty;
    final current = options.where((option) => option.value == value);
    final shown = current.isEmpty ? '' : current.first.label;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: AuleSpace.xs),
            InkWell(
              onTap: enabled ? () => _open(context) : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: enabled ? AuleColors.ink : AuleColors.line,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        shown,
                        style: AuleText.sans(
                          18,
                          26,
                          400,
                          color: enabled ? AuleColors.ink : AuleColors.muted,
                        ),
                      ),
                    ),
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: AuleColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final change = onChanged;
    if (change == null) return;
    final chosen = await showAuleSheet<PickerOption<T>>(
      context,
      builder: (sheetContext) => SheetBody(
        title: label,
        children: <Widget>[
          for (final option in options)
            OptionButton(
              label: option.label,
              selected: option.value == value,
              onPressed: () => Navigator.of(sheetContext).pop(option),
            ),
        ],
      ),
    );
    if (chosen != null) change(chosen.value);
  }
}
