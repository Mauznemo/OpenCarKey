import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../types/ble_commands.dart';
import '../types/vehicle_session.dart';

/// Most additional data bytes a command may carry (the firmware rejects more).
const int maxAdditionalDataLength = 12;

/// Shortest password the firmware builds with. Keep in sync with
/// MIN_PASSWORD_LENGTH in Firmware/LockController/lib/OckCore/src/OckPasswordPolicy.h.
const int minPasswordLength = 12;

/// Highest rolling code counter, the firmware stores it as uint32.
const int maxCounter = 0xFFFFFFFF;

/// Derives the 32 byte shared secret from the password, the same way the
/// firmware does: SHA-256 of the UTF-8 password.
Uint8List generateSharedSecret(String password) {
  final cleanedPassword = password.replaceAll('\u0000', '');
  return Uint8List.fromList(sha256.convert(utf8.encode(cleanedPassword)).bytes);
}

/// Validator for the password field when adding a vehicle.
String? validatePassword(String? value) {
  final password = value?.trim() ?? '';
  if (password.isEmpty) {
    return 'Please enter a password';
  }
  if (password.length < minPasswordLength) {
    return 'The password has to be at least $minPasswordLength characters';
  }
  return null;
}

/// Length of the random nonce the vehicle picks for every connection.
const int sessionNonceLength = 16;

/// Length of the session characteristic (ffe2): nonce + counter (uint32).
const int sessionInfoLength = sessionNonceLength + 4;

/// Parses the session characteristic (ffe2) the vehicle sets on every
/// connect: nonce (16 bytes) + its current counter (uint32 little endian).
/// Anything else is an error, a command must never go out with a guessed
/// nonce or counter.
VehicleSession parseSessionInfo(List<int> value) {
  if (value.length != sessionInfoLength) {
    throw FormatException(
      'Session info has to be $sessionInfoLength bytes, got ${value.length}',
    );
  }
  final bytes = Uint8List.fromList(value);
  final nonce = bytes.sublist(0, sessionNonceLength);
  // The vehicle never picks an all zero nonce, that would be a broken value
  if (nonce.every((b) => b == 0)) {
    throw const FormatException('Session info has no nonce');
  }
  return VehicleSession(
    nonce: nonce,
    nextCounter: ByteData.sublistView(
      bytes,
    ).getUint32(sessionNonceLength, Endian.little),
  );
}

/// The bytes the HMAC covers: session nonce (16 bytes) + counter (uint32
/// little endian) + command, plus data length + data if there is data.
/// Covering the data means nobody can swap in their own values (e.g. a
/// different unlock range) into a valid message, and the nonce ties the
/// message to the connection it was made for.
Uint8List buildHmacInput(
  Uint8List nonce,
  int counter,
  ClientCommand command, {
  Uint8List? additionalData,
}) {
  _checkNonce(nonce);
  _checkCounter(counter);
  final data = _checkData(additionalData);

  final builder = BytesBuilder();
  builder.add(nonce);
  builder.add(
    Uint8List(4)..buffer.asByteData().setUint32(0, counter, Endian.little),
  );
  builder.addByte(command.value);
  if (data != null) {
    builder.addByte(data.length);
    builder.add(data);
  }
  return builder.toBytes();
}

/// HMAC-SHA256 of the nonce, counter, command and additional data.
Uint8List generateHmac(
  Uint8List nonce,
  int counter,
  ClientCommand command,
  Uint8List sharedSecret, {
  Uint8List? additionalData,
}) {
  final input = buildHmacInput(
    nonce,
    counter,
    command,
    additionalData: additionalData,
  );
  return Uint8List.fromList(Hmac(sha256, sharedSecret).convert(input).bytes);
}

/// The full message written to the vehicle:
/// 32 byte HMAC + 1 byte command (+ 1 byte data length + data).
Uint8List buildCommandPayload(
  Uint8List nonce,
  int counter,
  ClientCommand command,
  Uint8List sharedSecret, {
  Uint8List? additionalData,
}) {
  final data = _checkData(additionalData);
  final builder = BytesBuilder();
  builder.add(
    generateHmac(nonce, counter, command, sharedSecret, additionalData: data),
  );
  builder.addByte(command.value);
  if (data != null) {
    builder.addByte(data.length);
    builder.add(data);
  }
  return builder.toBytes();
}

void _checkNonce(Uint8List nonce) {
  if (nonce.length != sessionNonceLength) {
    throw ArgumentError.value(
      nonce.length,
      'nonce',
      'The session nonce has to be $sessionNonceLength bytes',
    );
  }
}

void _checkCounter(int counter) {
  // A counter outside uint32 would silently wrap and repeat an old one
  if (counter < 0 || counter > maxCounter) {
    throw RangeError.range(counter, 0, maxCounter, 'counter');
  }
}

/// Empty data is sent as no data. Too much data is an error instead of being
/// cut off, so a command never goes out with different values than intended.
Uint8List? _checkData(Uint8List? data) {
  if (data == null || data.isEmpty) return null;
  if (data.length > maxAdditionalDataLength) {
    throw ArgumentError.value(
      data.length,
      'additionalData',
      'At most $maxAdditionalDataLength bytes are allowed',
    );
  }
  return data;
}
