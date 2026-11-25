import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/aule_colors.dart';
import 'buttons.dart';
import 'error_text.dart';

/// Waiting for an answer. It sits inside a page's list, so it does not try
/// to fill the screen.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuleSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              semanticsLabel: text ?? context.l10n.commonLoading,
            ),
          ),
          if (text != null) ...<Widget>[
            const SizedBox(height: AuleSpace.m),
            ExcludeSemantics(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Something failed: the family-facing text and a retry.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuleSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              errorText(context, error),
              style: Theme.of(context).textTheme.bodyLarge!
                  .copyWith(color: AuleColors.danger),
            ),
          ),
          const SizedBox(height: AuleSpace.m),
          SmallButton(label: context.l10n.commonRetry, onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Nothing to show yet, with an optional action under the text.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final next = action;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuleSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
          if (next != null) ...<Widget>[
            const SizedBox(height: AuleSpace.l),
            next,
          ],
        ],
      ),
    );
  }
}
