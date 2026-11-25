import 'dart:convert';
import 'dart:typed_data';

import 'package:aule/features/device/blufi/blufi_frame.dart';
import 'package:aule/features/device/blufi/ffdhe3072.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> bytesOf(String spaced) => <int>[
  for (final part in spaced.split(' ')) int.parse(part, radix: 16),
];

void main() {
  group('phone frames, byte for byte (§8.2)', () {
    test('GET_VERSION, seq 0', () {
      final frame = buildBlufiFrame(
        type: BlufiType.getVersion,
        fc: BlufiFc.checksum,
        seq: 0,
        plain: const <int>[],
      );
      expect(frame, bytesOf('1C 02 00 00 F0 E2'));
    });

    test('NEG length, seq 1', () {
      final frame = buildBlufiFrame(
        type: BlufiType.negotiate,
        fc: BlufiFc.checksum,
        seq: 1,
        plain: blufiNegotiationLength(775),
      );
      expect(frame, bytesOf('01 02 01 03 00 03 07 CA FA'));
    });

    test('SET_SEC_MODE, seq 5', () {
      final frame = buildBlufiFrame(
        type: BlufiType.setSecurityMode,
        fc: BlufiFc.checksum,
        seq: 5,
        plain: const <int>[blufiSecurityMode],
      );
      expect(frame, bytesOf('04 02 05 01 03 C1 DB'));
    });
  });

  group('encryption and the checksum', () {
    Uint8List flip(List<int> plain) =>
        Uint8List.fromList(<int>[for (final byte in plain) byte ^ 0xFF]);

    test('the data is encrypted and the checksum covers the plain text', () {
      const plain = <int>[0x43, 0x61, 0x73, 0x61];
      final frame = buildBlufiFrame(
        type: BlufiType.staSsid,
        fc: BlufiFc.checksum | BlufiFc.encrypted,
        seq: 7,
        plain: plain,
        encrypt: flip,
      );
      expect(frame.sublist(0, 4), <int>[0x09, 0x03, 0x07, 0x04]);
      expect(frame.sublist(4, 8), flip(plain));
      final crc = blufiChecksum(7, plain);
      expect(frame.sublist(8), <int>[crc & 0xFF, crc >> 8]);
    });

    test('an encrypted frame needs a cipher, and only it gets one', () {
      expect(
        () => buildBlufiFrame(
          type: BlufiType.staSsid,
          fc: BlufiFc.checksum | BlufiFc.encrypted,
          seq: 0,
          plain: const <int>[1],
        ),
        throwsArgumentError,
      );
      expect(
        () => buildBlufiFrame(
          type: BlufiType.staSsid,
          fc: BlufiFc.checksum,
          seq: 0,
          plain: const <int>[1],
          encrypt: flip,
        ),
        throwsArgumentError,
      );
    });

    test('a device frame parses, and its checksum is checked', () {
      const plain = <int>[0x05, 0xD0, 0x43, 0x61, 0x73, 0x61];
      final bytes = buildBlufiFrame(
        type: BlufiType.wifiList,
        fc: BlufiFc.checksum | BlufiFc.fromDevice,
        seq: 3,
        plain: plain,
      );
      final frame = BlufiFrame.parse(bytes);
      expect(frame.type, BlufiType.wifiList);
      expect(frame.seq, 3);
      expect(frame.fromDevice, isTrue);
      expect(frame.encrypted, isFalse);
      expect(frame.data, plain);
      expect(frame.checksumMatches(frame.data), isTrue);
      expect(
        frame.checksumMatches(const <int>[0x05, 0xD0, 0x43, 0x61, 0x73, 0x62]),
        isFalse,
      );
    });

    test('a frame shorter than it says is refused', () {
      expect(
        () => BlufiFrame.parse(const <int>[0x45, 0x06, 0x00, 0x05, 0x01]),
        throwsFormatException,
      );
      expect(() => BlufiFrame.parse(const <int>[0x45]), throwsFormatException);
    });
  });

  group('fragments', () {
    // The size of the NEG parameters message: its type byte and 775 bytes.
    final payload = Uint8List.fromList(
      List<int>.generate(776, (i) => (i * 7 + 3) & 0xFF),
    );

    for (final mtu in const <int>[23, 517]) {
      test('a round trip at MTU $mtu', () {
        final fragments = blufiFragments(payload, mtu: mtu);
        final reassembler = BlufiReassembler();
        BlufiMessage? message;
        for (final (index, fragment) in fragments.indexed) {
          final last = index == fragments.length - 1;
          expect(fragment.more, !last);
          expect(fragment.data.length, lessThanOrEqualTo(255));
          // Each frame fits one GATT write: 4 + data_len + 2 <= mtu - 3.
          expect(4 + fragment.data.length + 2, lessThanOrEqualTo(mtu - 3));
          message = reassembler.add(
            type: BlufiType.negotiate,
            more: fragment.more,
            data: fragment.data,
          );
          if (!last) expect(message, isNull);
        }
        expect(message, isNotNull);
        expect(message!.type, BlufiType.negotiate);
        expect(message.payload, payload);
      });
    }

    test('at MTU 23 a frame carries 14 data bytes', () {
      expect(blufiMaxData(23), 14);
      final fragments = blufiFragments(payload, mtu: 23);
      expect(fragments, hasLength(65));
      // The prefix counts the bytes still to come, this fragment's included,
      // little-endian: 776, then 764.
      expect(fragments[0].data.sublist(0, 2), <int>[0x08, 0x03]);
      expect(fragments[1].data.sublist(0, 2), <int>[0xFC, 0x02]);
      expect(fragments[0].data.sublist(2), payload.sublist(0, 12));
      expect(fragments.last.data, payload.sublist(768));
    });

    test('at MTU 517 a frame carries 255 data bytes', () {
      expect(blufiMaxData(517), 255);
      final fragments = blufiFragments(payload, mtu: 517);
      expect(fragments.map((f) => f.data.length), <int>[255, 255, 255, 17]);
    });

    test('a message that fits is one frame with no prefix', () {
      final fragments = blufiFragments(const <int>[1, 2, 3], mtu: 23);
      expect(fragments, hasLength(1));
      expect(fragments.single.more, isFalse);
      expect(fragments.single.data, <int>[1, 2, 3]);
    });

    test('a fragment of another message breaks the reassembly', () {
      final reassembler = BlufiReassembler();
      reassembler.add(
        type: BlufiType.negotiate,
        more: true,
        data: const <int>[0x04, 0x00, 1, 2],
      );
      expect(
        () => reassembler.add(
          type: BlufiType.wifiList,
          more: false,
          data: const <int>[3, 4],
        ),
        throwsFormatException,
      );
    });
  });

  group('messages', () {
    test('NEG parameters are 775 bytes for ffdhe3072', () {
      final params = blufiNegotiationParams(
        prime: Ffdhe3072.primeBytes(),
        generator: Ffdhe3072.generator,
        publicKey: Uint8List(384),
      );
      expect(params, hasLength(775));
      expect(params.sublist(0, 2), <int>[0x01, 0x80]);
      expect(params.sublist(386, 389), <int>[0x00, 0x01, 0x02]);
      expect(params.sublist(389, 391), <int>[0x01, 0x80]);
      expect(blufiNegotiationLength(params.length), <int>[0x00, 0x03, 0x07]);
      expect(blufiNegotiationData(params).first, 0x01);
      expect(blufiNegotiationData(params), hasLength(776));
    });

    test('WIFI_LIST: repeated [len][rssi][ssid]', () {
      final payload = <int>[
        5, 0xD0, ...utf8.encode('Casa'), //
        6, 0xB1, ...utf8.encode('Niño'),
        1, 0xC0,
      ];
      final networks = parseBlufiWifiList(payload);
      expect(networks.map((n) => n.ssid), <String>['Casa', 'Niño', '']);
      expect(networks.map((n) => n.rssi), <int>[-48, -79, -64]);
    });

    test('WIFI_LIST: a broken tail is dropped, bad UTF-8 replaced', () {
      expect(
        parseBlufiWifiList(<int>[5, 0xD0, ...utf8.encode('Casa'), 9, 0xC0])
            .map((n) => n.ssid),
        <String>['Casa'],
      );
      expect(
        parseBlufiWifiList(const <int>[3, 0xC0, 0xFF, 0x41]).single.ssid,
        '�A',
      );
    });

    test('WIFI_REP: the station state', () {
      expect(
        blufiWifiReportState(const <int>[1, 0, 0, 0x02, 0x01, 0x43]),
        BlufiStaState.connected,
      );
      expect(blufiWifiReportState(const <int>[1, 1, 0]), BlufiStaState.failed);
      expect(blufiWifiReportState(const <int>[1]), isNull);
    });
  });
}
