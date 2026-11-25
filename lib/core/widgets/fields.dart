import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/aule_colors.dart';
import '../theme/aule_text.dart';

/// A one-line field as on the web: a 2 px ink underline, copper on focus,
/// danger with the error text below it.
class LineField extends StatelessWidget {
  const LineField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.help,
    this.error,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLength,
    this.inputFormatters,
    this.autofillHints,
    this.autofocus = false,
    this.enabled = true,
    this.trailing,
    this.private = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? help;
  final String? error;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final bool enabled;
  final Widget? trailing;

  /// For what is typed about a child: no autocorrect, no suggestions, and
  /// the keyboard is asked not to learn the words (Gboard and the iOS
  /// keyboard can keep and sync them otherwise).
  final bool private;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall!;
    final fieldLabel = label;
    UnderlineInputBorder underline(Color color) => UnderlineInputBorder(
      borderSide: BorderSide(color: color, width: 2),
      borderRadius: BorderRadius.zero,
    );
    final field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      autocorrect: autocorrect && !private,
      enableSuggestions: enableSuggestions && !private,
      enableIMEPersonalizedLearning: !private,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      autofocus: autofocus,
      enabled: enabled,
      maxLines: 1,
      style: AuleText.field.copyWith(
        color: enabled ? AuleColors.ink : AuleColors.muted,
      ),
      cursorColor: AuleColors.ink,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AuleText.field.copyWith(color: AuleColors.muted),
        helperText: help,
        helperMaxLines: 4,
        helperStyle: small,
        errorText: error,
        errorMaxLines: 4,
        errorStyle: small.copyWith(color: AuleColors.danger),
        counterText: '',
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        suffixIcon: trailing,
        border: underline(AuleColors.ink),
        enabledBorder: underline(AuleColors.ink),
        focusedBorder: underline(AuleColors.copper),
        errorBorder: underline(AuleColors.danger),
        focusedErrorBorder: underline(AuleColors.danger),
        disabledBorder: underline(AuleColors.line),
      ),
    );
    if (fieldLabel == null) return field;
    // Merged, the label above becomes the field's own name for screen readers.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(fieldLabel, style: theme.textTheme.labelSmall),
          const SizedBox(height: AuleSpace.xs),
          field,
        ],
      ),
    );
  }
}

/// Gives [child] a name that only screen readers hear, for fields whose
/// visible title already says what they are (such as the email screen).
class ScreenReaderLabel extends StatelessWidget {
  const ScreenReaderLabel({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(label: label, child: const SizedBox(height: 1)),
          child,
        ],
      ),
    );
  }
}

/// Replaces line breaks with spaces, for one-line notes.
class OneLineFormatter extends TextInputFormatter {
  const OneLineFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.text.contains(RegExp(r'[\r\n]'))) return newValue;
    final text = newValue.text.replaceAll(RegExp(r'[\r\n]+'), ' ');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
