import 'package:material_ui/material_ui.dart';

/// A serif section title, read as a heading by screen readers.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
