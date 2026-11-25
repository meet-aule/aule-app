import 'package:material_ui/material_ui.dart';

import '../../../core/api/models/models.dart';
import '../../../core/l10n/dates.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/labels.dart';
import '../../../core/theme/aule_colors.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/rows.dart';
import '../progress_store.dart';

/// One line of "Últimas sesiones": a session's facts, its review, or both.
@immutable
class SessionEntry {
  const SessionEntry({
    required this.sessionId,
    required this.at,
    this.fact,
    this.review,
  });

  final String sessionId;

  /// When it started, or when its review was written.
  final DateTime at;
  final SessionFact? fact;
  final Review? review;
}

/// The child's sessions, newest first. With [withFacts], each fact is
/// merged with the review of the same session; without, the reviews alone.
List<SessionEntry> sessionEntries(
  ChildProgress progress, {
  required bool withFacts,
}) {
  final reviews = progress.reviews ?? const <Review>[];
  if (!withFacts) {
    return <SessionEntry>[
      for (final review in reviews)
        SessionEntry(
          sessionId: review.sessionId,
          at: review.createdAt,
          review: review,
        ),
    ];
  }
  final byId = <String, Review>{
    for (final review in reviews) review.sessionId: review,
  };
  final seen = <String>{};
  final entries = <SessionEntry>[];
  for (final fact in progress.sessions ?? const <SessionFact>[]) {
    seen.add(fact.id);
    entries.add(
      SessionEntry(
        sessionId: fact.id,
        at: fact.startedAt ?? fact.createdAt,
        fact: fact,
        review: byId[fact.id],
      ),
    );
  }
  for (final review in reviews) {
    if (seen.contains(review.sessionId)) continue;
    entries.add(
      SessionEntry(
        sessionId: review.sessionId,
        at: review.createdAt,
        review: review,
      ),
    );
  }
  entries.sort((a, b) => b.at.compareTo(a.at));
  return entries;
}

/// Duration · objective · where · how it ended, joined with " · ". The
/// status, when known, wins over the fact's.
String sessionFactsLine(
  BuildContext context, {
  required String nickname,
  SessionFact? fact,
  SessionStatus? status,
}) {
  final l10n = context.l10n;
  final live = status?.isLive ?? fact?.isLive ?? false;
  final parts = <String>[];
  final duration = fact?.duration;
  if (!live && duration != null) {
    final minutes = (duration.inSeconds / 60).round();
    parts.add(l10n.sessionMinutes(minutes < 1 ? 1 : minutes));
  }
  final objective = fact?.objective;
  if (objective != null) {
    final text = l10n.objective(objective);
    if (text.isNotEmpty) parts.add(text);
  }
  if (fact != null) {
    parts.add(fact.onDevice ? l10n.sessionOnDevice : l10n.sessionInBrowser);
  }
  if (live) {
    parts.add(l10n.sessionInProgress);
  } else {
    final reason = status?.endReason ?? fact?.endReason;
    if (reason != null && reason.isNotEmpty) {
      parts.add(l10n.endReason(reason, nickname));
    }
  }
  return parts.join(' · ');
}

/// "lunes 23 de noviembre · 16:40".
String dayAndTime(BuildContext context, DateTime at) =>
    '${dayLabel(context, at)} · ${timeLabel(context, at)}';

/// The review's flags as tags. Unknown flags are not shown.
class FlagTags extends StatelessWidget {
  const FlagTags(this.flags, {super.key});

  final List<String> flags;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tags = <Widget>[
      for (final code in flags)
        if (l10n.flag(code) case final label?)
          Tag(label, accent: code == 'distress' || code == 'safety_concern'),
    ];
    if (tags.isEmpty) return const SizedBox.shrink();
    return TagRow(tags);
  }
}

/// A session in the child's list: the day and time, the facts, then the
/// review as the server wrote it, or that it is not ready yet.
class SessionEntryCard extends StatelessWidget {
  const SessionEntryCard({
    super.key,
    required this.entry,
    required this.nickname,
    required this.onTap,
  });

  final SessionEntry entry;
  final String nickname;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final review = entry.review;
    final fact = entry.fact;
    final facts = fact == null
        ? ''
        : sessionFactsLine(context, nickname: nickname, fact: fact);
    final nextStep = review?.nextStep;
    return AuleCard(
      onTap: onTap,
      accent: fact?.isLive ?? false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            fact == null
                ? dayLabel(context, entry.at)
                : dayAndTime(context, entry.at),
            style: theme.textTheme.titleMedium,
          ),
          if (facts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(facts, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AuleSpace.s),
          if (review != null) ...<Widget>[
            Text(review.summary, style: theme.textTheme.bodyLarge),
            if (nextStep != null && nextStep.isNotEmpty) ...<Widget>[
              const SizedBox(height: AuleSpace.xs),
              Text(
                l10n.sessionNextStep(nextStep),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (review.flags.isNotEmpty) ...<Widget>[
              const SizedBox(height: AuleSpace.s),
              FlagTags(review.flags),
            ],
          ] else if (!(fact?.isLive ?? false))
            Text(
              l10n.sessionSummaryPending,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: AuleColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}
