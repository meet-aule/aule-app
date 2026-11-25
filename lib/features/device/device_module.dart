import 'package:aule/core/api/fake/demo_data.dart';
import 'package:aule/core/app_deps.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'blufi/blufi_provisioner.dart';
import 'data/device_api.dart';
import 'data/fake_device_api.dart';
import 'data/http_device_api.dart';
import 'provisioning/ble_permissions.dart';
import 'provisioning/fake_wifi_provisioner.dart';
import 'provisioning/wifi_provisioner.dart';
import 'ui/device_screen.dart';
import 'ui/device_setup_screen.dart';

/// The device services, provided by `app.dart`. In demo mode only the fakes
/// are built: no radio, no OS prompt and no network.
List<SingleChildWidget> deviceProviders(AppDeps deps) {
  final demo = deps.config.demo;
  return [
    Provider<DeviceApi>.value(
      value: demo
          // The demo's devices belong to the family signed in now, so a new
          // demo family starts with none.
          ? FakeDeviceApi(
              familyOf: () => deps.auth.me?.familyId ?? DemoData.familyId,
            )
          : HttpDeviceApi(deps.transport!),
    ),
    Provider<WifiProvisioner>.value(
      value: demo ? FakeWifiProvisioner() : BlufiProvisioner(),
    ),
    Provider<BleAccess>.value(value: demo ? BleAccess.demo : BleAccess.phone),
  ];
}

List<RouteBase> deviceRoutes() => [
  // Listed before '/devices/:deviceId' so 'setup' is not read as an id.
  GoRoute(
    path: '/devices/setup',
    builder: (context, state) =>
        DeviceSetupScreen(childId: state.uri.queryParameters['child']),
  ),
  GoRoute(
    path: '/devices/:deviceId',
    builder: (context, state) =>
        DeviceScreen(deviceId: state.pathParameters['deviceId']!),
  ),
];
