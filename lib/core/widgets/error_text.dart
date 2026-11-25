import 'package:flutter/widgets.dart';

import '../api/api_exception.dart';
import '../l10n/l10n.dart';

/// The family-facing text for an error, by the mapping in §4.1.
String errorText(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is! ApiException) return l10n.errorGeneric;
  return switch (error.kind) {
    ApiErrorKind.network => l10n.errorNetwork,
    ApiErrorKind.unavailable => l10n.errorUnavailable,
    ApiErrorKind.unauthorized => l10n.errorSignedOut,
    ApiErrorKind.notFound => l10n.errorNotFound,
    _ => l10n.errorGeneric,
  };
}

/// Whether an error is one of the given kinds.
bool isApiError(Object error, Set<ApiErrorKind> kinds) =>
    error is ApiException && kinds.contains(error.kind);
