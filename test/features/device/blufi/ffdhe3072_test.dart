import 'package:aule/features/device/blufi/blufi_crypto.dart';
import 'package:aule/features/device/blufi/ffdhe3072.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the prime is 384 bytes, with FF in its first and last eight', () {
    final bytes = Ffdhe3072.primeBytes();
    expect(bytes, hasLength(384));
    expect(bytes.sublist(0, 8), everyElement(0xFF));
    expect(bytes.sublist(376), everyElement(0xFF));
    expect(Ffdhe3072.prime.bitLength, 3072);
    expect(bigIntToBytes(Ffdhe3072.prime, Ffdhe3072.length), bytes);
  });

  test(
    'it is RFC 7919: 2^3072 - 2^3008 + {[2^2942 * e] + 2625351} * 2^64 - 1',
    () {
      // floor(2^2942 * e), with e = sum of 1/k! for k = 0..600. The terms left
      // out are far below 2^-2942.
      const terms = 600;
      var factorial = BigInt.one;
      for (var k = 2; k <= terms; k++) {
        factorial *= BigInt.from(k);
      }
      var sum = BigInt.zero;
      var term = factorial;
      for (var k = 0; k <= terms; k++) {
        sum += term;
        if (k < terms) term = term ~/ BigInt.from(k + 1);
      }
      final eFloor = (BigInt.two.pow(2942) * sum) ~/ factorial;
      final p =
          BigInt.two.pow(3072) -
          BigInt.two.pow(3008) +
          (eFloor + BigInt.from(2625351)) * BigInt.two.pow(64) -
          BigInt.one;
      expect(Ffdhe3072.prime, p);
    },
  );
}
