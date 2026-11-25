import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:aule/features/device/blufi/blufi_frame.dart';
import 'package:aule/features/device/blufi/blufi_session.dart';
import 'package:aule/features/device/provisioning/wifi_provisioner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_blufi_device.dart';

const _credentials = WifiCredentials(ssid: 'Casa', password: 'aule1234');

Matcher _provisionFailure(ProvisionFailure failure, {int? code}) =>
    isA<ProvisionException>()
        .having((e) => e.failure, 'failure', failure)
        .having((e) => e.deviceErrorCode, 'deviceErrorCode', code);

bool _contains(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

void main() {
  for (final mtu in const <int>[23, 517]) {
    test(
      'at MTU $mtu: handshake, networks, then a join that connects',
      () async {
        final device = FakeBlufiDevice(mtu: mtu);
        final session = BlufiSession(device, random: Random(1));
        addTearDown(session.close);

        await session.handshake();
        final networks = await session.networks();
        expect(networks.map((n) => n.ssid), <String>['Casa', 'Vecino']);
        expect(networks.map((n) => n.rssi), <int>[-48, -80]);

        expect(await session.join(_credentials), WifiResult.connected);
        expect(device.receivedSsid, 'Casa');
        expect(device.receivedPassword, 'aule1234');
      },
    );
  }

  test('the phone numbers its frames from 0, fragments included', () async {
    final device = FakeBlufiDevice(mtu: 23);
    final session = BlufiSession(device, random: Random(2));
    addTearDown(session.close);
    await session.handshake();
    final seqs = device.written.map((frame) => frame[2]).toList();
    expect(seqs, List<int>.generate(seqs.length, (i) => i));
    // NEG length (1 frame), NEG parameters (776 bytes, 65 frames at MTU
    // 23), then SET_SEC_MODE.
    expect(seqs, hasLength(67));
    expect(device.written.first[0], BlufiType.negotiate);
    expect(device.written.last, <int>[
      BlufiType.setSecurityMode,
      BlufiFc.checksum,
      66,
      1,
      blufiSecurityMode,
      ...device.written.last.sublist(5),
    ]);
  });

  test('every phone frame has a checksum; data is encrypted after the '
      'handshake', () async {
    final device = FakeBlufiDevice(mtu: 517);
    final session = BlufiSession(device, random: Random(3));
    addTearDown(session.close);
    await session.handshake();
    final before = device.written.length;
    await session.join(_credentials);
    for (final frame in device.written) {
      expect(frame[1] & BlufiFc.checksum, BlufiFc.checksum);
      expect(frame[1] & BlufiFc.ackRequested, 0);
    }
    final join = device.written.sublist(before);
    expect(join.map((frame) => frame[0]), <int>[
      BlufiType.staSsid,
      BlufiType.staPassword,
      BlufiType.connectToAp,
    ]);
    expect(join.map((frame) => frame[1]), <int>[0x03, 0x03, 0x02]);
  });

  test('the SSID and the password never travel in the clear', () async {
    final device = FakeBlufiDevice(mtu: 517);
    final session = BlufiSession(device, random: Random(4));
    addTearDown(session.close);
    await session.handshake();
    await session.join(_credentials);
    final travelled = <int>[for (final frame in device.written) ...frame];
    expect(_contains(travelled, utf8.encode('aule1234')), isFalse);
    expect(_contains(travelled, utf8.encode('Casa')), isFalse);
  });

  test('a wrong password is a failed join, and the session goes on', () async {
    final device = FakeBlufiDevice();
    final session = BlufiSession(device, random: Random(5));
    addTearDown(session.close);
    await session.handshake();
    expect(
      await session.join(
        const WifiCredentials(ssid: 'Casa', password: 'wrong-one'),
      ),
      WifiResult.failed,
    );
    expect(session.isOpen, isTrue);
    expect(await session.join(_credentials), WifiResult.connected);
  });

  test('an open network sends an empty password', () async {
    final device = FakeBlufiDevice(password: '');
    final session = BlufiSession(device, random: Random(6));
    addTearDown(session.close);
    await session.handshake();
    expect(
      await session.join(const WifiCredentials(ssid: 'Casa', password: '')),
      WifiResult.connected,
    );
    expect(device.receivedPassword, '');
  });

  test('the link dropping after CONN_TO_AP is probably connected', () async {
    final device = FakeBlufiDevice(dropAfterConnect: true);
    final session = BlufiSession(device, random: Random(7));
    addTearDown(session.close);
    await session.handshake();
    expect(await session.join(_credentials), WifiResult.probablyConnected);
  });

  test('ERROR_INFO 11 from the Wi-Fi scan is an empty list', () async {
    final device = FakeBlufiDevice(networks: const <(String, int)>[]);
    final session = BlufiSession(device, random: Random(8));
    addTearDown(session.close);
    await session.handshake();
    expect(await session.networks(), isEmpty);
  });

  test('a device error during the handshake carries its code', () async {
    final device = FakeBlufiDevice(negotiationError: 6);
    final session = BlufiSession(device, random: Random(9));
    addTearDown(session.close);
    await expectLater(
      session.handshake(),
      throwsA(_provisionFailure(ProvisionFailure.handshakeFailed, code: 6)),
    );
  });

  test('a device that never answers times out', () async {
    final device = FakeBlufiDevice(silent: true);
    final session = BlufiSession(
      device,
      random: Random(10),
      timeouts: const BlufiTimeouts(negotiation: Duration(milliseconds: 50)),
    );
    addTearDown(session.close);
    await expectLater(
      session.handshake(),
      throwsA(_provisionFailure(ProvisionFailure.timeout)),
    );
  });

  test('a link that drops during the handshake fails to connect', () async {
    final device = FakeBlufiDevice(silent: true);
    final session = BlufiSession(device, random: Random(11));
    addTearDown(session.close);
    final handshake = session.handshake();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    device.drop();
    await expectLater(
      handshake,
      throwsA(_provisionFailure(ProvisionFailure.connectFailed)),
    );
    expect(session.isOpen, isFalse);
  });

  test('networks and join need the handshake first', () async {
    final session = BlufiSession(FakeBlufiDevice(), random: Random(12));
    addTearDown(session.close);
    await expectLater(session.networks(), throwsStateError);
  });

  test('close is safe twice and drops the link', () async {
    final device = FakeBlufiDevice();
    final session = BlufiSession(device, random: Random(13));
    await session.handshake();
    await session.close();
    await session.close();
    expect(device.connected, isFalse);
    expect(session.isOpen, isFalse);
  });

  test('a frame with a wrong checksum breaks the session', () async {
    final device = _CorruptingDevice();
    final session = BlufiSession(device, random: Random(14));
    addTearDown(session.close);
    await session.handshake();
    await expectLater(
      session.networks(),
      throwsA(_provisionFailure(ProvisionFailure.deviceError)),
    );
    expect(session.isOpen, isFalse);
  });
}

/// Flips one byte of the device's encrypted frames.
class _CorruptingDevice extends FakeBlufiDevice {
  @override
  Stream<Uint8List> get notifications => super.notifications.map((frame) {
    if ((frame[1] & BlufiFc.encrypted) == 0) return frame;
    final copy = Uint8List.fromList(frame);
    copy[4] ^= 0x01;
    return copy;
  });
}
