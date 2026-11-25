import 'dart:async';

import 'package:aule/core/api/models/models.dart';
import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/core/config/app_config.dart';
import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/router/routes.dart';
import 'package:aule/core/theme/aule_colors.dart';
import 'package:aule/core/widgets/buttons.dart';
import 'package:aule/core/widgets/cards.dart';
import 'package:aule/core/widgets/section_title.dart';
import 'package:aule/core/widgets/states.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/device_api.dart';
import '../data/device_models.dart';
import 'device_labels.dart';

/// The family's devices, inside /family (§4.8).
class DevicesSection extends StatefulWidget {
  const DevicesSection({super.key});
  // Reads DeviceApi, AuthController and AppConfig from providers. It does
  // not scroll on its own: B1 places it inside the family screen's list.

  @override
  State<DevicesSection> createState() => _DevicesSectionState();
}

class _DevicesSectionState extends State<DevicesSection> {
  List<Device>? _devices;
  Object? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (context.read<AppConfig>().flags.deviceLink) unawaited(_load());
  }

  /// Fetches the list. Nothing here calls setState before the first await,
  /// so it is safe from initState.
  Future<void> _load() async {
    final request = ++_request;
    try {
      final devices = await context.read<DeviceApi>().devices();
      if (!mounted || request != _request) return;
      setState(() {
        _devices = devices;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = error);
    }
  }

  void _retry() {
    setState(() => _error = null);
    unawaited(_load());
  }

  Future<void> _open(Device device) async {
    await context.push<void>(Routes.device(device.id));
    if (mounted) unawaited(_load());
  }

  Future<void> _setUp() async {
    await context.push<void>(Routes.deviceSetup());
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final enabled = context.read<AppConfig>().flags.deviceLink;
    final children = context.watch<AuthController>().children;
    final devices = _devices;
    final error = _error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.deviceSectionTitle),
        const SizedBox(height: AuleSpace.m),
        if (!enabled)
          Text(l10n.deviceComingSoon, style: text.bodyMedium)
        else if (devices == null && error != null)
          ErrorView(error: error, onRetry: _retry)
        else if (devices == null)
          const LoadingView()
        else ...[
          if (devices.isEmpty) ...[
            Text(l10n.deviceNone, style: text.bodyMedium),
            const SizedBox(height: AuleSpace.l),
          ],
          for (final device in devices) ...[
            AuleCard(
              onTap: () => _open(device),
              child: _DeviceCardBody(device: device, children: children),
            ),
            const SizedBox(height: AuleSpace.m),
          ],
          SmallButton(label: l10n.deviceSetUp, onPressed: _setUp),
        ],
      ],
    );
  }
}

class _DeviceCardBody extends StatelessWidget {
  const _DeviceCardBody({required this.device, required this.children});

  final Device device;
  final List<ChildRef> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final when = lastSeenWhen(context, device, inline: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(deviceNameOf(context, device, children), style: text.titleMedium),
        const SizedBox(height: AuleSpace.xs),
        Text(
          when == null ? l10n.deviceNeverSeen : l10n.deviceLastSeen(when),
          style: text.bodySmall,
        ),
      ],
    );
  }
}
