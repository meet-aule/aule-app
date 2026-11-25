import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/aule_colors.dart';
import '../theme/aule_text.dart';

/// One hidden text field over [length] boxes. Paste fills every box;
/// characters outside [allowed] are dropped.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    super.key,
    required this.length,
    required this.onChanged,
    this.onCompleted,
    this.allowed,
    this.uppercase = false,
    this.hasError = false,
    this.keyboardType = TextInputType.text,
    this.autofillHints,
    this.semanticLabel,
    this.autofocus = true,
    this.groupOf,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final RegExp? allowed; // matches one character
  final bool uppercase;
  final bool hasError;
  final TextInputType keyboardType;
  final Iterable<String>? autofillHints;
  final String? semanticLabel;
  final bool autofocus;
  final int? groupOf; // 3 draws 3 + 3 with a gap

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
    _controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    _focus.removeListener(_rebuild);
    _controller.removeListener(_rebuild);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _changed(String value) {
    widget.onChanged(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final focusedIndex = _focus.hasFocus
        ? (text.length < widget.length ? text.length : widget.length - 1)
        : -1;
    final boxes = <Widget>[];
    final group = widget.groupOf;
    for (var i = 0; i < widget.length; i++) {
      if (i > 0) {
        final groupGap = group != null && group > 0 && i % group == 0;
        boxes.add(SizedBox(width: groupGap ? AuleSpace.xl : AuleSpace.s));
      }
      boxes.add(
        Expanded(
          child: _CodeBox(
            character: i < text.length ? text[i] : '',
            focused: i == focusedIndex,
            hasError: widget.hasError,
          ),
        ),
      );
    }
    return MergeSemantics(
      child: Stack(
        children: <Widget>[
          ExcludeSemantics(child: Row(children: boxes)),
          Positioned.fill(
            child: Opacity(
              // The field takes the taps, the keyboard, the paste menu and the
              // screen reader; the boxes above show what it holds.
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                keyboardType: widget.keyboardType,
                autofillHints: widget.autofillHints,
                autocorrect: false,
                enableSuggestions: false,
                showCursor: false,
                maxLines: 1,
                textCapitalization: widget.uppercase
                    ? TextCapitalization.characters
                    : TextCapitalization.none,
                inputFormatters: <TextInputFormatter>[
                  CodeFormatter(
                    length: widget.length,
                    allowed: widget.allowed,
                    uppercase: widget.uppercase,
                  ),
                ],
                onChanged: _changed,
                style: const TextStyle(color: Color(0x00000000), fontSize: 1),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  // Read by screen readers only: the field itself is hidden.
                  labelText: widget.semanticLabel,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.character,
    required this.focused,
    required this.hasError,
  });

  final String character;
  final bool focused;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final color = hasError
        ? AuleColors.danger
        : (focused ? AuleColors.copper : AuleColors.ink);
    // 60 px at normal text size, growing with the phone's text scale so a
    // large character is never clipped. The character is centred without
    // stretching the box to the height it is given.
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: AuleSpace.s),
      decoration: BoxDecoration(
        color: AuleColors.surface,
        border: Border.all(color: color, width: focused ? 2.5 : 1.5),
        borderRadius: BorderRadius.circular(auleRadius),
      ),
      child: Center(
        heightFactor: 1,
        child: Text(character, style: AuleText.code),
      ),
    );
  }
}

/// Keeps only allowed characters, upper-cases them when asked, and stops at
/// the code's length. A pasted "123 456" or "k7q-m2x" fills every box.
class CodeFormatter extends TextInputFormatter {
  const CodeFormatter({
    required this.length,
    this.allowed,
    this.uppercase = false,
  });

  final int length;
  final RegExp? allowed;
  final bool uppercase;

  /// The code that [input] gives, without the editing state.
  String clean(String input) {
    final source = uppercase ? input.toUpperCase() : input;
    final buffer = StringBuffer();
    var count = 0;
    for (final rune in source.runes) {
      if (count >= length) break;
      final character = String.fromCharCode(rune);
      final pattern = allowed;
      if (pattern != null && !pattern.hasMatch(character)) continue;
      buffer.write(character);
      count++;
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = clean(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
