import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/api/aule_api.dart';
import 'core/app_deps.dart';
import 'core/auth/auth_controller.dart';
import 'core/config/app_config.dart';
import 'core/l10n/l10n.dart';
import 'core/router/app_router.dart';
import 'core/theme/aule_theme.dart';
import 'core/widgets/demo_banner.dart';
import 'features/children/children_store.dart';
import 'features/consent/add_child_flow.dart';
import 'features/device/device_module.dart';
import 'features/live/live_module.dart';
import 'features/progress/progress_store.dart';

/// The family app: providers, the router and the theme (§6.4).
class AuleApp extends StatefulWidget {
  const AuleApp({super.key, required this.deps});

  final AppDeps deps;

  @override
  State<AuleApp> createState() => _AuleAppState();
}

class _AuleAppState extends State<AuleApp> {
  // The generated delegates list still names the deprecated Material ones,
  // so the list is built here (§6.11). Built once, so the app does not
  // reload its localizations on every rebuild.
  static final List<LocalizationsDelegate<dynamic>> _delegates =
      <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ];

  late final AddChildFlow _addChildFlow;
  late final ProgressStore _progress;
  late final ChildrenStore _children;
  late final GoRouter _router;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final deps = widget.deps;
    _addChildFlow = AddChildFlow(api: deps.api, auth: deps.auth);
    _progress = ProgressStore(
      api: deps.api,
      auth: deps.auth,
      flags: deps.config.flags,
    );
    _children = ChildrenStore(api: deps.api, auth: deps.auth);
    // Built once: it listens to the session and the consent draft.
    _router = buildAppRouter(auth: deps.auth, addChildFlow: _addChildFlow);
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  void _onResume() {
    final auth = widget.deps.auth;
    if (auth.state != AuthState.signedIn) return;
    auth.refreshMe();
    _progress.refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    _children.dispose();
    _progress.dispose();
    _addChildFlow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: deps.config),
        Provider<AuleApi>.value(value: deps.api),
        ChangeNotifierProvider<AuthController>.value(value: deps.auth),
        ChangeNotifierProvider<AddChildFlow>.value(value: _addChildFlow),
        ChangeNotifierProvider<ProgressStore>.value(value: _progress),
        ChangeNotifierProvider<ChildrenStore>.value(value: _children),
        ...deviceProviders(deps),
        ...liveProviders(deps),
      ],
      child: Builder(
        builder: (context) {
          final locale = context.select<AuthController, Locale>(
            (auth) => auth.locale,
          );
          return MaterialApp.router(
            routerConfig: _router,
            onGenerateTitle: (context) => context.l10n.appTitle,
            theme: auleTheme(),
            themeMode: ThemeMode.light,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: _delegates,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              final page = child ?? const SizedBox.shrink();
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: auleSystemUi,
                child: deps.config.demo ? DemoBanner(child: page) : page,
              );
            },
          );
        },
      ),
    );
  }
}
