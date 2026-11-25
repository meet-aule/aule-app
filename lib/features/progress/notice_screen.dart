import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/labels.dart';
import '../../core/links.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/states.dart';
import 'progress_store.dart';
import 'widgets/sessions.dart';

/// /progress/notices/:noticeId: one notice, as the server wrote it.
class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key, required this.noticeId});

  final String noticeId;

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  bool _missing = false;
  bool _marked = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final store = context.read<ProgressStore>();
    // From the cached list; if it is not there, fetch the list once more.
    if (store.notice(widget.noticeId) == null) {
      await store.refreshNotices();
      if (!mounted) return;
      if (store.notice(widget.noticeId) == null) {
        setState(() => _missing = true);
        return;
      }
    }
    final notice = store.notice(widget.noticeId);
    if (notice != null && notice.unread && !_marked) {
      _marked = true;
      // Once; the store then refreshes `me` so the tab badge falls.
      await store.markRead(widget.noticeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final notice = context.watch<ProgressStore>().notice(widget.noticeId);
    if (notice == null) {
      return AulePage(
        title: _missing ? l10n.errorNotFound : l10n.noticesTitle,
        children: <Widget>[if (!_missing) const LoadingView()],
      );
    }
    final childId = notice.childId;
    final sessionId = notice.sessionId;
    return AulePage(
      step: l10n.noticeKind(notice.kind),
      title: notice.title,
      children: <Widget>[
        Text(
          dayAndTime(context, notice.createdAt),
          style: theme.textTheme.bodySmall,
        ),
        Text(notice.body, style: theme.textTheme.bodyLarge),
        if (childId != null && sessionId != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LinkButton(
              label: l10n.noticeSeeSession,
              onPressed: () =>
                  context.go(Routes.sessionDetail(childId, sessionId)),
            ),
          ),
        if (notice.kind == 'attention') ...<Widget>[
          Text(l10n.noticeAttentionHelp, style: theme.textTheme.bodySmall),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LinkButton(
              label: l10n.commonWriteUs,
              onPressed: () => openSupportMail(context),
            ),
          ),
        ],
      ],
    );
  }
}
