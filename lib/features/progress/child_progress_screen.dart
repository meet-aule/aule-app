import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/labels.dart';
import '../../core/router/routes.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/rows.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/states.dart';
import '../children/children_store.dart';
import '../live/ui/live_session_banner.dart';
import 'progress_store.dart';
import 'widgets/notices.dart';
import 'widgets/sessions.dart';

/// /progress/child/:childId: what one child knows, what comes next, their
/// latest sessions and their notices.
class ChildProgressScreen extends StatefulWidget {
  const ChildProgressScreen({super.key, required this.childId});

  final String childId;

  static const maxSkillNames = 5;
  static const maxNotices = 5;

  @override
  State<ChildProgressScreen> createState() => _ChildProgressScreenState();
}

class _ChildProgressScreenState extends State<ChildProgressScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProgressStore>().refreshChild(widget.childId);
    // For the grade in the step line.
    context.read<ChildrenStore>().load(widget.childId).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final flags = context.read<AppConfig>().flags;
    final auth = context.watch<AuthController>();
    final store = context.watch<ProgressStore>();
    final detail = context.watch<ChildrenStore>().detail(widget.childId);
    final ref = auth.children.where((child) => child.id == widget.childId);
    if (ref.isEmpty) {
      // Deleted, or not this family's: nothing to show.
      return AulePage(title: l10n.errorNotFound);
    }
    final nickname = ref.first.nickname;
    final grade = detail?.child.grade;
    final progress = store.progressOf(widget.childId);
    final skills = progress.skills;
    final suggestions = skills?.suggestions(store.skillName);
    final entries = sessionEntries(progress, withFacts: flags.sessionList);
    final notices = store
        .noticesFor(widget.childId)
        .take(ChildProgressScreen.maxNotices)
        .toList();

    return AulePage(
      title: nickname,
      step: grade == null || grade.isEmpty ? null : l10n.grade(grade),
      onRefresh: () => store.refreshChild(widget.childId),
      children: <Widget>[
        for (final session in store.liveSessions(widget.childId))
          LiveSessionBanner(
            sessionId: session.id,
            childId: widget.childId,
            nickname: nickname,
            onDevice: session.onDevice,
          ),

        // What they know.
        SectionTitle(l10n.childProgressKnows),
        if (!progress.loaded)
          const LoadingView()
        else if (skills == null)
          ErrorView(
            error: progress.skillsError ?? progress.reviewsError ?? Object(),
            onRetry: () => store.refreshChild(widget.childId),
          )
        else ...<Widget>[
          Text(
            skills.worked.isEmpty
                ? l10n.progressNoExercises
                : l10n.skillsLine(skills.masteredCount, skills.practisingCount),
            style: theme.textTheme.bodyLarge,
          ),
          if (store.catalogAvailable && suggestions != null)
            ..._skillNames(context, store, skills, {
              for (final skill in [
                ...suggestions.revisit,
                ...suggestions.ongoing,
                ...suggestions.other,
              ])
                skill.skillId,
            }),
        ],

        // What comes next.
        if (suggestions != null && suggestions.revisit.isNotEmpty) ...<Widget>[
          SectionTitle(l10n.childProgressRevisit),
          for (final skill in suggestions.revisit) _NextRow(name: skill.name),
        ],
        if (suggestions != null && suggestions.ongoing.isNotEmpty) ...<Widget>[
          SectionTitle(l10n.childProgressOngoing),
          for (final skill in suggestions.ongoing) _NextRow(name: skill.name),
        ],
        if (suggestions != null && suggestions.other.isNotEmpty) ...<Widget>[
          SectionTitle(l10n.childProgressNext),
          for (final skill in suggestions.other)
            _NextRow(
              name: skill.name,
              reason: l10n.nextReason(skill.reason ?? ''),
            ),
        ],

        // The latest sessions.
        SectionTitle(l10n.childProgressSessions),
        if (progress.loaded && entries.isEmpty)
          EmptyView(text: l10n.childProgressEmpty(nickname))
        else
          for (final entry in entries)
            SessionEntryCard(
              entry: entry,
              nickname: nickname,
              onTap: () => context.go(
                Routes.sessionDetail(widget.childId, entry.sessionId),
              ),
            ),

        // Their notices.
        SectionTitle(l10n.childProgressNotices(nickname)),
        for (final notice in notices)
          NoticeRow(
            notice: notice,
            onTap: () => context.push(Routes.notice(notice.id)),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: LinkButton(
            label: l10n.progressNotices,
            onPressed: () => context.go(Routes.notices),
          ),
        ),
      ],
    );
  }

  /// "Ya domina" and "Está practicando", up to five names each.
  List<Widget> _skillNames(
    BuildContext context,
    ProgressStore store,
    SkillReport skills,
    Set<String> shownInSuggestions,
  ) {
    final l10n = context.l10n;
    List<String> names(bool mastered) => <String>[
      for (final skill in skills.worked)
        if (skill.mastered == mastered &&
            !shownInSuggestions.contains(skill.skillId))
          ?store.skillName(skill.skillId),
    ].take(ChildProgressScreen.maxSkillNames).toList();
    final mastered = names(true);
    final practising = names(false);
    return <Widget>[
      if (mastered.isNotEmpty)
        InfoRow(label: l10n.childProgressMastered, value: mastered.join(' · ')),
      if (practising.isNotEmpty)
        InfoRow(
          label: l10n.childProgressPractising,
          value: practising.join(' · '),
        ),
    ];
  }
}

class _NextRow extends StatelessWidget {
  const _NextRow({required this.name, this.reason});

  final String name;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final tag = reason;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
        ),
        if (tag != null) ...<Widget>[
          const SizedBox(width: AuleSpace.s),
          Tag(tag),
        ],
      ],
    );
  }
}
