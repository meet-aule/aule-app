import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/aule_api.dart';
import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/links.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/rows.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snack.dart';
import '../../core/widgets/states.dart';
import '../children/children_store.dart';
import '../consent/consent_texts.dart';
import '../consent/voice_consent_sheet.dart';
import '../progress/progress_store.dart';

/// /privacy/child/:childId: the three consents, what Aule remembers, and
/// deleting the child's data.
class ChildPrivacyScreen extends StatefulWidget {
  const ChildPrivacyScreen({super.key, required this.childId});

  final String childId;

  @override
  State<ChildPrivacyScreen> createState() => _ChildPrivacyScreenState();
}

class _ChildPrivacyScreenState extends State<ChildPrivacyScreen> {
  /// The purpose being saved, and the value its switch shows meanwhile.
  ConsentPurpose? _saving;
  bool _savingValue = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    // Fresh: the switches must show the current consent.
    context.read<ChildrenStore>().load(widget.childId, force: true).ignore();
  }

  /// What happens to a session going on now. With sessionList the app ends
  /// it; without, it cannot see it, and says so (gaps 5 and 6b).
  static String _sessionNote(
    AppLocalizations l10n,
    FeatureFlags flags,
    String nickname,
  ) => flags.sessionList
      ? l10n.sessionCloseNote(nickname)
      : l10n.sessionMayContinueNote(nickname);

  Future<void> _change(
    ConsentPurpose purpose,
    bool granted,
    String nickname,
  ) async {
    final l10n = context.l10n;
    final flags = context.read<AppConfig>().flags;
    if (!granted) {
      // Switching off always asks first.
      final (title, body, confirm) = switch (purpose) {
        ConsentPurpose.voice => (
          l10n.withdrawVoiceTitle,
          '${l10n.withdrawVoiceBody(nickname)}\n\n'
              '${_sessionNote(l10n, flags, nickname)}',
          l10n.withdrawVoiceConfirm,
        ),
        ConsentPurpose.memory => (
          l10n.withdrawMemoryTitle,
          l10n.withdrawMemoryBody(nickname),
          l10n.withdrawMemoryConfirm,
        ),
        ConsentPurpose.transcripts => (
          l10n.withdrawTranscriptsTitle,
          l10n.withdrawTranscriptsBody,
          l10n.withdrawTranscriptsConfirm,
        ),
      };
      final confirmed = await showConfirmSheet(
        context,
        title: title,
        body: body,
        confirmLabel: confirm,
        danger: true,
      );
      if (!confirmed || !mounted) return;
    } else if (purpose == ConsentPurpose.voice) {
      // Voice is asked for again with its full text, unticked.
      final agreed = await showVoiceConsentSheet(context, nickname: nickname);
      if (!agreed || !mounted) return;
    }
    // Memory and transcripts switched on are recorded at once: the switch
    // is the parent's own act.
    await _record(purpose, granted, nickname);
  }

  Future<void> _record(
    ConsentPurpose purpose,
    bool granted,
    String nickname,
  ) async {
    final api = context.read<AuleApi>();
    final store = context.read<ChildrenStore>();
    final progress = context.read<ProgressStore>();
    final sessionList = context.read<AppConfig>().flags.sessionList;
    final locale = consentLocaleOf(context);
    final failed = context.l10n.consentSaveFailed;
    final closeFailed = context.l10n.sessionCloseFailed(nickname);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = purpose;
      _savingValue = granted;
    });
    try {
      final consent = await api.recordConsent(
        widget.childId,
        ConsentAnswer(
          purpose: purpose,
          granted: granted,
          policyVersion: kConsentPolicyVersion,
          locale: locale,
        ),
      );
      store.setConsent(widget.childId, consent);
      if (purpose == ConsentPurpose.voice && !granted && sessionList) {
        // Until gap 6b ends them on the server: the sessions are read fresh,
        // not from what Progress last showed.
        if (!await progress.endLiveSessions(widget.childId)) {
          showNoticeOn(messenger, closeFailed);
        }
      }
    } on Exception {
      // The switch goes back to what the server has.
      showNoticeOn(messenger, failed);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _delete(String nickname) async {
    final l10n = context.l10n;
    final flags = context.read<AppConfig>().flags;
    final confirmed = await showConfirmSheet(
      context,
      title: l10n.deleteChildTitle(nickname),
      body: '${l10n.deleteChildBody}\n\n${_sessionNote(l10n, flags, nickname)}',
      confirmLabel: l10n.deleteChildConfirm,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final store = context.read<ChildrenStore>();
    final progress = context.read<ProgressStore>();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final done = l10n.deleteChildDone(nickname);
    final closeFailed = l10n.sessionCloseFailed(nickname);
    setState(() => _deleting = true);
    try {
      // A session going on now is ended first, read fresh (gap 6b), so the
      // child is not left talking to a tutor whose data is gone.
      final ended =
          !flags.sessionList || await progress.endLiveSessions(widget.childId);
      // Deletes, then refreshes `me`.
      await store.delete(widget.childId);
      router.go(Routes.privacy);
      showNoticeOn(messenger, ended ? done : '$done $closeFailed');
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showNotice(context, errorText(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final auth = context.watch<AuthController>();
    final store = context.watch<ChildrenStore>();
    final ref = auth.children.where((child) => child.id == widget.childId);
    if (ref.isEmpty && !_deleting) {
      return AulePage(title: l10n.errorNotFound);
    }
    final nickname = ref.isEmpty ? '' : ref.first.nickname;
    final detail = store.detail(widget.childId);
    final loadError = store.error(widget.childId);
    final saving = _saving;
    bool shown(ConsentPurpose purpose) => saving == purpose
        ? _savingValue
        : (detail?.consent.of(purpose) ?? false);
    ValueChanged<bool>? onChanged(ConsentPurpose purpose) =>
        saving != null || _deleting || detail == null
        ? null
        : (value) => _change(purpose, value, nickname);

    return AulePage(
      title: l10n.childPrivacyTitle(nickname),
      children: <Widget>[
        if (detail == null)
          loadError == null
              ? const LoadingView()
              : ErrorView(
                  error: loadError,
                  onRetry: () => store.retry(widget.childId),
                )
        else ...<Widget>[
          SwitchRow(
            label: l10n.consentVoiceLabel,
            help: l10n.consentVoiceDesc(nickname),
            value: shown(ConsentPurpose.voice),
            onChanged: onChanged(ConsentPurpose.voice),
          ),
          const LineDivider(),
          SwitchRow(
            label: l10n.consentMemoryLabel,
            help: l10n.consentMemoryDesc,
            value: shown(ConsentPurpose.memory),
            onChanged: onChanged(ConsentPurpose.memory),
          ),
          const LineDivider(),
          SwitchRow(
            label: l10n.consentTranscriptsLabel,
            help: l10n.consentTranscriptsDesc,
            value: shown(ConsentPurpose.transcripts),
            onChanged: onChanged(ConsentPurpose.transcripts),
          ),
          // What Aule's team wrote about the child for the tutor: the family
          // sees everything kept about them.
          if (detail.child.notes case final notes?
              when notes.trim().isNotEmpty) ...<Widget>[
            const LineDivider(),
            InfoRow(label: l10n.childTeamNoteLabel, value: notes),
            Text(l10n.childTeamNoteHelp, style: theme.textTheme.bodySmall),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: LinkButton(
                label: l10n.commonWriteUs,
                onPressed: () => openSupportMail(context),
              ),
            ),
          ],
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LinkButton(
              label: l10n.memoriesLink,
              onPressed: () => context.go(Routes.memories(widget.childId)),
            ),
            LinkButton(
              label: l10n.deleteChildLink(nickname),
              danger: true,
              onPressed: _deleting ? null : () => _delete(nickname),
            ),
          ],
        ),
      ],
    );
  }
}
