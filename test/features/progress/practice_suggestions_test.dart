import 'package:aule/core/api/json.dart';
import 'package:aule/core/api/models/progress.dart';
import 'package:aule/core/api/fake/demo_data.dart';
import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/features/children/children_store.dart';
import 'package:aule/features/progress/child_progress_screen.dart';
import 'package:aule/features/progress/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../core/harness.dart';

void main() {
  test('each named practice group keeps up to three skills with attempts', () {
    final report = SkillReport.fromJson({
      'skills': [
        for (final id in ['a', 'b', 'c', 'd', 'e', 'missing-name'])
          {'skill_id': id, 'attempts': 2},
        {'skill_id': 'untried', 'attempts': 0},
      ],
      'next': <Json>[
        {'skill_id': 'missing-name', 'reason': 'review_due'},
        for (final id in ['a', 'b', 'c', 'd'])
          {'skill_id': id, 'name': ' $id ', 'reason': 'review_due'},
        {'skill_id': 'e', 'name': ' ', 'reason': 'in_progress'},
        {'skill_id': 'untried', 'name': 'Untried', 'reason': 'review_due'},
        {'skill_id': 'future', 'name': 'Future', 'reason': 'ready'},
      ],
    });
    final groups = report.suggestions(
      (id) => id == 'e' ? 'Catalog name' : null,
    );
    expect(groups.revisit.map((s) => s.name), ['a', 'b', 'c']);
    expect(groups.ongoing.single.name, 'Catalog name');
    expect(groups.other.map((s) => (s.name, s.reason)), [
      ('Untried', null),
      ('Future', 'ready'),
    ]);
  });

  test('legacy responses keep a suggested name without implying practice', () {
    final report = SkillReport.fromJson({
      'skills': [
        {'skill_id': 'old'},
      ],
      'next': [
        {'skill_id': 'old', 'name': 'Older skill', 'reason': 'in_progress'},
        {'skill_id': 'no-reason', 'name': 'Unnamed reason'},
      ],
    });
    final groups = report.suggestions((_) => null);
    expect(groups.revisit, isEmpty);
    expect(groups.ongoing, isEmpty);
    expect(groups.other.map((s) => s.reason), [null, null]);
  });

  testWidgets(
    'the child screen shows practice once and separates upcoming topics',
    (tester) async {
      useTallScreen(tester);
      final api = instantApi();
      final auth = await signedInAuth(api);
      final store = ProgressStore(
        api: api,
        auth: auth,
        flags: testConfig.flags,
      );
      final children = ChildrenStore(api: api, auth: auth);
      await store.refresh();
      await pumpScreen(
        tester,
        const ChildProgressScreen(childId: DemoData.childMati),
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<ProgressStore>.value(value: store),
          ChangeNotifierProvider<ChildrenStore>.value(value: children),
        ],
      );
      expect(find.text(es.childProgressOngoing), findsOneWidget);
      expect(find.text('Tabla del 4'), findsOneWidget);
      expect(find.text(es.childProgressNext), findsOneWidget);
      expect(find.text('Sumas de tres cifras'), findsOneWidget);
      // No recorded attempt for the demo's "Tabla del 3" recommendation.
      expect(find.text('Tabla del 3'), findsOneWidget);
      expect(find.text(es.childProgressRevisit), findsNothing);
      expect(find.text(es.reasonReviewDue), findsNothing);
    },
  );
}
