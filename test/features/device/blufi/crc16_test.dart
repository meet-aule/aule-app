import 'dart:convert';

import 'package:aule/features/device/blufi/crc16.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CRC-16/GENIBUS has the check value 0xD64E', () {
    expect(crc16Genibus(ascii.encode('123456789')), 0xD64E);
  });

  test('no bytes give the initial value inverted', () {
    expect(crc16Genibus(const <int>[]), 0x0000);
  });

  test('it reads only the low byte of each value', () {
    expect(
      crc16Genibus(const <int>[0x131, 0x132]),
      crc16Genibus(const <int>[0x31, 0x32]),
    );
  });
}
