import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/dates.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/labels.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/states.dart';
import '../live/ui/live_session_banner.dart';
import 'progress_store.dart';
import 'widgets/notices.dart';

/// /progress, tab 1: what needs attention, live sessions, each child, and
/// the notices. It refreshes on open, on resume (app.dart), on pull, and
/// every 60 s while it is the screen in front.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  static const refreshEvery = Duration(seconds: 60);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Timer? _timer;

  /// Whether this screen is the one in front: its tab, and no other route
  /// over it. Updated in build, which reruns when either changes.
  bool _inFront = true;

  @override
  void initState() {
    super.initState();
    context.read<ProgressStore>().refresh();
    _timer = Timer.periodic(ProgressScreen.refreshEvery, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || !_inFront) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final flags = context.read<AppConfig>().flags;
    final store = context.read<ProgressStore>();
    context.read<AuthController>().refreshMe();
    store.refreshNotices();
    if (flags.sessionList) store.refreshLive();
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthController>();
    final store = context.read<ProgressStore>();
    await auth.refreshMe();
    await store.refresh();
  }

  @override
  Widget build(BuildContext context) {
    _inFront =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    final l10n = context.l10n;
    final auth = context.watch<AuthController>();
    final store = context.watch<ProgressStore>();
    final flags = context.read<AppConfig>().flags;
    final children = auth.children;
    final name = auth.me?.guardian.name ?? '';
    final attention = <Notice>[
      for (final notice in store.notices)
        if (notice.unread && notice.kind == 'attention') notice,
    ];

    return AulePage(
      showBack: false,
      step: name.isEmpty ? null : l10n.greeting(name),
      title: l10n.progressTitle,
      onRefresh: _refresh,
      children: <Widget>[
        for (final notice in attention)
          AttentionCard(
            notice: notice,
            onTap: () => context.push(Routes.notice(notice.id)),
          ),
        if (flags.sessionList)
          for (final child in children)
            for (final session in store.liveSessions(child.id))
              LiveSessionBanner(
                sessionId: session.id,
                childId: child.id,
                nickname: child.nickname,
                onDevice: session.onDevice,
              ),
        if (children.isEmpty)
          EmptyView(
            text: l10n.progressNoChildren,
            action: PrimaryButton(
              label: l10n.familyAddChild,
              onPressed: () => context.push(Routes.addChild),
            ),
          )
        else
          for (final child in children)
            AuleCard(
              onTap: () => context.go(Routes.childProgress(child.id)),
              child: _ChildSummary(
                nickname: child.nickname,
                progress: store.progressOf(child.id),
              ),
            ),
        LinkButton(
          label: l10n.resourcesTitle,
          onPressed: () => context.push(Routes.resources),
        ),
        AuleCard(
          onTap: () => context.go(Routes.notices),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.progressNotices,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.progressUnread(auth.me?.unreadNotices ?? 0),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A child on Progress: the nickname, the last session and what they know.
class _ChildSummary extends StatelessWidget {
  const _ChildSummary({required this.nickname, required this.progress});

  final String nickname;
  final ChildProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final last = progress.lastSessionAt;
    final summary = progress.latestReview?.summary;
    final skills = progress.skills;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(nickname, style: theme.textTheme.titleLarge),
        const SizedBox(height: AuleSpace.xs),
        if (!progress.loaded)
          Text(l10n.commonLoading, style: theme.textTheme.bodySmall)
        else ...<Widget>[
          if (last == null)
            Text(l10n.progressNoSessions, style: theme.textTheme.bodyMedium)
          else ...<Widget>[
            Text(
              l10n.progressLastSession(dayLabel(context, last, inline: true)),
              style: theme.textTheme.bodySmall,
            ),
            if (summary != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ],
          if (skills != null) ...<Widget>[
            const SizedBox(height: AuleSpace.xs),
            Text(
              skills.worked.isEmpty
                  ? l10n.progressNoExercises
                  : l10n.skillsLine(
                      skills.masteredCount,
                      skills.practisingCount,
                    ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ],
    );
  }
}
