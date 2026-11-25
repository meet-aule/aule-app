import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../log/app_log.dart';
import 'api_exception.dart';
import 'api_transport.dart';
import 'json.dart';

/// The platform over HTTPS, as the signed-in guardian (§6.6).
///
/// It sends only `Accept`, `Authorization` (when there is a token) and
/// `Content-Type` (when there is a body). It keeps no cache and no cookies,
/// and never retries: callers decide. It logs only the method, the route
/// template, the status and the time taken.
class HttpApiTransport implements ApiTransport {
  HttpApiTransport({
    required String baseUrl,
    required Future<String?> Function() readToken,
    required void Function() onUnauthorized,
    http.Client? client,
    Duration timeout = const Duration(seconds: 20),
  }) : _baseUrl = baseUrl,
       _readToken = readToken,
       _onUnauthorized = onUnauthorized,
       _client = client ?? http.Client(),
       _timeout = timeout;

  final String _baseUrl;
  final Future<String?> Function() _readToken;
  final void Function() _onUnauthorized;
  final http.Client _client;
  final Duration _timeout;

  @override
  Future<Json> get(String path, {Map<String, String>? query}) async {
    final json = await _send('GET', path, query: query);
    if (json == null) {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
    return json;
  }

  @override
  Future<Json?> post(String path, [Json? body]) =>
      _send('POST', path, body: body);

  @override
  Future<Json?> put(String path, [Json? body]) =>
      _send('PUT', path, body: body);

  @override
  Future<Json?> delete(String path, [Json? body]) =>
      _send('DELETE', path, body: body);

  /// Closes the underlying client. The app never calls it; tests may.
  void close() => _client.close();

  Future<Json?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Json? body,
  }) async {
    final watch = Stopwatch()..start();
    var status = 0;
    try {
      final base = Uri.parse('$_baseUrl$path');
      final uri = query == null || query.isEmpty
          ? base
          : base.replace(
              queryParameters: <String, String>{
                ...base.queryParameters,
                ...query,
              },
            );
      final request = http.Request(method, uri);
      request.headers['Accept'] = 'application/json';
      final token = await _readToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (body != null) {
        // bodyBytes leaves Content-Type alone, so it stays exactly this.
        request.bodyBytes = utf8.encode(jsonEncode(body));
        request.headers['Content-Type'] = 'application/json';
      }
      final streamed = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(_timeout);
      status = response.statusCode;
      if (status >= 200 && status < 300) {
        if (response.bodyBytes.isEmpty) return null;
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) return decoded;
        throw ApiException(ApiErrorKind.invalidResponse, status: status);
      }
      final error = _errorOf(response.bodyBytes);
      if (status == 401) _onUnauthorized();
      throw ApiException(
        errorKindForStatus(status),
        status: status,
        code: error?.code,
        message: error?.message,
      );
    } on ApiException {
      rethrow;
    } on http.ClientException {
      throw const ApiException(ApiErrorKind.network);
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.network);
    } on IOException {
      // SocketException, HandshakeException and the other TLS failures.
      throw const ApiException(ApiErrorKind.network);
    } on FormatException {
      throw ApiException(
        ApiErrorKind.invalidResponse,
        status: status == 0 ? null : status,
      );
    } finally {
      AppLog.info('api.request', <String, Object>{
        'method': method,
        'route': routeTemplate(path),
        'status': status,
        'ms': watch.elapsedMilliseconds,
      });
    }
  }

  static ({String? code, String? message})? _errorOf(List<int> bytes) {
    if (bytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      final error = jObjectOrNull(decoded, 'error');
      if (error == null) return null;
      return (
        code: jStringOrNull(error, 'code'),
        message: jStringOrNull(error, 'message'),
      );
    } on FormatException {
      return null;
    }
  }

  static const Set<String> _routeWords = <String>{
    'auth',
    'start',
    'verify',
    'google',
    'signout',
    'me',
    'families',
    'children',
    'consents',
    'reviews',
    'skills',
    'sessions',
    'end',
    'join',
    'memories',
    'notices',
    'read',
    'devices',
    'claim',
  };

  /// The path with the query dropped and every segment that is not a known
  /// route word replaced by `{id}`, so no id ever reaches the log.
  @visibleForTesting
  static String routeTemplate(String path) {
    final bare = path.split('?').first;
    return bare
        .split('/')
        .map(
          (segment) => segment.isEmpty || _routeWords.contains(segment)
              ? segment
              : '{id}',
        )
        .join('/');
  }
}
