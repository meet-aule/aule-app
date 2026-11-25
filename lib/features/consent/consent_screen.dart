import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/links.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/theme/aule_text.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/check_row.dart';
import 'add_child_flow.dart';
import 'consent_draft.dart';

/// /add-child, step 1 of 2: the parent's permission. It asks nothing about
/// the child and shows no child data. Every box starts unticked.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _voice = false;
  bool _memory = false;
  bool _transcripts = false;
  bool _keepOpen = true; // "Qué guardamos" starts open

  @override
  void initState() {
    super.initState();
    // Coming back from the profile: the boxes as the parent left them.
    final draft = context.read<AddChildFlow>().consent;
    if (draft != null) {
      _voice = true;
      _memory = draft.memory;
      _transcripts = draft.transcripts;
    }
  }

  void _agree() {
    context.read<AddChildFlow>().accept(
      ConsentDraft(
        memory: _memory,
        transcripts: _transcripts,
        locale: consentLocaleOf(context),
      ),
    );
    context.push(Routes.addChildProfile);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, result) {
        // Back clears the draft.
        if (didPop) context.read<AddChildFlow>().cancel();
      },
      child: AulePage(
        step: l10n.consentStep,
        title: l10n.consentTitle,
        help: l10n.consentHelp,
        children: <Widget>[
          CheckRow(
            boxed: true,
            value: _voice,
            onChanged: (value) => setState(() => _voice = value),
            label: l10n.consentVoice,
          ),
          _KeepToggle(
            label: l10n.consentKeepToggle,
            open: _keepOpen,
            onPressed: () => setState(() => _keepOpen = !_keepOpen),
          ),
          if (_keepOpen)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // What is kept whatever the boxes say, then the two choices.
                Text(l10n.consentAlwaysKept, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AuleSpace.s),
                CheckRow(
                  value: _memory,
                  onChanged: (value) => setState(() => _memory = value),
                  label: l10n.consentMemory,
                ),
                CheckRow(
                  value: _transcripts,
                  onChanged: (value) => setState(() => _transcripts = value),
                  label: l10n.consentTranscripts,
                ),
                const SizedBox(height: AuleSpace.s),
                Text(l10n.consentNever, style: theme.textTheme.bodySmall),
              ],
            ),
          // Outside the panel, so closing it never hides the policy.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LinkButton(
              label: l10n.commonPrivacyPolicy,
              onPressed: () => openPrivacyPolicy(context),
            ),
          ),
        ],
        footer: <Widget>[
          PrimaryButton(
            label: l10n.consentAgree,
            onPressed: _voice ? _agree : null,
          ),
        ],
      ),
    );
  }
}

/// "Qué guardamos": a link-style toggle for the panel below it.
class _KeepToggle extends StatelessWidget {
  const _KeepToggle({
    required this.label,
    required this.open,
    required this.onPressed,
  });

  final String label;
  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = AuleText.sans(15, 22, 500).copyWith(
      decoration: TextDecoration.underline,
      decorationColor: AuleColors.ink,
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        container: true,
        button: true,
        expanded: open,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(auleRadius),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuleSpace.xs,
                vertical: AuleSpace.s,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label, style: style),
                  const SizedBox(width: AuleSpace.xs),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AuleColors.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
