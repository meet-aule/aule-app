import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/aule_api.dart';
import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/l10n/dates.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/error_text.dart';
import '../live/ui/live_session_banner.dart';
import 'progress_store.dart';
import 'widgets/sessions.dart';

/// /progress/child/:childId/session/:sessionId: one session's facts and
/// review. The status comes from GET /sessions/{id}, merged with the fact.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.childId,
    required this.sessionId,
  });

  final String childId;
  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  SessionStatus? _status;
  Object? _statusError;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final api = context.read<AuleApi>();
    try {
      final status = await api.session(widget.sessionId);
      if (mounted) setState(() => _status = status);
    } on Exception catch (error) {
      if (mounted) setState(() => _statusError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final auth = context.watch<AuthController>();
    final store = context.watch<ProgressStore>();
    final ref = auth.children.where((child) => child.id == widget.childId);
    final gone =
        ref.isEmpty ||
        isApiError(_statusError ?? Object(), <ApiErrorKind>{
          ApiErrorKind.notFound,
        });
    if (gone && _status == null) {
      return AulePage(title: l10n.errorNotFound);
    }
    final nickname = ref.isEmpty ? '' : ref.first.nickname;
    final progress = store.progressOf(widget.childId);
    SessionFact? fact;
    for (final item in progress.sessions ?? const <SessionFact>[]) {
      if (item.id == widget.sessionId) fact = item;
    }
    Review? review;
    for (final item in progress.reviews ?? const <Review>[]) {
      if (item.sessionId == widget.sessionId) review = item;
    }
    final status = _status;
    final at = fact?.startedAt ?? fact?.createdAt ?? review?.createdAt;
    final live = status?.isLive ?? fact?.isLive ?? false;
    final facts = sessionFactsLine(
      context,
      nickname: nickname,
      fact: fact,
      status: status,
    );
    final nextStep = review?.nextStep;

    return AulePage(
      // A long date here: "Sesión del hoy" would not read well.
      title: at == null
          ? nickname
          : l10n.sessionDetailTitle(longDateLabel(context, at)),
      children: <Widget>[
        if (live)
          LiveSessionBanner(
            sessionId: widget.sessionId,
            childId: widget.childId,
            nickname: nickname,
            onDevice: fact?.onDevice ?? false,
          ),
        if (at != null)
          Text(dayAndTime(context, at), style: theme.textTheme.titleMedium),
        if (facts.isNotEmpty) Text(facts, style: theme.textTheme.bodySmall),
        if (review != null) ...<Widget>[
          Text(review.summary, style: theme.textTheme.bodyLarge),
          if (nextStep != null && nextStep.isNotEmpty)
            Text(
              l10n.sessionNextStep(nextStep),
              style: theme.textTheme.bodyMedium,
            ),
          if (review.flags.isNotEmpty) FlagTags(review.flags),
        ] else if (!live)
          Text(
            l10n.sessionSummaryPending,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: AuleColors.muted,
            ),
          ),
      ],
    );
  }
}
