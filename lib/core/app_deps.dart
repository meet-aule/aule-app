import 'api/api_transport.dart';
import 'api/aule_api.dart';
import 'auth/auth_controller.dart';
import 'config/app_config.dart';

/// What feature modules need to build their own services.
class AppDeps {
  const AppDeps({
    required this.config,
    required this.api,
    required this.transport,
    required this.auth,
  });

  final AppConfig config;
  final AuleApi api;

  /// Null in demo mode: B2's HTTP implementations are never built then.
  final ApiTransport? transport;
  final AuthController auth;
}
