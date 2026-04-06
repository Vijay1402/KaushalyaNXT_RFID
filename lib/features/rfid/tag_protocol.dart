import 'dart:convert';
import 'dart:typed_data';

enum HealthStatus {
  unknown,
  healthy,
  needsAttention,
  diseased,
  dead,
}

enum Species {
  unknown,
  mango,
  coconut,
  arecanut,
  cashew,
  // add more as needed
}

class TagData {
  // Tag identity:
  // - `epc` (12B) is the Tree ID that we overwrite during WRITE.
  // - `tid` (40B) is the Tag ID that we keep as-is (read from tag; normally read-only).
  final String epc;
  final String tid;

  // Tree ID used by the app, derived from EPC (12B, hex string).
  final String treeId;
  final String farmerName;
  final int lastInspectionUnix; // seconds
  final HealthStatus healthStatus;
  final double lastYieldKg; // will be stored with 1 decimal
  final int treeAgeYears;
  final Species species;

  TagData({
    this.epc = '',
    this.tid = '',
    required this.treeId,
    required this.farmerName,
    required this.lastInspectionUnix,
    required this.healthStatus,
    required this.lastYieldKg,
    required this.treeAgeYears,
    required this.species,
  });
}

int healthStatusToByte(HealthStatus s) => s.index;

HealthStatus healthStatusFromByte(int b) =>
    HealthStatus.values[(b >= 0 && b < HealthStatus.values.length) ? b : 0];

int speciesToByte(Species s) => s.index;

Species speciesFromByte(int b) =>
    Species.values[(b >= 0 && b < Species.values.length) ? b : 0];

Uint8List hexToBytes(String hex) {
  final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  final result = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < clean.length; i += 2) {
    result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
  }
  return result;
}

String bytesToHex(Uint8List bytes) {
  final StringBuffer sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString().toUpperCase();
}

// CRC‑16 (Modbus-style; adjust poly/initial if you need a different variant)
int crc16(Uint8List data, {int poly = 0xA001, int initial = 0xFFFF}) {
  var crc = initial;
  for (final byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      final lsb = crc & 0x0001;
      crc >>= 1;
      if (lsb != 0) crc ^= poly;
    }
  }
  return crc & 0xFFFF;
}

// Encode TagData → hex string for USER bank (86 bytes → 172 hex chars)
String encodeTagData(TagData tag) {
  final bytes = Uint8List(86);
  final view = ByteData.view(bytes.buffer);

  // 0–15: RESERVED in USER memory
  // "Tree ID" is stored in EPC (12B). USER[0..15] is left as zeros.
  bytes.setRange(0, 16, Uint8List(16));

  // 16–47: Farmer name, max 32 chars, UTF‑8, zero‑padded
  final nameBytes = utf8.encode(tag.farmerName);
  final nameLen = nameBytes.length.clamp(0, 32);
  bytes.setRange(16, 16 + nameLen, nameBytes.sublist(0, nameLen));
  // remaining bytes [16+nameLen .. 48) stay 0x00

  // 48–51: Last inspection date (u32)
  view.setUint32(48, tag.lastInspectionUnix, Endian.big);

  // 52: Health status enum
  bytes[52] = healthStatusToByte(tag.healthStatus);

  // 53–54: Last yield (kg * 10, u16)
  final yieldScaled = (tag.lastYieldKg * 10).round().clamp(0, 0xFFFF);
  view.setUint16(53, yieldScaled, Endian.big);

  // 55–56: Tree age (years, u16)
  final age = tag.treeAgeYears.clamp(0, 0xFFFF);
  view.setUint16(55, age, Endian.big);

  // 57: Species enum
  bytes[57] = speciesToByte(tag.species);

  // 58–83: reserved (already 0x00)

  // 84–85: CRC‑16 over bytes 0–83
  final crc = crc16(bytes.sublist(0, 84));
  view.setUint16(84, crc, Endian.big);

  return bytesToHex(bytes); // send to your existing USER‑write API
}

// Decode USER‑bank hex → TagData
TagData decodeTagData(
  String userHex, {
  bool verifyCrc = true,
  String epc = '',
  String tid = '',
}) {
  // Normalize to exactly 86 bytes (172 hex chars) before decoding.
  // Some readers trim trailing 0x00 words; padding lets decoding continue.
  final clean = userHex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  var normalized = clean;
  if (normalized.length.isOdd) {
    normalized = normalized.padRight(normalized.length + 1, '0');
  }

  const expectedBytes = 86;
  const expectedHexLen = expectedBytes * 2; // 2 hex chars per byte
  if (normalized.length < expectedHexLen) {
    normalized = normalized.padRight(expectedHexLen, '0');
  } else if (normalized.length > expectedHexLen) {
    normalized = normalized.substring(0, expectedHexLen);
  }

  final bytes = hexToBytes(normalized);
  if (bytes.length != expectedBytes) {
    throw ArgumentError('USER memory must be exactly $expectedBytes bytes');
  }
  final view = ByteData.view(bytes.buffer);

  // CRC check
  final storedCrc = view.getUint16(84, Endian.big);
  final calcCrc = crc16(bytes.sublist(0, 84));
  if (verifyCrc && storedCrc != calcCrc) {
    throw StateError('CRC mismatch: stored=$storedCrc, calc=$calcCrc');
  }

  // Tree ID is stored in EPC (not USER memory).
  final normalizedEpc =
      epc.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
  final treeId = normalizedEpc;

  // 16–47: Farmer name (trim trailing 0x00)
  final nameRaw = bytes.sublist(16, 48);
  final zeroIndex = nameRaw.indexOf(0x00);
  final nameSlice = zeroIndex == -1 ? nameRaw : nameRaw.sublist(0, zeroIndex);
  final farmerName = utf8.decode(nameSlice, allowMalformed: true);

  // 48–51: Last inspection
  final lastInsp = view.getUint32(48, Endian.big);

  // 52: Health status
  final health = healthStatusFromByte(bytes[52]);

  // 53–54: Last yield
  final yieldScaled = view.getUint16(53, Endian.big);
  final lastYieldKg = yieldScaled / 10.0;

  // 55–56: Tree age
  final ageYears = view.getUint16(55, Endian.big);

  // 57: Species
  final species = speciesFromByte(bytes[57]);

  return TagData(
    epc: epc,
    tid: tid,
    treeId: treeId,
    farmerName: farmerName,
    lastInspectionUnix: lastInsp,
    healthStatus: health,
    lastYieldKg: lastYieldKg,
    treeAgeYears: ageYears,
    species: species,
  );
}
