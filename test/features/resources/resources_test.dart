import 'package:aule/core/config/app_config.dart';
import 'package:aule/core/router/app_router.dart';
import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/core/router/routes.dart';
import 'package:aule/features/resources/lesson.dart';
import 'package:aule/features/resources/resources_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/harness.dart';

void main() {
  test('open activities are available even when account restoration is unavailable', () {
    for (final state in AuthState.values) {
      expect(
        authRedirect(
          state: state,
          hasChildren: false,
          startDismissed: false,
          hasConsentDraft: false,
          location: Routes.resources,
        ),
        isNull,
      );
    }
  });

  test(
    'activity links use the configured playground without private identifiers',
    () {
      final config = AppConfig(
        apiBaseUrl: 'https://school.example/aule/api/v1/',
        demo: false,
        flags: testConfig.flags,
        googleServerClientId: '',
        googleIosClientId: '',
        privacyPolicyUrl: '',
        privacyPolicyUrlEn: '',
        supportEmail: '',
        version: 'test',
      );
      expect(
        config.resourceLink('add-fractions', 'en', practice: true).toString(),
        'https://school.example/aule/?practice=add-fractions&lang=en',
      );
      expect(
        config
            .resourceLink('compare-fractions', 'es', practice: false)
            .toString(),
        'https://school.example/aule/resources?activity=compare-fractions&lang=es',
      );
      expect(
        testConfig.resourceLink('add-fractions', 'es', practice: true),
        isNull,
      );
      expect(config.resourceLink('../', 'en', practice: true), isNull);
    },
  );

  for (final lang in ['es', 'en']) {
    testWidgets(
      'opens a complete offline lesson in $lang and keeps answers folded',
      (tester) async {
        useTallScreen(tester);
        final lessons = Lesson.inLanguage(lang);
        expect(lessons.map((l) => l.id), [
          'equivalent-fractions',
          'compare-fractions',
          'add-fractions',
        ]);
        await pumpScreen(tester, const ResourcesScreen(), locale: Locale(lang));
        final lesson = lessons[1];
        await tester.tap(find.text(lesson.title));
        await tester.pumpAndSettle();
        expect(find.text(lesson.prompt), findsOneWidget);
        expect(find.text(lesson.answerKey), findsNothing);
        final key = find.text(lang == 'en' ? en.resourcesKey : es.resourcesKey);
        await tester.scrollUntilVisible(
          key,
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(key);
        await tester.pumpAndSettle();
        expect(find.text(lesson.answerKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
