import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_car_key_app/types/ble_commands.dart';
import 'package:open_car_key_app/types/features.dart';
import 'package:open_car_key_app/utils/esp32_response_parser.dart';

/// Responses are not authenticated, anything in BLE range could send them.
/// Malformed ones must never crash the app or be read past their end.
void main() {
  List<int> withFloat(int command, double value) {
    final data = ByteData(4)..setFloat32(0, value, Endian.little);
    return [command, 4, ...data.buffer.asUint8List()];
  }

  test('reads a float response', () {
    final parser = Esp32ResponseParser(withFloat(0x06, -61.5));
    expect(parser.command, Esp32Response.RSSI.value);
    expect(parser.getFloat(), -61.5);
  });

  test('reads a version string', () {
    final parser = Esp32ResponseParser([0x01, 2, 0x56, 0x35]);
    expect(parser.getString(), 'V5');
  });

  test('reads a features bitmask', () {
    final parser = Esp32ResponseParser([0x07, 4, 0x05, 0, 0, 0]);
    expect(featuresFromMask(parser.getInt32()!),
        {Feature.doorsLock, Feature.engine});
  });

  test('handles empty and command-only responses', () {
    expect(Esp32ResponseParser([]).hasData, isFalse);
    expect(Esp32ResponseParser([]).rawData, isNull);
    expect(Esp32ResponseParser([0x02]).rawData, isNull);
    expect(Esp32ResponseParser([0x02]).getFloat(), isNull);
  });

  test('rejects a length byte longer than the data', () {
    final parser = Esp32ResponseParser([0x06, 8, 1, 2, 3, 4]);
    expect(parser.rawData, isNull);
    expect(parser.getFloat(), isNull);
  });

  test('rejects data of the wrong size for the type', () {
    expect(Esp32ResponseParser([0x06, 2, 1, 2]).getFloat(), isNull);
    expect(Esp32ResponseParser([0x07, 2, 1, 2]).getInt32(), isNull);
    expect(Esp32ResponseParser([0x07, 4, 1, 2, 3, 4]).getInt16(), isNull);
  });

  test('ignores bytes after the declared length', () {
    final parser = Esp32ResponseParser([0x01, 2, 0x56, 0x35, 0xFF, 0xFF]);
    expect(parser.getString(), 'V5');
  });

  test('invalid UTF-8 does not throw', () {
    expect(Esp32ResponseParser([0x01, 2, 0xC3, 0x28]).getString(), isNull);
  });

  test('every short garbage response is handled without throwing', () {
    for (var length = 0; length <= 8; length++) {
      for (var lengthByte = 0; lengthByte <= 255; lengthByte += 5) {
        final value = List<int>.filled(length, 0x41);
        if (length > 1) value[1] = lengthByte;
        final parser = Esp32ResponseParser(value);
        expect(() {
          parser.rawData;
          parser.getString();
          parser.getFloat();
          parser.getInt32();
          parser.getUint32();
          parser.getInt16();
          parser.getUint16();
          parser.getByte();
          parser.getBool();
        }, returnsNormally);
      }
    }
  });

  test('unknown response codes are not mapped to a response', () {
    expect(Esp32Response.fromValue(0x0C), isNull);
    expect(Esp32Response.fromValue(0xFF), isNull);
  });

  test('client command values match the firmware', () {
    // Firmware/LockController/lib/OckCore/src/OckProtocol.h
    const firmware = {
      'GET_VERSION': 0x00,
      'GET_DATA': 0x01,
      'LOCK_DOORS': 0x02,
      'UNLOCK_DOORS': 0x03,
      'OPEN_TRUNK': 0x04,
      'START_ENGINE': 0x05,
      'STOP_ENGINE': 0x06,
      'PROXIMITY_KEY_ON': 0x07,
      'PROXIMITY_KEY_OFF': 0x08,
      'PROXIMITY_COOLDOWN': 0x09,
      'RSSI_TRIGGER': 0x0A,
      'GET_RSSI': 0x0B,
      'GET_FEATURES': 0x0C,
      'OPEN_WINDOWS': 0x0D,
      'CLOSE_WINDOWS': 0x0E,
    };
    expect({for (final c in ClientCommand.values) c.name: c.value}, firmware);
  });

  test('response values match the firmware', () {
    const firmware = {
      'INVALID_HMAC': 0x00,
      'VERSION': 0x01,
      'LOCKED': 0x02,
      'PROXIMITY_LOCKED': 0x03,
      'UNLOCKED': 0x04,
      'PROXIMITY_UNLOCKED': 0x05,
      'RSSI': 0x06,
      'FEATURES': 0x07,
      'ENGINE_STARTED': 0x08,
      'ENGINE_STOPPED': 0x09,
      'WINDOWS_OPENED': 0x0A,
      'WINDOWS_CLOSED': 0x0B,
    };
    expect({for (final r in Esp32Response.values) r.name: r.value}, firmware);
  });
}
