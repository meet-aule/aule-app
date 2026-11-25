import 'package:aule/core/api/api_exception.dart';
import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/core/config/app_config.dart';
import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/widgets/aule_page.dart';
import 'package:aule/core/widgets/buttons.dart';
import 'package:aule/core/widgets/error_text.dart';
import 'package:aule/core/widgets/sheets.dart';
import 'package:aule/core/widgets/snack.dart';
import 'package:aule/core/widgets/states.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/device_api.dart';
import 'device_controller.dart';
import 'device_labels.dart';
import 'device_soon_page.dart';

/// /devices/:deviceId: who uses it, what it is, and unlinking it (§4.8).
class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    if (!context.read<AppConfig>().flags.deviceLink) {
      return const DeviceSoonPage();
    }
    return ChangeNotifierProvider<DeviceController>(
      create: (context) =>
          DeviceController(api: context.read<DeviceApi>(), deviceId: deviceId)
            ..load(),
      child: const _DeviceView(),
    );
  }
}

class _DeviceView extends StatelessWidget {
  const _DeviceView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = context.watch<DeviceController>();
    final children = context.watch<AuthController>().children;
    final device = controller.device;
    void back() => closeDeviceRoute(context);
    if (device == null) {
      final error = controller.error;
      return AulePage(
        title: l10n.deviceTitle,
        onBack: back,
        children: [
          if (controller.loading)
            const LoadingView()
          else if (error != null)
            ErrorView(error: error, onRetry: controller.retry)
          else
            EmptyView(text: l10n.errorNotFound),
        ],
      );
    }
    final user = childById(device.childId, children);
    final idle = !controller.busy;
    return AulePage(
      title: l10n.deviceTitle,
      onBack: back,
      footer: [
        LinkButton(
          label: l10n.deviceUnlink,
          danger: true,
          onPressed: idle ? () => _unlink(context) : null,
        ),
      ],
      children: [
        DeviceFieldLabel(l10n.deviceUsedByLabel),
        for (final child in children)
          OptionButton(
            label: child.nickname,
            selected: user?.id == child.id,
            onPressed: idle ? () => _assign(context, child.id) : null,
          ),
        OptionButton(
          label: l10n.deviceNobody,
          selected: user == null,
          onPressed: idle ? () => _assign(context, null) : null,
        ),
        DeviceInfoRow(label: l10n.deviceSerialLabel, value: device.serial),
        DeviceInfoRow(
          label: l10n.deviceVersionLabel,
          value: device.firmwareVersion ?? '—',
        ),
        DeviceInfoRow(
          label: l10n.deviceLastSeenLabel,
          value: lastSeenWhen(context, device) ?? l10n.deviceNeverSeen,
        ),
      ],
    );
  }

  Future<void> _assign(BuildContext context, String? childId) async {
    final controller = context.read<DeviceController>();
    final saved = context.l10n.commonSaved;
    try {
      await controller.assign(childId);
      if (context.mounted) showNotice(context, saved);
    } on Object catch (error) {
      if (context.mounted) _failed(context, error);
    }
  }

  Future<void> _unlink(BuildContext context) async {
    final l10n = context.l10n;
    final controller = context.read<DeviceController>();
    final confirmed = await showConfirmSheet(
      context,
      title: l10n.deviceUnlinkTitle,
      body: l10n.deviceUnlinkBody,
      confirmLabel: l10n.deviceUnlinkConfirm,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await controller.unlink();
      if (!context.mounted) return;
      showNotice(context, l10n.deviceUnlinked);
      closeDeviceRoute(context);
    } on Object catch (error) {
      if (context.mounted) _failed(context, error);
    }
  }

  /// A 404 means the device is no longer in the family: leave the screen.
  void _failed(BuildContext context, Object error) {
    showNotice(context, errorText(context, error));
    if (error is ApiException && error.kind == ApiErrorKind.notFound) {
      closeDeviceRoute(context);
    }
  }
}
