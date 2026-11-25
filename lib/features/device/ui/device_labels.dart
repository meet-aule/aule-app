import 'package:aule/core/api/models/models.dart';
import 'package:aule/core/l10n/dates.dart';
import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/router/routes.dart';
import 'package:aule/core/theme/aule_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/device_models.dart';
import '../provisioning/wifi_provisioner.dart';

/// The family's child with [id], if it is still in the family.
ChildRef? childById(String? id, List<ChildRef> children) {
  if (id == null) return null;
  for (final child in children) {
    if (child.id == id) return child;
  }
  return null;
}

/// "Aule de Mati", or "Aule sin asignar" when nobody in the family uses it.
String deviceNameOf(
  BuildContext context,
  Device device,
  List<ChildRef> children,
) {
  final child = childById(device.childId, children);
  return child == null
      ? context.l10n.deviceNameUnassigned
      : context.l10n.deviceNameFor(child.nickname);
}

/// The day and time the device was last online, or null when it never was.
/// [inline] is for use after a colon: "Última conexión: hoy · 16:40".
String? lastSeenWhen(
  BuildContext context,
  Device device, {
  bool inline = false,
}) {
  final at = device.lastSeenAt;
  if (at == null) return null;
  final local = at.toLocal();
  final day = dayLabel(context, local, inline: inline);
  return '$day · ${timeLabel(context, local)}';
}

/// "Aule 3F2A" for a device advertising "Aule-3F2A", else "Un Aule cerca de
/// ti" (today's firmware gives every unit the same name).
String foundDeviceName(BuildContext context, FoundDevice device) {
  final code = device.code;
  return code == null || code.isEmpty
      ? context.l10n.setupDeviceUnnamed
      : context.l10n.setupDeviceName(code);
}

/// Leaves a device route: back to where it was opened, so the family
/// screen's list refreshes, or to the family tab after a deep link.
void closeDeviceRoute(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.family);
  }
}

/// A small muted label over a value or a group of options.
class DeviceFieldLabel extends StatelessWidget {
  const DeviceFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelSmall);
}

/// A label and its value, read only.
class DeviceInfoRow extends StatelessWidget {
  const DeviceInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeviceFieldLabel(label),
          const SizedBox(height: AuleSpace.xs),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
