import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/api/api_transport.dart';
import 'core/api/aule_api.dart';
import 'core/api/fake/fake_aule_api.dart';
import 'core/api/http_api_transport.dart';
import 'core/api/http_aule_api.dart';
import 'core/app_deps.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/google_auth.dart';
import 'core/config/app_config.dart';
import 'core/log/app_log.dart';
import 'core/storage/app_prefs.dart';
import 'core/storage/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Configuration and the log (debug builds only). Release builds print
  // nothing, not even an uncaught error: there is no crash reporting, and an
  // error's text can carry what was on the screen.
  final config = AppConfig.fromEnvironment();
  AppLog.configure(enabled: !kReleaseMode);
  if (kReleaseMode) {
    FlutterError.onError = (details) {};
    PlatformDispatcher.instance.onError = (error, stack) => true;
  }

  // 2. Preferences, then the token store. The Keychain survives an
  // uninstall, so a fresh install wipes secure storage first.
  final prefs = await AppPrefs.load();
  final tokens = TokenStore(demo: config.demo);
  if (!prefs.installed) {
    await tokens.wipeAll();
    await prefs.markInstalled();
  }

  // 3. The platform, or the in-memory fakes in demo mode.
  late final AuthController auth;
  final AuleApi api;
  final ApiTransport? transport;
  if (config.demo) {
    transport = null;
    api = FakeAuleApi();
  } else {
    final http = HttpApiTransport(
      baseUrl: config.apiBaseUrl,
      readToken: tokens.read,
      onUnauthorized: () => auth.handleUnauthorized(),
    );
    transport = http;
    api = HttpAuleApi(http);
  }

  // 4. The session. Google sign-in only with its flag, on Android (§2.1).
  final google =
      config.flags.googleSignIn &&
          defaultTargetPlatform == TargetPlatform.android
      ? GoogleAuth(
          serverClientId: config.googleServerClientId,
          fetchClientId: api.googleClientId,
        )
      : null;
  auth = AuthController(
    api: api,
    tokens: tokens,
    prefs: prefs,
    config: config,
    google: google,
  );

  // 5. The app, then the restore.
  runApp(
    AuleApp(
      deps: AppDeps(config: config, api: api, transport: transport, auth: auth),
    ),
  );
  await auth.restore();
}
