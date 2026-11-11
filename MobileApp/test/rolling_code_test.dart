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
/// format change on either side fails both.
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

  final vectors = [
    Vector(0, ClientCommand.GET_VERSION, null,
        '205a108405bfe7bd98f1aec14272cf3892fcbe0060f7d2fafd56bbd7c7619d7f00'),
    Vector(1, ClientCommand.UNLOCK_DOORS, null,
        '46ae279cdfc80620fb4001cb1da81ef45adbea942c514d981e6e538e28c6ab3d03'),
    Vector(0x12345678, ClientCommand.LOCK_DOORS, null,
        '4915fbca3febba7b5e65e2bcd880f6a21f95900fde455445ca615d42ceda29db02'),
    Vector(42, ClientCommand.PROXIMITY_COOLDOWN, floats([1.5]),
        'e48ded4cf122555db0324b0fd1470fcb8dd66d35f8fba5971f090a7b8db80dc809040000c03f'),
    Vector(43, ClientCommand.RSSI_TRIGGER, floats([-60, 4]),
        '950f4cef1f7c2af081fb0ab609c7e890897228988e0ba9e3a1bfe7c556b02a8c0a08000070c200008040'),
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
        final payload = buildCommandPayload(v.counter, v.command, secret,
            additionalData: v.data);
        expect(toHex(payload), v.payloadHex, reason: v.command.name);
      }
    });

    test('layout is HMAC + command (+ length + data)', () {
      final data = floats([-60, 4]);
      final payload = buildCommandPayload(
          7, ClientCommand.RSSI_TRIGGER, secret,
          additionalData: data);
      expect(payload.length, 32 + 1 + 1 + 8);
      expect(payload[32], ClientCommand.RSSI_TRIGGER.value);
      expect(payload[33], 8);
      expect(payload.sublist(34), data);

      final noData =
          buildCommandPayload(7, ClientCommand.UNLOCK_DOORS, secret);
      expect(noData.length, 33);
      expect(noData[32], ClientCommand.UNLOCK_DOORS.value);
    });

    test('empty data is sent as no data', () {
      expect(
        buildCommandPayload(3, ClientCommand.GET_DATA, secret,
            additionalData: Uint8List(0)),
        buildCommandPayload(3, ClientCommand.GET_DATA, secret),
      );
    });
  });

  group('HMAC', () {
    test('input is counter (little endian) + command + length + data', () {
      final input = buildHmacInput(0x12345678, ClientCommand.PROXIMITY_COOLDOWN,
          additionalData: hex('aabbccdd'));
      expect(toHex(input), '7856341209' '04' 'aabbccdd');

      expect(toHex(buildHmacInput(1, ClientCommand.UNLOCK_DOORS)),
          '0100000003');
    });

    test('covers the additional data', () {
      // Otherwise anyone holding a valid RSSI_TRIGGER could put in their own range
      final real = generateHmac(5, ClientCommand.RSSI_TRIGGER, secret,
          additionalData: floats([-60, 4]));
      final swapped = generateHmac(5, ClientCommand.RSSI_TRIGGER, secret,
          additionalData: floats([-200, 4]));
      final none = generateHmac(5, ClientCommand.RSSI_TRIGGER, secret);
      expect(real, isNot(swapped));
      expect(real, isNot(none));
    });

    test('changes with counter, command and secret', () {
      final base = generateHmac(5, ClientCommand.UNLOCK_DOORS, secret);
      expect(base, isNot(generateHmac(6, ClientCommand.UNLOCK_DOORS, secret)));
      expect(base, isNot(generateHmac(5, ClientCommand.LOCK_DOORS, secret)));
      expect(
          base,
          isNot(generateHmac(5, ClientCommand.UNLOCK_DOORS,
              generateSharedSecret('another-password-456'))));
    });

    test('is a standard HMAC-SHA256', () {
      final expected = Hmac(sha256, secret)
          .convert(buildHmacInput(9, ClientCommand.OPEN_TRUNK))
          .bytes;
      expect(generateHmac(9, ClientCommand.OPEN_TRUNK, secret), expected);
    });
  });

  group('limits', () {
    test('counters outside uint32 are refused instead of wrapping', () {
      expect(() => buildCommandPayload(-1, ClientCommand.GET_DATA, secret),
          throwsRangeError);
      expect(
          () => buildCommandPayload(
              maxCounter + 1, ClientCommand.GET_DATA, secret),
          throwsRangeError);
      // 2^32 would otherwise wrap to counter 0 and repeat the very first message
      expect(
          () => buildCommandPayload(0x100000000, ClientCommand.GET_DATA, secret),
          throwsRangeError);
      expect(buildCommandPayload(maxCounter, ClientCommand.GET_DATA, secret),
          hasLength(33));
    });

    test('too much data is refused instead of being cut off', () {
      expect(
        () => buildCommandPayload(1, ClientCommand.RSSI_TRIGGER, secret,
            additionalData: Uint8List(maxAdditionalDataLength + 1)),
        throwsArgumentError,
      );
      expect(
        buildCommandPayload(1, ClientCommand.RSSI_TRIGGER, secret,
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
