import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/links.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/rows.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snack.dart';
import '../children/children_store.dart';

/// /privacy, tab 3: what Aule keeps, each child's choices, and the account.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _savingLanguage = false;
  bool _savingNotices = false;

  @override
  void initState() {
    super.initState();
    context.read<ChildrenStore>().loadAll();
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthController>();
    final store = context.read<ChildrenStore>();
    await auth.refreshMe();
    await store.loadAll(force: true);
  }

  Future<void> _setLanguage(String language) async {
    final auth = context.read<AuthController>();
    if (_savingLanguage || auth.language == language) return;
    setState(() => _savingLanguage = true);
    try {
      // The UI switches at once: MaterialApp watches the locale.
      await auth.setLanguage(language);
    } on Exception catch (error) {
      if (mounted) showNotice(context, errorText(context, error));
    } finally {
      if (mounted) setState(() => _savingLanguage = false);
    }
  }

  Future<void> _setNotices(bool value) async {
    final auth = context.read<AuthController>();
    if (!value) {
      // The platform has one switch for every emailed notice, so turning it
      // off silences the attention ones too: the parent is told first.
      final l10n = context.l10n;
      final confirmed = await showConfirmSheet(
        context,
        title: l10n.emailNoticesOffTitle,
        body: l10n.emailNoticesOffBody,
        confirmLabel: l10n.emailNoticesOffConfirm,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _savingNotices = true);
    try {
      await auth.setNoticesByEmail(value);
    } on Exception catch (error) {
      if (mounted) showNotice(context, errorText(context, error));
    } finally {
      if (mounted) setState(() => _savingNotices = false);
    }
  }

  Future<void> _signOut() async {
    final l10n = context.l10n;
    final auth = context.read<AuthController>();
    final confirmed = await showConfirmSheet(
      context,
      title: l10n.signOutTitle,
      body: l10n.signOutBody,
      confirmLabel: l10n.signOutConfirm,
    );
    // The router takes the parent to /sign-in.
    if (confirmed) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final config = context.read<AppConfig>();
    final auth = context.watch<AuthController>();
    final store = context.watch<ChildrenStore>();
    final guardian = auth.me?.guardian;
    String yesNo(bool value) => value ? l10n.commonYes : l10n.commonNo;

    return AulePage(
      showBack: false,
      title: l10n.privacyTitle,
      help: l10n.privacyHelp,
      onRefresh: _refresh,
      children: <Widget>[
        Text(l10n.privacyWhatWeKeep, style: theme.textTheme.bodyLarge),

        // Each child's choices.
        if (auth.children.isNotEmpty) ...<Widget>[
          SectionTitle(l10n.privacyChildren),
          for (final child in auth.children)
            AuleCard(
              onTap: () => context.go(Routes.childPrivacy(child.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(child.nickname, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(switch (store.detail(child.id)?.consent) {
                    final consent? => l10n.privacyChildSummary(
                      yesNo(consent.voice),
                      yesNo(consent.memory),
                      yesNo(consent.transcripts),
                    ),
                    null => l10n.commonLoading,
                  }, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],

        // The account.
        SectionTitle(l10n.accountTitle),
        if (guardian != null) ...<Widget>[
          Text(guardian.name, style: theme.textTheme.titleMedium),
          Text(guardian.email, style: theme.textTheme.bodyMedium),
        ],
        Text(l10n.accountLanguage, style: theme.textTheme.labelSmall),
        Row(
          children: <Widget>[
            Expanded(
              child: OptionButton(
                label: l10n.languageEs,
                selected: auth.language == 'es',
                onPressed: _savingLanguage ? null : () => _setLanguage('es'),
              ),
            ),
            const SizedBox(width: AuleSpace.m),
            Expanded(
              child: OptionButton(
                label: l10n.languageEn,
                selected: auth.language == 'en',
                onPressed: _savingLanguage ? null : () => _setLanguage('en'),
              ),
            ),
          ],
        ),
        Text(l10n.accountLanguageHelp, style: theme.textTheme.bodySmall),
        if (guardian != null)
          SwitchRow(
            label: l10n.accountEmailNotices,
            help: l10n.accountEmailNoticesHelp,
            value: guardian.noticesByEmail,
            onChanged: _savingNotices ? null : _setNotices,
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LinkButton(
              label: l10n.commonPrivacyPolicy,
              onPressed: () => openPrivacyPolicy(context),
            ),
            LinkButton(label: l10n.accountSignOut, onPressed: _signOut),
            LinkButton(
              label: l10n.accountDelete,
              danger: true,
              onPressed: () => context.go(Routes.deleteAccount),
            ),
          ],
        ),
        Text(
          l10n.versionLine(config.version),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
