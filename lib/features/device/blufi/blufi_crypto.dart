import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart'
    show MacAlgorithm, SecretKeyData;
import 'package:cryptography/dart.dart' show DartAesCtr;

import 'ffdhe3072.dart';

/// The BluFi key exchange and ciphers of the ESP-IDF 6 PSA variant that
/// aule-fw carries (§8.2): Diffie-Hellman in ffdhe3072, SHA-256 for the key
/// and the IVs, and one AES-256-CTR stream per direction.
///
/// Nothing in here is ever logged: not the exponent, the shared secret, the
/// key or the IVs.
abstract final class BlufiCrypto {
  /// Domain of the phone-to-device IV: the device decrypts with it.
  static const phoneToDeviceDomain = 'blufi_dec';

  /// Domain of the device-to-phone IV: the device encrypts with it.
  static const deviceToPhoneDomain = 'blufi_enc';

  /// Bits of the private exponent.
  static const privateBits = 256;
}

/// One side of the key exchange: a private exponent and its public value.
class BlufiKeyPair {
  BlufiKeyPair._(this._private, this.publicKey);

  /// Picks the exponent from 256 random bits ([Random.secure] unless a test
  /// passes its own) and computes `A = 2^a mod P`, left-padded to 384 bytes.
  factory BlufiKeyPair.generate([Random? random]) {
    final source = random ?? Random.secure();
    BigInt exponent;
    do {
      exponent = _randomBits(source, BlufiCrypto.privateBits);
    } while (exponent < BigInt.two);
    return BlufiKeyPair.fromPrivate(exponent);
  }

  /// A key pair with a known exponent, for tests and for a simulated device.
  factory BlufiKeyPair.fromPrivate(BigInt exponent) {
    final publicValue = BigInt.from(Ffdhe3072.generator)
        .modPow(exponent, Ffdhe3072.prime);
    return BlufiKeyPair._(
      exponent,
      bigIntToBytes(publicValue, Ffdhe3072.length),
    );
  }

  BigInt? _private;

  /// The public value, 384 big-endian bytes.
  final Uint8List publicKey;

  /// `Z = B^a mod P` as exactly 384 big-endian bytes, left-padded. The
  /// exponent is dropped once it is used. Throws a [FormatException] when
  /// [peerPublic] is not a valid public value.
  Uint8List sharedSecret(List<int> peerPublic) {
    final exponent = _private;
    if (exponent == null) {
      throw StateError('this key pair was already used');
    }
    final peer = checkedPeerPublic(peerPublic);
    _private = null;
    return bigIntToBytes(
      peer.modPow(exponent, Ffdhe3072.prime),
      Ffdhe3072.length,
    );
  }

  /// Drops the exponent without using it.
  void destroy() => _private = null;
}

/// The other side's public value: exactly 384 bytes, with `1 < B < P - 1`.
BigInt checkedPeerPublic(List<int> bytes) {
  if (bytes.length != Ffdhe3072.length) {
    throw const FormatException('the public value is not 384 bytes');
  }
  final value = bigIntFromBytes(bytes);
  if (value <= BigInt.one || value >= Ffdhe3072.prime - BigInt.one) {
    throw const FormatException('the public value is out of range');
  }
  return value;
}

/// The key and IVs derived from the shared secret (§8.2).
class BlufiKeys {
  BlufiKeys._({
    required this.key,
    required this.ivPhoneToDevice,
    required this.ivDeviceToPhone,
  });

  /// `key = SHA-256(Z)`, `ivPhoneToDevice = SHA-256("blufi_dec" ‖ Z)[0:16]`
  /// and `ivDeviceToPhone = SHA-256("blufi_enc" ‖ Z)[0:16]`.
  ///
  /// Zeroes [sharedSecret] when it is done with it.
  factory BlufiKeys.derive(Uint8List sharedSecret) {
    try {
      return BlufiKeys._(
        key: Uint8List.fromList(sha256.convert(sharedSecret).bytes),
        ivPhoneToDevice: _iv(BlufiCrypto.phoneToDeviceDomain, sharedSecret),
        ivDeviceToPhone: _iv(BlufiCrypto.deviceToPhoneDomain, sharedSecret),
      );
    } finally {
      sharedSecret.fillRange(0, sharedSecret.length, 0);
    }
  }

  static Uint8List _iv(String domain, Uint8List sharedSecret) {
    final label = utf8.encode(domain);
    final material = Uint8List(label.length + sharedSecret.length)
      ..setAll(0, label)
      ..setAll(label.length, sharedSecret);
    try {
      return Uint8List.fromList(sha256.convert(material).bytes.sublist(0, 16));
    } finally {
      material.fillRange(0, material.length, 0);
    }
  }

  /// The AES-256 key, 32 bytes.
  final Uint8List key;
  final Uint8List ivPhoneToDevice;
  final Uint8List ivDeviceToPhone;

  /// The stream the phone encrypts its frames with.
  BlufiCipher phoneToDevice() =>
      AesCtrBlufiCipher(key: key, iv: ivPhoneToDevice);

  /// The stream the phone decrypts the device's frames with.
  BlufiCipher deviceToPhone() =>
      AesCtrBlufiCipher(key: key, iv: ivDeviceToPhone);

  /// Zeroes the key and the IVs. The ciphers keep their own copies.
  void destroy() {
    key.fillRange(0, key.length, 0);
    ivPhoneToDevice.fillRange(0, ivPhoneToDevice.length, 0);
    ivDeviceToPhone.fillRange(0, ivDeviceToPhone.length, 0);
  }
}

/// One direction's cipher. It sits behind this interface so that it can be
/// swapped if a capture from a real board disagrees.
abstract interface class BlufiCipher {
  /// Encrypts or decrypts the next [data] of this direction's stream: CTR is
  /// the same both ways. The stream advances by `data.length`.
  Uint8List apply(List<int> data);

  /// Zeroes the key. The cipher cannot be used after this.
  void destroy();
}

/// AES-256-CTR as PSA_ALG_CTR does it: the 16-byte IV is the whole initial
/// counter block, incremented big-endian across all 16 bytes. One stream
/// covers the whole connection, so each call continues at the byte offset
/// where the previous one stopped.
class AesCtrBlufiCipher implements BlufiCipher {
  AesCtrBlufiCipher({required List<int> key, required List<int> iv})
    : _key = SecretKeyData(
        Uint8List.fromList(key),
        overwriteWhenDestroyed: true,
      ),
      _iv = Uint8List.fromList(iv) {
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'needs 32 bytes');
    }
    if (iv.length != 16) {
      throw ArgumentError.value(iv.length, 'iv', 'needs 16 bytes');
    }
  }

  static const _aes = DartAesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);

  final SecretKeyData _key;
  final Uint8List _iv;
  int _offset = 0;
  bool _destroyed = false;

  /// How many bytes of the stream were used so far.
  int get offset => _offset;

  @override
  Uint8List apply(List<int> data) {
    if (_destroyed) throw StateError('the cipher was destroyed');
    if (data.isEmpty) return Uint8List(0);
    final box = _aes.encryptSync(
      data,
      secretKey: _key,
      nonce: _iv,
      keyStreamIndex: _offset,
    );
    _offset += data.length;
    return Uint8List.fromList(box.cipherText);
  }

  @override
  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    _key.destroy();
    _iv.fillRange(0, _iv.length, 0);
  }
}

/// [value] as exactly [length] big-endian bytes, left-padded with zeros.
Uint8List bigIntToBytes(BigInt value, int length) {
  if (value.isNegative) {
    throw ArgumentError.value(value, 'value', 'is negative');
  }
  final bytes = Uint8List(length);
  final mask = BigInt.from(0xFF);
  var rest = value;
  for (var i = length - 1; i >= 0 && rest > BigInt.zero; i--) {
    bytes[i] = (rest & mask).toInt();
    rest = rest >> 8;
  }
  if (rest > BigInt.zero) {
    throw ArgumentError.value(length, 'length', 'too short for the value');
  }
  return bytes;
}

/// The unsigned big-endian integer in [bytes].
BigInt bigIntFromBytes(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte & 0xFF);
  }
  return value;
}

BigInt _randomBits(Random random, int bits) {
  var value = BigInt.zero;
  for (var i = 0; i < bits ~/ 8; i++) {
    value = (value << 8) | BigInt.from(random.nextInt(256));
  }
  return value;
}
