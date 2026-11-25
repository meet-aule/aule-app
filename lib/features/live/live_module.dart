import 'package:aule/core/app_deps.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'connection/fake_live_connection.dart';
import 'connection/live_connection.dart';
import 'connection/livekit_connection.dart';
import 'data/fake_live_api.dart';
import 'data/http_live_api.dart';
import 'data/live_api.dart';
import 'ui/live_screen.dart';
import 'ui/live_session_controller.dart';

/// The live-session services, provided by `app.dart`. In demo mode only the
/// fakes are built: no LiveKit, no network and no microphone prompt.
List<SingleChildWidget> liveProviders(AppDeps deps) => [
  Provider<LiveApi>.value(
    value: deps.config.demo ? FakeLiveApi() : HttpLiveApi(deps.transport!),
  ),
  Provider<LiveConnector>.value(
    value: deps.config.demo ? FakeLiveConnector() : LiveKitConnector(),
  ),
  Provider<LivePlatform>.value(
    value: deps.config.demo ? const DemoLivePlatform() : const LivePlatform(),
  ),
];

List<RouteBase> liveRoutes() => [
  GoRoute(
    path: '/live/:sessionId',
    builder: (context, state) => LiveScreen(
      sessionId: state.pathParameters['sessionId']!,
      childId: state.uri.queryParameters['child'] ?? '',
    ),
  ),
];
