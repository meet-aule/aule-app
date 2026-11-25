import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// The app's only log. It writes through `dart:developer` in debug builds and
/// nothing at all in release builds.
///
/// Allowed field values: numbers, booleans, enum names and route templates
/// with `{id}` in place of ids. Never pass ids, names, nicknames, emails,
/// notes, summaries, memories, notice texts, SSIDs, passwords, codes or
/// tokens. As a last guard, a text value that does not look like a code or a
/// route template is replaced before it is written.
abstract final class AppLog {
  static bool _enabled = false;

  static final RegExp _safeText = RegExp(r'^[A-Za-z0-9_./{}:-]{1,64}$');

  static void configure({required bool enabled}) {
    _enabled = enabled && !kReleaseMode;
  }

  static void info(String event, [Map<String, Object> fields = const {}]) =>
      _write(800, event, fields);

  static void warn(String event, [Map<String, Object> fields = const {}]) =>
      _write(900, event, fields);

  static void _write(int level, String event, Map<String, Object> fields) {
    if (!_enabled || kReleaseMode) return;
    final parts = <String>[event];
    fields.forEach((key, value) => parts.add('$key=${_safe(value)}'));
    developer.log(parts.join(' '), name: 'aule', level: level);
  }

  static String _safe(Object value) {
    if (value is num || value is bool) return '$value';
    if (value is Enum) return value.name;
    if (value is String && _safeText.hasMatch(value) && !value.contains('@')) {
      return value;
    }
    return '<dropped>';
  }
}
