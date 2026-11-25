import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/widgets/buttons.dart';
import 'package:aule/core/widgets/code_boxes.dart';
import 'package:aule/core/widgets/error_text.dart';
import 'package:aule/core/widgets/snack.dart';
import 'package:aule/core/widgets/states.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/device_models.dart';
import '../device_labels.dart';
import '../device_setup_controller.dart';
import 'setup_page.dart';

/// code: the 6 characters the device shows, and who will use it (§4.8).
class CodeStep extends StatelessWidget {
  const CodeStep({super.key});

  /// The platform's alphabet; lower case is accepted and upper-cased.
  static final _allowed = RegExp('[A-HJ-NP-Z2-9]', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    final children = context.watch<AuthController>().children;
    final problem = switch (setup.claimProblem) {
      ClaimProblem.wrong => l10n.linkWrong,
      ClaimProblem.tooMany => l10n.linkTooMany,
      ClaimProblem.other => errorText(context, setup.claimError ?? Object()),
      null => null,
    };
    return SetupPage(
      title: l10n.linkTitle,
      help: l10n.linkHelp,
      footer: [
        PrimaryButton(
          label: l10n.linkButton,
          busy: setup.busy,
          onPressed: setup.canLink ? setup.link : null,
        ),
      ],
      children: [
        CodeBoxes(
          key: ValueKey<int>(setup.codeAttempt),
          length: ClaimCode.length,
          groupOf: 3,
          uppercase: true,
          allowed: _allowed,
          keyboardType: TextInputType.visiblePassword,
          semanticLabel: l10n.linkCodeLabel,
          hasError: problem != null,
          onChanged: setup.setCode,
        ),
        if (problem != null) StepText(problem, error: true),
        if (children.isNotEmpty) ...[
          DeviceFieldLabel(l10n.linkChildLabel),
          for (final child in children)
            OptionButton(
              label: child.nickname,
              selected: setup.childId == child.id,
              onPressed: () => setup.chooseChild(child.id),
            ),
          OptionButton(
            label: l10n.linkChildLater,
            selected: setup.childId == null,
            onPressed: () => setup.chooseChild(null),
          ),
        ],
      ],
    );
  }
}

/// waiting: the device still has to confirm the link, up to the code's
/// lifetime.
class WaitingStep extends StatelessWidget {
  const WaitingStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    if (setup.timedOut) {
      return SetupPage(
        title: l10n.linkTimeoutTitle,
        help: l10n.linkTimeoutHelp,
        footer: [
          PrimaryButton(label: l10n.linkTypeAgain, onPressed: setup.typeAgain),
        ],
      );
    }
    return SetupPage(
      title: l10n.linkWaitingTitle,
      help: l10n.linkWaitingHelp,
      children: const [LoadingView()],
    );
  }
}

/// linked: done, or who will use it when nobody was chosen.
class LinkedStep extends StatelessWidget {
  const LinkedStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = context.watch<DeviceSetupController>();
    final children = context.watch<AuthController>().children;
    final child = childById(setup.childId, children);
    return SetupPage(
      title: l10n.linkedTitle,
      help: child != null
          ? l10n.linkedFor(child.nickname)
          : children.isEmpty
          ? null
          : l10n.linkedChoose,
      footer: [
        PrimaryButton(
          label: l10n.commonDone,
          onPressed: () => closeDeviceRoute(context),
        ),
      ],
      children: [
        if (child == null)
          for (final option in children)
            OptionButton(
              label: option.nickname,
              onPressed: setup.busy
                  ? null
                  : () => _assign(context, setup, option.id),
            ),
      ],
    );
  }

  Future<void> _assign(
    BuildContext context,
    DeviceSetupController setup,
    String childId,
  ) async {
    try {
      await setup.assignLinked(childId);
    } on Object catch (error) {
      if (context.mounted) showNotice(context, errorText(context, error));
    }
  }
}
