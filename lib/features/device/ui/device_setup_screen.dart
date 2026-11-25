import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/core/config/app_config.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/device_api.dart';
import '../provisioning/ble_permissions.dart';
import '../provisioning/wifi_provisioner.dart';
import 'device_labels.dart';
import 'device_setup_controller.dart';
import 'device_soon_page.dart';
import 'steps/bluetooth_steps.dart';
import 'steps/intro_step.dart';
import 'steps/link_steps.dart';
import 'steps/setup_page.dart';
import 'steps/wifi_steps.dart';

/// /devices/setup: one route whose controller steps through Wi-Fi over
/// Bluetooth and linking with a code (§4.8, §8.1).
class DeviceSetupScreen extends StatelessWidget {
  const DeviceSetupScreen({super.key, this.childId});

  /// The child to preselect, from `?child=`.
  final String? childId;

  @override
  Widget build(BuildContext context) {
    final flags = context.read<AppConfig>().flags;
    if (!flags.deviceLink) return const DeviceSoonPage();
    // In demo mode every Bluetooth answer is "ready": no OS prompt.
    final ble = context.read<BleAccess>();
    return ChangeNotifierProvider<DeviceSetupController>(
      create: (context) => DeviceSetupController(
        devices: context.read<DeviceApi>(),
        provisioner: context.read<WifiProvisioner>(),
        bleWifi: flags.bleWifi,
        checkBluetooth: ble.check,
        requestBluetooth: ble.request,
        asksForLocation: ble.asksForLocation,
        // Only a child of this family is preselected.
        childId: childById(
          childId,
          context.read<AuthController>().children,
        )?.id,
      ),
      child: const _SetupFlow(),
    );
  }
}

class _SetupFlow extends StatelessWidget {
  const _SetupFlow();

  @override
  Widget build(BuildContext context) {
    final step = context.select<DeviceSetupController, SetupStep>(
      (setup) => setup.step,
    );
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setupBack(context);
      },
      child: switch (step) {
        SetupStep.intro => const IntroStep(),
        SetupStep.permissions => const PermissionsStep(),
        SetupStep.scanning => const ScanningStep(),
        SetupStep.pick => const PickStep(),
        SetupStep.connecting => const ConnectingStep(),
        SetupStep.networks => const NetworksStep(),
        SetupStep.password => const PasswordStep(),
        SetupStep.joining => const JoiningStep(),
        SetupStep.wifiFailed => const WifiFailedStep(),
        SetupStep.wifiDone => const WifiDoneStep(),
        SetupStep.code => const CodeStep(),
        SetupStep.waiting => const WaitingStep(),
        SetupStep.linked => const LinkedStep(),
      },
    );
  }
}
