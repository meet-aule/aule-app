import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/aule_colors.dart';
import 'buttons.dart';

/// A bottom sheet with a title, a body and two buttons. True when confirmed.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel, // default: commonCancel
  bool danger = false,
}) async {
  final cancel = cancelLabel ?? context.l10n.commonCancel;
  final confirmed = await showAuleSheet<bool>(
    context,
    builder: (context) => SheetBody(
      title: title,
      children: <Widget>[
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
      ],
      actions: <Widget>[
        PrimaryButton(
          label: confirmLabel,
          danger: danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        Center(
          child: LinkButton(
            label: cancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Shows [builder] as a bottom sheet on the root navigator, over the tabs.
Future<T?> showAuleSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AuleColors.paper,
    builder: builder,
  );
}

/// The layout every sheet uses: a serif title, the content, and the actions
/// at the bottom, 12 px apart.
class SheetBody extends StatelessWidget {
  const SheetBody({
    super.key,
    required this.title,
    this.children = const <Widget>[],
    this.actions = const <Widget>[],
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = width < 360 ? AuleSpace.l : AuleSpace.xl;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(side, AuleSpace.xl, side, AuleSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final child in children) ...<Widget>[
              const SizedBox(height: AuleSpace.l),
              child,
            ],
            if (actions.isNotEmpty) const SizedBox(height: AuleSpace.xl),
            for (var i = 0; i < actions.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: AuleSpace.m),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}
