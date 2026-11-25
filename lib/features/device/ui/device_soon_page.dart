import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/widgets/aule_page.dart';
import 'package:aule/core/widgets/buttons.dart';
import 'package:material_ui/material_ui.dart';

import 'device_labels.dart';

/// What a device route shows while linking is not available yet (flag
/// `deviceLink` off), when it is reached by a stale link.
class DeviceSoonPage extends StatelessWidget {
  const DeviceSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AulePage(
      title: l10n.setupTitle,
      help: l10n.deviceComingSoon,
      onBack: () => closeDeviceRoute(context),
      footer: [
        PrimaryButton(
          label: l10n.commonBack,
          onPressed: () => closeDeviceRoute(context),
        ),
      ],
    );
  }
}
