import 'package:aule/core/api/json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Json json = <String, dynamic>{
    'text': 'hola',
    'yes': true,
    'count': 3,
    'ratio': 0.5,
    'whole': 2.0,
    'at': '2026-11-23T15:04:05Z',
    'tags': <dynamic>['a', 1, 'b', null],
    'object': <String, dynamic>{'x': 1},
    'items': <dynamic>[
      <String, dynamic>{'id': 'one'},
      'not an object',
      <String, dynamic>{'id': 'two'},
    ],
  };

  test('jString answers text and refuses anything else', () {
    expect(jString(json, 'text'), 'hola');
    expect(() => jString(json, 'count'), throwsFormatException);
    expect(() => jString(json, 'missing'), throwsFormatException);
    expect(jStringOrNull(json, 'count'), isNull);
    expect(jStringOrNull(json, 'text'), 'hola');
  });

  test('numbers and booleans fall back when absent or of another type', () {
    expect(jBool(json, 'yes'), isTrue);
    expect(jBool(json, 'text'), isFalse);
    expect(jBool(json, 'missing', fallback: true), isTrue);
    expect(jInt(json, 'count'), 3);
    expect(jInt(json, 'whole'), 2);
    expect(jInt(json, 'missing', fallback: 7), 7);
    expect(jIntOrNull(json, 'text'), isNull);
    expect(jDouble(json, 'ratio'), 0.5);
    expect(jDouble(json, 'count'), 3.0);
    expect(jDoubleOrNull(json, 'missing'), isNull);
  });

  test('times parse as UTC instants', () {
    final at = jTime(json, 'at');
    expect(at.isUtc, isTrue);
    expect(at, DateTime.utc(2026, 11, 23, 15, 4, 5));
    expect(jTimeOrNull(json, 'missing'), isNull);
  });

  test('lists keep only the items of the right type', () {
    expect(jStrings(json, 'tags'), <String>['a', 'b']);
    expect(jStrings(json, 'missing'), isEmpty);
    final ids = jList(json, 'items', (item) => jString(item, 'id'));
    expect(ids, <String>['one', 'two']);
    expect(jList(json, 'text', (item) => item), isEmpty);
  });

  test('objects', () {
    expect(jObject(json, 'object'), <String, dynamic>{'x': 1});
    expect(() => jObject(json, 'text'), throwsFormatException);
    expect(jObjectOrNull(json, 'text'), isNull);
  });
}
