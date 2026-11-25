import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/states.dart';
import 'progress_store.dart';
import 'widgets/notices.dart';

/// /progress/notices: every notice, newest first, at most the server's 50.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProgressStore>().refreshNotices();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final store = context.watch<ProgressStore>();
    final children = context.watch<AuthController>().children;
    final nicknames = <String, String>{
      for (final child in children) child.id: child.nickname,
    };
    final notices = store.notices.take(50).toList();
    final error = store.noticesError;
    return AulePage(
      title: l10n.noticesTitle,
      onRefresh: store.refreshNotices,
      children: <Widget>[
        if (notices.isEmpty && !store.noticesLoaded && error == null)
          const LoadingView()
        else if (notices.isEmpty && error != null)
          ErrorView(error: error, onRetry: store.refreshNotices)
        else if (notices.isEmpty)
          EmptyView(text: l10n.noticesEmpty)
        else
          for (final notice in notices)
            NoticeRow(
              notice: notice,
              nickname: notice.childId == null
                  ? null
                  : nicknames[notice.childId],
              onTap: () => context.go(Routes.notice(notice.id)),
            ),
      ],
    );
  }
}
