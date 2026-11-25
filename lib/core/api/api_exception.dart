enum ApiErrorKind {
  badRequest, // 400
  unauthorized, // 401
  forbidden, // 403
  notFound, // 404, also an unknown route
  conflict, // 409
  planLimit, // 402
  unavailable, // 503
  internal, // 500 and any other status
  network, // no answer, timeout, TLS failure
  invalidResponse, // an answer that is not the JSON promised
}

class ApiException implements Exception {
  const ApiException(this.kind, {this.status, this.code, this.message});

  final ApiErrorKind kind;
  final int? status;

  /// The platform's error.code, such as "not_found".
  final String? code;

  /// The platform's error.message, in English. Used only to tell two errors
  /// with the same code apart (§9.3); never shown and never logged.
  final String? message;

  @override
  String toString() => 'ApiException($kind, $status)';
}

/// The kind of error a non-2xx HTTP status means.
ApiErrorKind errorKindForStatus(int status) => switch (status) {
  400 => ApiErrorKind.badRequest,
  401 => ApiErrorKind.unauthorized,
  402 => ApiErrorKind.planLimit,
  403 => ApiErrorKind.forbidden,
  404 => ApiErrorKind.notFound,
  409 => ApiErrorKind.conflict,
  503 => ApiErrorKind.unavailable,
  _ => ApiErrorKind.internal,
};
