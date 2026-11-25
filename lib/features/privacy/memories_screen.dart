import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/aule_api.dart';
import '../../core/api/models/models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/l10n/dates.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/labels.dart';
import '../../core/theme/aule_colors.dart';
import '../../core/widgets/aule_page.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/rows.dart';
import '../../core/widgets/snack.dart';
import '../../core/widgets/states.dart';
import '../children/children_store.dart';

/// What Aule remembers about one child, for this screen only (§6.2): it is
/// created with the route and disposed with it, and never cached elsewhere.
class MemoriesModel extends ChangeNotifier {
  MemoriesModel({required AuleApi api, required this.childId}) : _api = api;

  static const limit = 100;

  final AuleApi _api;
  final String childId;
  List<Memory>? _memories;
  bool _partial = false;
  Object? _error;
  final Set<String> _forgetting = <String>{};
  bool _disposed = false;

  /// Newest first; null until loaded.
  List<Memory>? get memories => _memories;

  /// The platform answered as many as it returns at once, so older
  /// memories may exist that this list does not show (no paging yet, gap 9).
  bool get partial => _partial;
  Object? get error => _error;
  bool isForgetting(String memoryId) => _forgetting.contains(memoryId);

  Future<void> load() async {
    try {
      final list = await _api.memories(childId, limit: limit);
      _memories = list.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _partial = list.length >= limit;
      _error = null;
    } on Exception catch (error) {
      _error = error;
    }
    _notify();
  }

  Future<void> retry() async {
    _error = null;
    _notify();
    await load();
  }

  /// Forgets one memory. True when it is gone, also when it was already.
  Future<bool> forget(String memoryId) async {
    _forgetting.add(memoryId);
    _notify();
    try {
      await _api.forgetMemory(childId, memoryId);
      _drop(memoryId);
      return true;
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.notFound) {
        _drop(memoryId);
        return true;
      }
      return false;
    } on Exception {
      return false;
    } finally {
      _forgetting.remove(memoryId);
      _notify();
    }
  }

  void _drop(String memoryId) {
    _memories = <Memory>[
      for (final memory in _memories ?? const <Memory>[])
        if (memory.id != memoryId) memory,
    ];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// /privacy/child/:childId/memories.
class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MemoriesModel>(
      create: (context) =>
          MemoriesModel(api: context.read<AuleApi>(), childId: childId)..load(),
      child: _MemoriesView(childId: childId),
    );
  }
}

class _MemoriesView extends StatefulWidget {
  const _MemoriesView({required this.childId});

  final String childId;

  @override
  State<_MemoriesView> createState() => _MemoriesViewState();
}

class _MemoriesViewState extends State<_MemoriesView> {
  @override
  void initState() {
    super.initState();
    // The memory consent decides whether there is a list at all.
    context.read<ChildrenStore>().load(widget.childId).ignore();
  }

  Future<void> _forget(MemoriesModel model, String memoryId) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final gone = await model.forget(memoryId);
    showNoticeOn(
      messenger,
      gone ? l10n.memoryForgotten : l10n.memoryForgetFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final model = context.watch<MemoriesModel>();
    final auth = context.watch<AuthController>();
    final detail = context.watch<ChildrenStore>().detail(widget.childId);
    final ref = auth.children.where((child) => child.id == widget.childId);
    if (ref.isEmpty) return AulePage(title: l10n.errorNotFound);
    final nickname = ref.first.nickname;
    final memories = model.memories;
    final error = model.error;
    final memoryOn = detail?.consent.memory;

    return AulePage(
      title: l10n.memoriesTitle(nickname),
      onRefresh: model.load,
      children: <Widget>[
        if (memoryOn == false)
          Text(l10n.memoriesOff(nickname), style: theme.textTheme.bodyLarge)
        else if (memories == null && error != null)
          ErrorView(error: error, onRetry: model.retry)
        else if (memories == null || memoryOn == null)
          const LoadingView()
        else if (memories.isEmpty)
          EmptyView(text: l10n.memoriesEmpty(nickname))
        else ...<Widget>[
          if (model.partial)
            Text(
              l10n.memoriesLatest(MemoriesModel.limit),
              style: theme.textTheme.bodyMedium,
            ),
          for (final memory in memories)
            AuleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (l10n.memoryKind(memory.kind)
                      case final kind?) ...<Widget>[
                    Tag(kind),
                    const SizedBox(height: AuleSpace.s),
                  ],
                  Text(memory.content, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AuleSpace.xs),
                  Text(
                    dayLabel(context, memory.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AuleSpace.s),
                  SmallButton(
                    label: l10n.memoryForget,
                    onPressed: model.isForgetting(memory.id)
                        ? null
                        : () => _forget(model, memory.id),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
