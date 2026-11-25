import 'package:material_ui/material_ui.dart';

import '../../../core/api/models/models.dart';
import '../../../core/l10n/dates.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/labels.dart';
import '../../../core/theme/aule_colors.dart';
import '../../../core/theme/aule_text.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/rows.dart';

/// An unread "needs your attention" notice at the top of Progress: the
/// kind, the server's title, two lines of its body, and the day.
class AttentionCard extends StatelessWidget {
  const AttentionCard({super.key, required this.notice, required this.onTap});

  final Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AuleCard(
      accent: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Tag(l10n.noticeKindAttention, accent: true),
          const SizedBox(height: AuleSpace.s),
          Text(notice.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AuleSpace.xs),
          Text(
            notice.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AuleSpace.xs),
          Text(
            dayLabel(context, notice.createdAt),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A notice in a list: the kind, the child's nickname, the server's title
/// and the day. Unread rows have a copper dot and a semibold title.
class NoticeRow extends StatelessWidget {
  const NoticeRow({
    super.key,
    required this.notice,
    required this.onTap,
    this.nickname,
  });

  final Notice notice;
  final String? nickname;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final unread = notice.unread;
    final name = nickname;
    final kind = l10n.noticeKind(notice.kind);
    return Semantics(
      label: unread ? l10n.noticeUnread : null,
      child: AuleCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 7, right: AuleSpace.m),
              child: ExcludeSemantics(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: unread ? AuleColors.copper : const Color(0x00000000),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    name == null ? kind : '$kind · $name',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notice.title,
                    style: unread
                        ? AuleText.sans(16, 22, 600)
                        : AuleText.sans(16, 22, 400),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayLabel(context, notice.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
