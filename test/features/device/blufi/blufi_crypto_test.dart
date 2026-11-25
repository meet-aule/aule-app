import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:aule/features/device/blufi/blufi_crypto.dart';
import 'package:aule/features/device/blufi/ffdhe3072.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List hex(String text) => Uint8List.fromList(<int>[
  for (var i = 0; i < text.length; i += 2)
    int.parse(text.substring(i, i + 2), radix: 16),
]);

final _key = hex(
  '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f',
);
final _iv = hex('8daaf46408d5e3a167cd2cdb6e8a15bd');

void main() {
  group('AES-256-CTR', () {
    test('NIST SP 800-38A, F.5.5 (CTR-AES256.Encrypt)', () {
      final cipher = AesCtrBlufiCipher(
        key: hex(
          '603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4',
        ),
        iv: hex('f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff'),
      );
      final plain = hex(
        '6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51'
        '30c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710',
      );
      expect(
        cipher.apply(plain),
        hex(
          '601ec313775789a5b7a7f504bbf3d228f443e3ca4d62b59aca84e990cacaf5c5'
          '2b0930daa23de94ce87017ba2d84988ddfc9c58db67aada613c2dd08457941a6',
        ),
      );
    });

    test('the counter carries across all 16 bytes, as PSA_ALG_CTR does', () {
      // From OpenSSL: the second block uses the counter 00..01 00..00.
      final cipher = AesCtrBlufiCipher(
        key: _key,
        iv: hex('0000000000000000ffffffffffffffff'),
      );
      expect(
        cipher.apply(Uint8List(32)),
        hex(
          'a6fbdb5cfde07d1b58fd362177bcffdf'
          '511dd5ef9a682b7da49f91c86c4f7ac3',
        ),
      );
    });

    test('one stream per direction: abc then defgh is abcdefgh at once', () {
      final once = AesCtrBlufiCipher(
        key: _key,
        iv: _iv,
      ).apply(ascii.encode('abcdefgh'));
      final stream = AesCtrBlufiCipher(key: _key, iv: _iv);
      final parts = <int>[
        ...stream.apply(ascii.encode('abc')),
        ...stream.apply(ascii.encode('defgh')),
      ];
      expect(parts, once);
      expect(stream.offset, 8);
    });

    test('the stream continues across blocks, from any offset', () {
      final once = AesCtrBlufiCipher(key: _key, iv: _iv).apply(Uint8List(80));
      final stream = AesCtrBlufiCipher(key: _key, iv: _iv);
      final parts = <int>[
        for (final size in const <int>[5, 11, 16, 1, 30, 17])
          ...stream.apply(Uint8List(size)),
      ];
      expect(parts, once);
    });

    test('decrypting is applying the same stream', () {
      final phone = AesCtrBlufiCipher(key: _key, iv: _iv);
      final device = AesCtrBlufiCipher(key: _key, iv: _iv);
      final secret = ascii.encode('aule1234');
      final sent = phone.apply(secret);
      expect(sent, isNot(secret));
      expect(device.apply(sent), secret);
    });

    test('a destroyed cipher cannot be used', () {
      final cipher = AesCtrBlufiCipher(key: _key, iv: _iv)..destroy();
      expect(() => cipher.apply(const <int>[1]), throwsStateError);
    });

    test('the key and the IV have fixed sizes', () {
      expect(
        () => AesCtrBlufiCipher(key: Uint8List(16), iv: _iv),
        throwsArgumentError,
      );
      expect(
        () => AesCtrBlufiCipher(key: _key, iv: Uint8List(12)),
        throwsArgumentError,
      );
    });
  });

  group('the key exchange', () {
    test('two local key pairs agree on Z', () {
      final random = Random(7);
      final phone = BlufiKeyPair.generate(random);
      final device = BlufiKeyPair.generate(random);
      expect(phone.publicKey, hasLength(Ffdhe3072.length));
      final phoneSecret = phone.sharedSecret(device.publicKey);
      final deviceSecret = device.sharedSecret(phone.publicKey);
      expect(phoneSecret, hasLength(Ffdhe3072.length));
      expect(phoneSecret, deviceSecret);

      final phoneKeys = BlufiKeys.derive(phoneSecret);
      final deviceKeys = BlufiKeys.derive(deviceSecret);
      expect(phoneKeys.key, deviceKeys.key);
      // What the phone encrypts, the device decrypts, and the other way.
      final toDevice = phoneKeys.phoneToDevice();
      final atDevice = AesCtrBlufiCipher(
        key: deviceKeys.key,
        iv: deviceKeys.ivPhoneToDevice,
      );
      final ssid = utf8.encode('Casa');
      expect(atDevice.apply(toDevice.apply(ssid)), ssid);
      expect(phoneKeys.ivPhoneToDevice, isNot(phoneKeys.ivDeviceToPhone));
    });

    test('A is 2^a mod P', () {
      final pair = BlufiKeyPair.fromPrivate(BigInt.from(5));
      expect(bigIntFromBytes(pair.publicKey), BigInt.from(32));
      expect(pair.publicKey.sublist(0, 383), everyElement(0));
    });

    test('a short Z is left-padded to 384 bytes', () {
      final pair = BlufiKeyPair.fromPrivate(BigInt.one);
      final shared = pair.sharedSecret(bigIntToBytes(BigInt.two, 384));
      expect(shared, hasLength(384));
      expect(shared.sublist(0, 383), everyElement(0));
      expect(shared.last, 2);
    });

    test('the key and the IVs follow §8.2', () {
      // Golden values for Z = 2, padded to 384 bytes, from Python's hashlib.
      final shared = Uint8List(384)..[383] = 2;
      final keys = BlufiKeys.derive(shared);
      expect(
        keys.key,
        hex('0c29b032a70f848d7ce809f1c926afaea4bce7b3a037ad74b39861c19eb0161c'),
      );
      expect(keys.ivPhoneToDevice, hex('8daaf46408d5e3a167cd2cdb6e8a15bd'));
      expect(keys.ivDeviceToPhone, hex('88ed25c21404d19c0209aa3692ab1022'));
      expect(shared, everyElement(0), reason: 'Z is zeroed once it is used');
    });

    test('a public value out of range is refused', () {
      final p = Ffdhe3072.prime;
      for (final bad in <BigInt>[BigInt.zero, BigInt.one, p - BigInt.one]) {
        final pair = BlufiKeyPair.fromPrivate(BigInt.from(3));
        expect(
          () => pair.sharedSecret(bigIntToBytes(bad, 384)),
          throwsFormatException,
        );
      }
      final pair = BlufiKeyPair.fromPrivate(BigInt.from(3));
      expect(() => pair.sharedSecret(Uint8List(383)), throwsFormatException);
    });

    test('a key pair is used once', () {
      final pair = BlufiKeyPair.fromPrivate(BigInt.from(3));
      final peer = BlufiKeyPair.fromPrivate(BigInt.from(4)).publicKey;
      pair.sharedSecret(peer);
      expect(() => pair.sharedSecret(peer), throwsStateError);
    });

    test('big-endian helpers', () {
      expect(bigIntToBytes(BigInt.from(0x0102), 4), <int>[0, 0, 1, 2]);
      expect(bigIntFromBytes(const <int>[0, 0, 1, 2]), BigInt.from(0x0102));
      expect(
        () => bigIntToBytes(BigInt.from(0x010203), 2),
        throwsArgumentError,
      );
    });
  });
}
