/// CRC-16/GENIBUS: polynomial 0x1021, initial value 0xFFFF, not reflected,
/// final XOR 0xFFFF. Its check value for ASCII "123456789" is 0xD64E.
///
/// This is what the firmware computes with `esp_crc16_be(0, ...)` for the
/// BluFi checksum. It takes an [Iterable] so that callers can chain bytes
/// without copying them.
int crc16Genibus(Iterable<int> bytes) {
  var crc = 0xFFFF;
  for (final byte in bytes) {
    crc ^= (byte & 0xFF) << 8;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 0x8000) != 0
          ? ((crc << 1) ^ 0x1021) & 0xFFFF
          : (crc << 1) & 0xFFFF;
    }
  }
  return crc ^ 0xFFFF;
}
