import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/aule_colors.dart';
import '../theme/aule_text.dart';

/// Every screen's frame, as on the web: a header row with the wordmark or
/// "← Atrás", an optional copper step line, the serif title, the help text,
/// a scrollable body and actions pinned at the bottom. Content is centred
/// and at most 560 px wide.
class AulePage extends StatelessWidget {
  const AulePage({
    super.key,
    required this.title,
    this.step,
    this.help,
    this.children = const <Widget>[],
    this.footer = const <Widget>[],
    this.showBack = true,
    this.onBack,
    this.onRefresh,
  });

  final String title; // serif page title
  final String? step; // copper line above the title
  final String? help; // muted text under the title
  final List<Widget> children; // the body, 16 px apart, scrollable
  final List<Widget> footer; // pinned actions at the bottom, 12 px apart
  final bool showBack; // "← Atrás" in the header row; else the wordmark
  final VoidCallback? onBack; // default: Navigator.maybePop
  final Future<void> Function()? onRefresh; // pull to refresh when set

  /// The side padding: 24 px, or 16 px under 360 px wide.
  static double sidePadding(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360 ? AuleSpace.l : AuleSpace.xl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final side = sidePadding(context);
    final stepText = step;
    final helpText = help;

    final body = <Widget>[
      if (stepText != null) ...<Widget>[
        Text(stepText, style: theme.textTheme.labelMedium),
        const SizedBox(height: AuleSpace.s),
      ],
      Semantics(
        header: true,
        child: Text(title, style: theme.textTheme.headlineMedium),
      ),
      if (helpText != null) ...<Widget>[
        const SizedBox(height: AuleSpace.s),
        Text(helpText, style: theme.textTheme.bodyMedium),
      ],
      for (final child in children) ...<Widget>[
        const SizedBox(height: AuleSpace.l),
        child,
      ],
    ];

    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(side, AuleSpace.s, side, AuleSpace.xl),
      children: body,
    );
    final refresh = onRefresh;
    if (refresh != null) {
      list = RefreshIndicator(
        onRefresh: refresh,
        color: AuleColors.ink,
        backgroundColor: AuleColors.surface,
        child: list,
      );
    }

    return Scaffold(
      backgroundColor: AuleColors.paper,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            // The footer takes at most half the height and scrolls inside it,
            // so large text or a landscape phone with the keyboard open never
            // overflows; the list keeps the rest.
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      side - AuleSpace.xs,
                      AuleSpace.s,
                      side,
                      0,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: showBack
                          ? BackLink(onPressed: onBack)
                          : const _Wordmark(),
                    ),
                  ),
                  Expanded(child: list),
                  if (footer.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight.isFinite
                            ? constraints.maxHeight / 2
                            : double.infinity,
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          side,
                          AuleSpace.m,
                          side,
                          AuleSpace.l,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (var i = 0; i < footer.length; i++) ...<Widget>[
                              if (i > 0) const SizedBox(height: AuleSpace.m),
                              footer[i],
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The web's "← Atrás" link, 44 px tall.
class BackLink extends StatelessWidget {
  const BackLink({super.key, this.onPressed});

  /// Default: Navigator.maybePop.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.commonBack;
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => _back(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(auleRadius),
        onTap: () => _back(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuleSpace.xs,
              vertical: AuleSpace.s,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.arrow_back, size: 18, color: AuleColors.ink),
                const SizedBox(width: AuleSpace.s),
                Text(label, style: AuleText.sans(15, 22, 500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _back(BuildContext context) {
    final press = onPressed;
    if (press != null) {
      press();
    } else {
      Navigator.maybePop(context);
    }
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuleSpace.xs,
        vertical: AuleSpace.s + 2,
      ),
      child: Text(context.l10n.appTitle, style: AuleText.wordmark),
    );
  }
}
