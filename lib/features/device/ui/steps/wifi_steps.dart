import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/widgets/buttons.dart';
import 'package:aule/core/widgets/fields.dart';
import 'package:aule/core/widgets/states.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../device_setup_controller.dart';
import 'setup_page.dart';

/// networks: what the device sees, strongest first, plus a field for a
/// network that is not listed (§4.8).
class NetworksStep extends StatelessWidget {
  const NetworksStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    if (setup.networksLoading) {
      return SetupPage(
        title: l10n.setupWifiTitle,
        help: l10n.setupWifiHelp,
        children: const [LoadingView()],
      );
    }
    final typing = setup.otherNetwork;
    return SetupPage(
      title: l10n.setupWifiTitle,
      help: l10n.setupWifiHelp,
      footer: [
        if (typing)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: setup.ssidField,
            builder: (context, value, _) => PrimaryButton(
              label: l10n.commonContinue,
              onPressed: value.text.isEmpty ? null : setup.submitOtherNetwork,
            ),
          ),
      ],
      children: [
        if (setup.networks.isEmpty) StepText(l10n.setupWifiNone),
        for (final network in setup.networks)
          OptionButton(
            label: network.ssid,
            onPressed: () => setup.chooseNetwork(network.ssid),
          ),
        if (!typing)
          OptionButton(
            label: l10n.setupWifiOther,
            onPressed: setup.showOtherNetwork,
          ),
        if (typing)
          LineField(
            controller: setup.ssidField,
            label: l10n.setupSsidLabel,
            error: setup.ssidProblem == SsidProblem.tooLong
                ? l10n.setupSsidTooLong
                : null,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => setup.submitOtherNetwork(),
          ),
        LinkButton(
          label: l10n.setupWifiRefresh,
          onPressed: setup.refreshNetworks,
        ),
      ],
    );
  }
}

/// password: typed for the chosen network, sent once, never kept.
class PasswordStep extends StatelessWidget {
  const PasswordStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    final error = switch (setup.passwordProblem) {
      PasswordProblem.tooLong => l10n.setupPasswordTooLong,
      PasswordProblem.tooShort => l10n.setupPasswordTooShort,
      null => null,
    };
    return SetupPage(
      title: l10n.setupPasswordTitle(setup.ssid),
      footer: [
        PrimaryButton(label: l10n.setupConnect, onPressed: setup.connectWifi),
      ],
      children: [
        LineField(
          controller: setup.passwordField,
          label: l10n.setupPasswordLabel,
          help: l10n.setupPasswordHelp,
          error: error,
          obscureText: !setup.showPassword,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => setup.connectWifi(),
          autofocus: true,
          trailing: LinkButton(
            label: setup.showPassword
                ? l10n.setupPasswordHide
                : l10n.setupPasswordShow,
            onPressed: setup.toggleShowPassword,
          ),
        ),
      ],
    );
  }
}

/// joining: the device tries the network (it answers within 25 s).
class JoiningStep extends StatelessWidget {
  const JoiningStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    return SetupPage(
      title: l10n.setupJoiningTitle(setup.ssid),
      help: l10n.setupJoiningHelp,
      showBack: false,
      children: const [LoadingView()],
    );
  }
}

/// wifiFailed: a wrong password and an unreachable network look the same.
class WifiFailedStep extends StatelessWidget {
  const WifiFailedStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    return SetupPage(
      title: l10n.setupWifiFailedTitle(setup.ssid),
      help: l10n.setupWifiFailedHelp,
      footer: [
        PrimaryButton(label: l10n.setupTryAgain, onPressed: setup.tryAgain),
        LinkButton(
          label: l10n.setupOtherNetwork,
          onPressed: setup.chooseAnotherNetwork,
        ),
      ],
    );
  }
}

/// wifiDone: on to the code. "Probably" when the link dropped right after
/// connecting, with no report (§8.4 a).
class WifiDoneStep extends StatelessWidget {
  const WifiDoneStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    return SetupPage(
      title: setup.probably
          ? l10n.setupWifiProbablyTitle
          : l10n.setupWifiDoneTitle,
      help: setup.probably
          ? l10n.setupWifiProbablyHelp
          : l10n.setupWifiDoneHelp,
      footer: [
        PrimaryButton(
          label: l10n.commonContinue,
          onPressed: setup.continueToCode,
        ),
      ],
    );
  }
}
