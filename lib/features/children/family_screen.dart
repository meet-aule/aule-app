import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/labels.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/states.dart';
import '../device/ui/devices_section.dart';
import 'children_store.dart';

/// /family, tab 2: the children, and B2's devices section below them.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final children = context.watch<AuthController>().children;
    final store = context.watch<ChildrenStore>();
    final add = Align(
      alignment: AlignmentDirectional.centerStart,
      child: SmallButton(
        label: l10n.familyAddChild,
        onPressed: () => context.push(Routes.addChild),
      ),
    );
    return AulePage(
      showBack: false,
      title: l10n.familyTitle,
      onRefresh: _refresh,
      children: <Widget>[
        SectionTitle(l10n.familyChildren),
        if (children.isEmpty)
          EmptyView(text: l10n.familyNoChildren, action: add)
        else ...<Widget>[
          for (final child in children)
            AuleCard(
              onTap: () => context.go(Routes.editChild(child.id)),
              child: _ChildCard(
                nickname: child.nickname,
                detail: store.detail(child.id),
              ),
            ),
          add,
        ],
        const DevicesSection(),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.nickname, required this.detail});

  final String nickname;
  final ChildDetail? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = _describe(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(nickname, style: theme.textTheme.titleLarge),
        if (line.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(line, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }

  /// Grade · tone (when not the default) · the first three interests.
  String _describe(BuildContext context) {
    final record = detail?.child;
    if (record == null) return '';
    final l10n = context.l10n;
    final grade = record.grade;
    return <String>[
      if (grade != null && grade.isNotEmpty) l10n.grade(grade),
      if (record.tutorPersona != ChildCodes.defaultPersona)
        l10n.personaTone(l10n.personaTitle(record.tutorPersona).toLowerCase()),
      ...record.interests.take(3),
    ].join(' · ');
  }
}
