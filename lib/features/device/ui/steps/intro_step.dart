import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/theme/aule_colors.dart';
import 'package:aule/core/widgets/buttons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../device_setup_controller.dart';
import 'setup_page.dart';

/// intro: what the parent needs, then Bluetooth or the code (§4.8). With
/// `bleWifi` off, only linking with a code is offered.
class IntroStep extends StatelessWidget {
  const IntroStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    if (!setup.bleWifi) {
      return SetupPage(
        title: l10n.setupTitle,
        help: l10n.setupBleSoon,
        footer: [
          PrimaryButton(
            label: l10n.setupLinkWithCode,
            onPressed: setup.skipToCode,
          ),
        ],
      );
    }
    return SetupPage(
      title: l10n.setupTitle,
      help: l10n.setupHelp,
      footer: [
        PrimaryButton(
          label: l10n.setupStart,
          busy: setup.busy,
          onPressed: setup.start,
        ),
        LinkButton(label: l10n.setupHasWifi, onPressed: setup.skipToCode),
      ],
      children: [_Need(l10n.setupNeedWifi), _Need(l10n.setupNeedPower)],
    );
  }
}

/// One item of the "what you need" list.
class _Need extends StatelessWidget {
  const _Need(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Text('•', style: style)),
        const SizedBox(width: AuleSpace.s),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
