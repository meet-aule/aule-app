import 'json.dart';

/// One platform request. Paths are relative to AppConfig.apiBaseUrl and
/// start with '/'; ids in them are passed through Uri.encodeComponent.
abstract interface class ApiTransport {
  Future<Json> get(String path, {Map<String, String>? query});

  /// Null when the answer has no body (204).
  Future<Json?> post(String path, [Json? body]);

  Future<Json?> put(String path, [Json? body]);

  Future<Json?> delete(String path, [Json? body]);
}
