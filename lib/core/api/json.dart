typedef Json = Map<String, dynamic>;

String jString(Json json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('expected text at "$key"');
}

String? jStringOrNull(Json json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

bool jBool(Json json, String key, {bool fallback = false}) {
  final value = json[key];
  return value is bool ? value : fallback;
}

int jInt(Json json, String key, {int fallback = 0}) {
  final value = json[key];
  return value is num ? value.toInt() : fallback;
}

int? jIntOrNull(Json json, String key) {
  final value = json[key];
  return value is num ? value.toInt() : null;
}

double jDouble(Json json, String key, {double fallback = 0}) {
  final value = json[key];
  return value is num ? value.toDouble() : fallback;
}

double? jDoubleOrNull(Json json, String key) {
  final value = json[key];
  return value is num ? value.toDouble() : null;
}

DateTime jTime(Json json, String key) => DateTime.parse(jString(json, key));

DateTime? jTimeOrNull(Json json, String key) {
  final value = jStringOrNull(json, key);
  return value == null ? null : DateTime.parse(value);
}

List<String> jStrings(Json json, String key) {
  final value = json[key];
  return value is List
      ? value.whereType<String>().toList(growable: false)
      : const <String>[];
}

Json jObject(Json json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw FormatException('expected an object at "$key"');
}

Json? jObjectOrNull(Json json, String key) {
  final value = json[key];
  return value is Map<String, dynamic> ? value : null;
}

List<T> jList<T>(Json json, String key, T Function(Json item) parse) {
  final value = json[key];
  if (value is! List) return <T>[];
  return <T>[
    for (final item in value)
      if (item is Map<String, dynamic>) parse(item),
  ];
}
