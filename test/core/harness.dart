// Shared helpers for B1's tests. Not a test file itself.
import 'package:aule/core/api/aule_api.dart';
import 'package:aule/core/api/fake/fake_aule_api.dart';
import 'package:aule/core/auth/auth_controller.dart';
import 'package:aule/core/config/app_config.dart';
import 'package:aule/core/l10n/l10n.dart';
import 'package:aule/core/storage/app_prefs.dart';
import 'package:aule/core/storage/token_store.dart';
import 'package:aule/core/theme/aule_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Demo-mode configuration with every proposed contract on.
const AppConfig testConfig = AppConfig(
  apiBaseUrl: '',
  demo: true,
  flags: FeatureFlags(
    googleSignIn: false,
    sessionList: true,
    liveJoin: true,
    deviceLink: true,
    bleWifi: true,
  ),
  googleServerClientId: '',
  googleIosClientId: '',
  privacyPolicyUrl: 'https://example.com/privacy',
  privacyPolicyUrlEn: 'https://example.com/en/privacy',
  supportEmail: 'help@example.com',
  version: '0.1.0-test',
);

/// The same, with the server gaps still open (no session list).
const AppConfig testConfigNoSessions = AppConfig(
  apiBaseUrl: 'https://example.com/v1',
  demo: false,
  flags: FeatureFlags(
    googleSignIn: false,
    sessionList: false,
    liveJoin: false,
    deviceLink: false,
    bleWifi: false,
  ),
  googleServerClientId: '',
  googleIosClientId: '',
  privacyPolicyUrl: 'https://example.com/privacy',
  privacyPolicyUrlEn: 'https://example.com/en/privacy',
  supportEmail: 'help@example.com',
  version: '0.1.0-test',
);

/// A fake platform that answers at once.
FakeAuleApi instantApi({bool signedIn = true, DateTime Function()? clock}) =>
    FakeAuleApi(latency: Duration.zero, signedIn: signedIn, clock: clock);

/// An AuthController over [api], with storage in memory.
AuthController testAuth({
  required AuleApi api,
  TokenStore? tokens,
  AppPrefs? prefs,
  AppConfig config = testConfig,
  Locale deviceLocale = const Locale('es'),
}) => AuthController(
  api: api,
  tokens: tokens ?? TokenStore.memory(demo: true),
  prefs: prefs ?? AppPrefs.memory(),
  config: config,
  deviceLocale: deviceLocale,
);

/// An AuthController already signed in as the demo family.
Future<AuthController> signedInAuth(
  AuleApi api, {
  AppConfig config = testConfig,
}) async {
  final tokens = TokenStore.memory(demo: true);
  await tokens.write(FakeAuleApi.token);
  final auth = testAuth(api: api, tokens: tokens, config: config);
  await auth.restore();
  expect(auth.state, AuthState.signedIn);
  return auth;
}

/// The delegates the app uses (§6.4).
final List<LocalizationsDelegate<dynamic>> testDelegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ];

/// Pumps [child] as the home of an app with the theme, the localizations
/// and the given providers.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  List<SingleChildWidget> providers = const <SingleChildWidget>[],
  Locale locale = const Locale('es'),
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppConfig>.value(value: testConfig),
        ...providers,
      ],
      child: MaterialApp(
        theme: auleTheme(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: testDelegates,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A phone-shaped window tall enough that long screens build every row:
/// 400 x 1600 logical pixels. Reset after the test.
void useTallScreen(WidgetTester tester) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(800, 3200);
  addTearDown(tester.view.reset);
}

/// The Spanish texts, for finding widgets by what they say.
AppLocalizations get es => lookupAppLocalizations(const Locale('es'));

/// The English texts.
AppLocalizations get en => lookupAppLocalizations(const Locale('en'));
