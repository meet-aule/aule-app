import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/widgets/buttons.dart';
import 'package:aule/core/widgets/states.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../provisioning/ble_permissions.dart';
import '../device_labels.dart';
import '../device_setup_controller.dart';
import 'setup_page.dart';

/// permissions: why Bluetooth is needed before the OS asks, then what is
/// missing (§4.8). The OS reports a permission never asked for as denied,
/// so the explanation shows until the parent pressed "Permitir Bluetooth".
class PermissionsStep extends StatelessWidget {
  const PermissionsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    final allow = PrimaryButton(
      label: l10n.setupBtAllow,
      busy: setup.busy,
      onPressed: setup.allowBluetooth,
    );
    final retry = PrimaryButton(
      label: l10n.commonRetry,
      busy: setup.busy,
      onPressed: setup.checkAgain,
    );
    final settings = LinkButton(
      label: l10n.commonOpenSettings,
      onPressed: openAppSettings,
    );
    return switch (setup.readiness) {
      BleReadiness.denied when setup.bluetoothAsked => SetupPage(
        title: l10n.setupBtTitle,
        help: l10n.setupBtDenied,
        footer: [allow, settings],
      ),
      BleReadiness.permanentlyDenied => SetupPage(
        title: l10n.setupBtTitle,
        help: l10n.setupBtDenied,
        footer: [
          PrimaryButton(
            label: l10n.commonOpenSettings,
            onPressed: openAppSettings,
          ),
          LinkButton(label: l10n.commonRetry, onPressed: setup.checkAgain),
        ],
      ),
      BleReadiness.bluetoothOff => SetupPage(
        title: l10n.setupBtTitle,
        help: l10n.setupBtOff,
        footer: [retry],
      ),
      BleReadiness.locationOff => SetupPage(
        title: l10n.setupBtTitle,
        help: l10n.setupLocationOff,
        footer: [retry, settings],
      ),
      BleReadiness.unsupported => SetupPage(
        title: l10n.setupBtTitle,
        help: l10n.setupBtUnsupported,
        footer: [
          PrimaryButton(
            label: l10n.setupLinkWithCode,
            onPressed: setup.skipToCode,
          ),
        ],
      ),
      BleReadiness.denied || BleReadiness.ready || null => SetupPage(
        title: l10n.setupBtTitle,
        help: setup.asksForLocation
            ? l10n.setupBtHelpLocation
            : l10n.setupBtHelp,
        footer: [allow],
      ),
    };
  }
}

/// scanning: until the first Aule shows up, or 20 s pass.
class ScanningStep extends StatelessWidget {
  const ScanningStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SetupPage(
      title: l10n.setupScanTitle,
      help: l10n.setupScanHelp,
      children: [
        const LoadingView(),
        StepText(l10n.setupScanHint, small: true),
      ],
    );
  }
}

/// pick: the devices found, which keep coming in while the scan runs.
class PickStep extends StatelessWidget {
  const PickStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    if (setup.found.isEmpty) {
      return SetupPage(
        title: l10n.setupNoneFound,
        help: l10n.setupNoneFoundHelp,
        footer: [
          PrimaryButton(label: l10n.setupScanAgain, onPressed: setup.scanAgain),
        ],
        children: [StepText(l10n.setupScanHint, small: true)],
      );
    }
    return SetupPage(
      title: l10n.setupPickTitle,
      children: [
        for (final device in setup.found)
          OptionButton(
            label: foundDeviceName(context, device),
            onPressed: () => setup.pick(device),
          ),
      ],
    );
  }
}

/// connecting: the BLE link and the secure handshake (up to 45 s).
class ConnectingStep extends StatelessWidget {
  const ConnectingStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    if (setup.connectFailed) {
      return SetupPage(
        title: l10n.setupTitle,
        help: l10n.setupConnectFailed,
        footer: [
          PrimaryButton(label: l10n.commonRetry, onPressed: setup.retryConnect),
        ],
      );
    }
    return SetupPage(
      title: l10n.setupConnecting,
      help: l10n.setupConnectingHelp,
      children: const [LoadingView()],
    );
  }
}
