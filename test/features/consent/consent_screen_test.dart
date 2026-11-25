import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/core/config/app_config.dart';
import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/router/routes.dart';
import 'package:aule/core/theme/aule_theme.dart';
import 'package:aule/core/widgets/buttons.dart';
import 'package:aule/core/widgets/check_row.dart';
import 'package:aule/features/consent/add_child_flow.dart';
import 'package:aule/features/consent/consent_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/harness.dart';

/// The consent screen in a router of its own, with the profile as a stub.
Future<AddChildFlow> pumpConsent(WidgetTester tester, {Locale? locale}) async {
  useTallScreen(tester);
  final api = instantApi();
  final auth = await signedInAuth(api);
  final flow = AddChildFlow(api: api, auth: auth);
  final router = GoRouter(
    initialLocation: Routes.addChild,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.addChild,
        builder: (context, state) => const ConsentScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'profile',
            builder: (context, state) => const Text('profile stub'),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: testConfig),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<AddChildFlow>.value(value: flow),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: auleTheme(),
        locale: locale ?? const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: testDelegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return flow;
}

List<bool> boxes(WidgetTester tester) => tester
    .widgetList<CheckRow>(find.byType(CheckRow))
    .map((row) => row.value)
    .toList();

void main() {
  testWidgets('asks nothing about the child, and nothing is ticked', (
    tester,
  ) async {
    await pumpConsent(tester);
    expect(find.text(es.consentTitle), findsOneWidget);
    // The voice box and both "what we keep" boxes, in a panel that starts
    // open, all unticked.
    expect(boxes(tester), <bool>[false, false, false]);
    expect(find.text(es.consentMemory), findsOneWidget);
    expect(find.text(es.consentTranscripts), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Autorizo waits for the voice box', (tester) async {
    final flow = await pumpConsent(tester);
    PrimaryButton agree() =>
        tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(agree().onPressed, isNull);

    // Memory alone is not enough.
    await tester.tap(find.text(es.consentMemory));
    await tester.pump();
    expect(agree().onPressed, isNull);

    await tester.tap(find.text(es.consentVoice));
    await tester.pump();
    expect(agree().onPressed, isNotNull);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    final draft = flow.consent!;
    expect(draft.memory, isTrue);
    expect(draft.transcripts, isFalse);
    expect(draft.locale, 'es-PE');
    expect(find.text('profile stub'), findsOneWidget);
  });

  testWidgets('in English the answers are recorded as en', (tester) async {
    final flow = await pumpConsent(tester, locale: const Locale('en'));
    await tester.tap(find.text(en.consentVoice));
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    expect(flow.consent!.locale, 'en');
  });

  testWidgets('the panel closes and opens again', (tester) async {
    await pumpConsent(tester);
    await tester.tap(find.text(es.consentKeepToggle));
    await tester.pump();
    expect(find.text(es.consentMemory), findsNothing);
    await tester.tap(find.text(es.consentKeepToggle));
    await tester.pump();
    expect(find.text(es.consentMemory), findsOneWidget);
  });
}
