import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_car_key_app/types/ble_commands.dart';
import 'package:open_car_key_app/utils/rolling_code.dart';

Uint8List hex(String value) => Uint8List.fromList([
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ]);

String toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List floats(List<double> values) {
  final data = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    data.setFloat32(i * 4, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Same vectors as the firmware tests
/// (Firmware/LockController/test/test_native/test_protocol_vectors.cpp), so a
/// format change on either side fails both. Session nonce 00 01 02 .. 0f.
class Vector {
  final int counter;
  final ClientCommand command;
  final Uint8List? data;
  final String payloadHex;

  const Vector(this.counter, this.command, this.data, this.payloadHex);
}

void main() {
  const password = 'test-password-123';
  final secret = generateSharedSecret(password);
  final nonce = Uint8List.fromList(List.generate(16, (i) => i));
  final otherNonce = Uint8List.fromList(List.generate(16, (i) => 0xa0 + i));

  final vectors = [
    Vector(0, ClientCommand.GET_VERSION, null,
        '3c37ac333b824b7df95862ec548ccbec7b60d224df59bc5de79ff280badc28c000'),
    Vector(1, ClientCommand.UNLOCK_DOORS, null,
        '34782e85685117cc37538f8e5e5e5c3669576afbe74e609c220549e045202be803'),
    Vector(0x12345678, ClientCommand.LOCK_DOORS, null,
        '4566e919f06eaa93d387971695d99a34cfca7e41e4d524c178afcfaec0c62efe02'),
    Vector(42, ClientCommand.PROXIMITY_COOLDOWN, floats([1.5]),
        'fba234c51edee1082dfd048152354afb8b5242a6424e0b70320246b2b6f5073409040000c03f'),
    Vector(43, ClientCommand.RSSI_TRIGGER, floats([-60, 4]),
        '444f924f61e2a704fd1a8a42d122447d136f7eae6b51fbddc87f50013e66e8bf0a08000070c200008040'),
  ];

  group('shared secret', () {
    test('is SHA-256 of the password, like the firmware', () {
      expect(toHex(secret),
          '7c13ab2e1d157284ccb11e9737f90cbb611b0acdb8f8dcd4e303a680e58a8b1b');
    });

    test('ignores NUL characters (C strings end there)', () {
      expect(generateSharedSecret('test-password\u0000-123'), secret);
    });
  });

  group('payload', () {
    test('matches the firmware test vectors byte for byte', () {
      for (final v in vectors) {
        final payload = buildCommandPayload(nonce, v.counter, v.command, secret,
            additionalData: v.data);
        expect(toHex(payload), v.payloadHex, reason: v.command.name);
      }
    });

    test('layout is HMAC + command (+ length + data)', () {
      final data = floats([-60, 4]);
      final payload = buildCommandPayload(
          nonce, 7, ClientCommand.RSSI_TRIGGER, secret,
          additionalData: data);
      expect(payload.length, 32 + 1 + 1 + 8);
      expect(payload[32], ClientCommand.RSSI_TRIGGER.value);
      expect(payload[33], 8);
      expect(payload.sublist(34), data);

      final noData =
          buildCommandPayload(nonce, 7, ClientCommand.UNLOCK_DOORS, secret);
      expect(noData.length, 33);
      expect(noData[32], ClientCommand.UNLOCK_DOORS.value);
    });

    test('empty data is sent as no data', () {
      expect(
        buildCommandPayload(nonce, 3, ClientCommand.GET_DATA, secret,
            additionalData: Uint8List(0)),
        buildCommandPayload(nonce, 3, ClientCommand.GET_DATA, secret),
      );
    });
  });

  group('HMAC', () {
    test('input is nonce + counter (little endian) + command + length + data',
        () {
      final input = buildHmacInput(
          nonce, 0x12345678, ClientCommand.PROXIMITY_COOLDOWN,
          additionalData: hex('aabbccdd'));
      expect(toHex(input),
          '000102030405060708090a0b0c0d0e0f' '78563412' '09' '04' 'aabbccdd');

      expect(toHex(buildHmacInput(nonce, 1, ClientCommand.UNLOCK_DOORS)),
          '000102030405060708090a0b0c0d0e0f' '01000000' '03');
    });

    test('is tied to the session nonce', () {
      // A message made for another connection (e.g. a fake vehicle) must not
      // be valid on this one
      expect(generateHmac(nonce, 5, ClientCommand.UNLOCK_DOORS, secret),
          isNot(generateHmac(otherNonce, 5, ClientCommand.UNLOCK_DOORS, secret)));
    });

    test('nonce has to be exactly 16 bytes', () {
      for (final length in [0, 15, 17, 32]) {
        expect(
            () => buildCommandPayload(
                Uint8List(length), 1, ClientCommand.UNLOCK_DOORS, secret),
            throwsArgumentError,
            reason: 'length $length');
      }
    });

    test('covers the additional data', () {
      // Otherwise anyone holding a valid RSSI_TRIGGER could put in their own range
      final real = generateHmac(nonce, 5, ClientCommand.RSSI_TRIGGER, secret,
          additionalData: floats([-60, 4]));
      final swapped = generateHmac(
          nonce, 5, ClientCommand.RSSI_TRIGGER, secret,
          additionalData: floats([-200, 4]));
      final none = generateHmac(nonce, 5, ClientCommand.RSSI_TRIGGER, secret);
      expect(real, isNot(swapped));
      expect(real, isNot(none));
    });

    test('changes with counter, command and secret', () {
      final base = generateHmac(nonce, 5, ClientCommand.UNLOCK_DOORS, secret);
      expect(base,
          isNot(generateHmac(nonce, 6, ClientCommand.UNLOCK_DOORS, secret)));
      expect(base,
          isNot(generateHmac(nonce, 5, ClientCommand.LOCK_DOORS, secret)));
      expect(
          base,
          isNot(generateHmac(nonce, 5, ClientCommand.UNLOCK_DOORS,
              generateSharedSecret('another-password-456'))));
    });

    test('is a standard HMAC-SHA256', () {
      final expected = Hmac(sha256, secret)
          .convert(buildHmacInput(nonce, 9, ClientCommand.OPEN_TRUNK))
          .bytes;
      expect(generateHmac(nonce, 9, ClientCommand.OPEN_TRUNK, secret), expected);
    });
  });

  group('limits', () {
    test('counters outside uint32 are refused instead of wrapping', () {
      expect(
          () => buildCommandPayload(nonce, -1, ClientCommand.GET_DATA, secret),
          throwsRangeError);
      expect(
          () => buildCommandPayload(
              nonce, maxCounter + 1, ClientCommand.GET_DATA, secret),
          throwsRangeError);
      // 2^32 would otherwise wrap to counter 0 and repeat the very first message
      expect(
          () => buildCommandPayload(
              nonce, 0x100000000, ClientCommand.GET_DATA, secret),
          throwsRangeError);
      expect(
          buildCommandPayload(nonce, maxCounter, ClientCommand.GET_DATA, secret),
          hasLength(33));
    });

    test('too much data is refused instead of being cut off', () {
      expect(
        () => buildCommandPayload(nonce, 1, ClientCommand.RSSI_TRIGGER, secret,
            additionalData: Uint8List(maxAdditionalDataLength + 1)),
        throwsArgumentError,
      );
      expect(
        buildCommandPayload(nonce, 1, ClientCommand.RSSI_TRIGGER, secret,
            additionalData: Uint8List(maxAdditionalDataLength)),
        hasLength(34 + maxAdditionalDataLength),
      );
    });
  });

  group('password validation', () {
    test('requires the same minimum length as the firmware', () {
      expect(minPasswordLength, 12);
      expect(validatePassword(null), isNotNull);
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('   '), isNotNull);
      expect(validatePassword('abc123'), isNotNull);
      expect(validatePassword('12345678901'), isNotNull);
      expect(validatePassword('  12345678901  '), isNotNull);
      expect(validatePassword('123456789012'), isNull);
    });
  });

  test('UTF-8 passwords hash like the firmware', () {
    // The firmware hashes the raw bytes of the PASSWORD string literal (UTF-8)
    expect(generateSharedSecret('pässwörd-ünicode'),
        sha256.convert(utf8.encode('pässwörd-ünicode')).bytes);
  });
}
