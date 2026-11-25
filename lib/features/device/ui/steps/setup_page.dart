import 'package:aule/core/theme/aule_colors.dart';
import 'package:aule/core/widgets/aule_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../device_labels.dart';
import '../device_setup_controller.dart';

/// One step of the setup flow: an [AulePage] whose "← Atrás" goes one step
/// back inside the flow before it leaves it.
class SetupPage extends StatelessWidget {
  const SetupPage({
    super.key,
    required this.title,
    this.step,
    this.help,
    this.children = const <Widget>[],
    this.footer = const <Widget>[],
    this.showBack = true,
  });

  final String title;
  final String? step;
  final String? help;
  final List<Widget> children;
  final List<Widget> footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return AulePage(
      title: title,
      step: step,
      help: help,
      showBack: showBack,
      onBack: () => setupBack(context),
      footer: footer,
      children: children,
    );
  }
}

/// "← Atrás" and Android back: one step back, or out of the flow.
void setupBack(BuildContext context) {
  if (context.read<DeviceSetupController>().back()) return;
  closeDeviceRoute(context);
}

/// Help or error text in the body of a step.
class StepText extends StatelessWidget {
  const StepText(
    this.text, {
    super.key,
    this.small = false,
    this.error = false,
  });

  final String text;
  final bool small;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final base = small ? theme.bodySmall : theme.bodyMedium;
    return Text(
      text,
      style: error ? base?.copyWith(color: AuleColors.danger) : base,
    );
  }
}
