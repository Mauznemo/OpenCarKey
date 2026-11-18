import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_car_key_app/services/ble_service.dart';
import 'package:open_car_key_app/types/background_vehicle.dart';
import 'package:open_car_key_app/types/vehicle_data.dart';
import 'package:open_car_key_app/types/vehicle_session.dart';
import 'package:open_car_key_app/utils/rolling_code.dart';

/// Session info the vehicle sets in ffe2: nonce + counter (uint32 LE)
List<int> sessionInfo(List<int> nonce, int counter) {
  final counterBytes = ByteData(4)..setUint32(0, counter, Endian.little);
  return [...nonce, ...counterBytes.buffer.asUint8List()];
}

/// The app takes nonce and counter from the vehicle for every connection and
/// keeps no counter of its own. These tests make sure a session is read once
/// per connection, counters are never handed out twice and nothing is sent
/// with a session that is broken or belongs to another connection.
void main() {
  final nonce = List.generate(16, (i) => i);
  final otherNonce = List.generate(16, (i) => 0xa0 + i);

  BackgroundVehicle createVehicle() => BackgroundVehicle(
    device: BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'),
    data: VehicleData(
      name: 'Test',
      macAddress: 'AA:BB:CC:DD:EE:FF',
      sharedSecret: generateSharedSecret('test-password-123'),
      features: {},
    ),
  );

  group('session info', () {
    test('is nonce (16 bytes) + counter (uint32 little endian)', () {
      final session = parseSessionInfo([...nonce, 0x78, 0x56, 0x34, 0x12]);
      expect(session.nonce, nonce);
      expect(session.nextCounter, 0x12345678);

      expect(
        parseSessionInfo(sessionInfo(nonce, 0xFFFFFFFF)).nextCounter,
        maxCounter,
      );
    });

    test('a wrong length is an error, not silently accepted', () {
      for (final length in [0, 4, 16, 19, 21, 32]) {
        expect(
          () => parseSessionInfo(List.filled(length, 1)),
          throwsFormatException,
          reason: 'length $length',
        );
      }
    });

    test('an all zero nonce is an error', () {
      expect(
        () => parseSessionInfo(sessionInfo(List.filled(16, 0), 3)),
        throwsFormatException,
      );
    });

    test('the nonce is a copy of the read value', () {
      final value = sessionInfo(nonce, 1);
      final session = parseSessionInfo(value);
      value[0] = 0xff;
      expect(session.nonce, nonce);
    });
  });

  group('counters', () {
    test('start at the vehicle counter and count up', () {
      final session = VehicleSession(
        nonce: Uint8List.fromList(nonce),
        nextCounter: 41,
      );
      expect(session.takeCounter(), 41);
      expect(session.takeCounter(), 42);
      expect(session.takeCounter(), 43);
      expect(session.nextCounter, 44);
    });

    test('are never handed out twice', () {
      final session = VehicleSession(
        nonce: Uint8List.fromList(nonce),
        nextCounter: 0,
      );
      final counters = List.generate(100, (_) => session.takeCounter());
      expect(counters.toSet(), hasLength(100));
    });
  });

  group('getSession', () {
    test('reads the session once per connection', () async {
      final vehicle = createVehicle();
      var reads = 0;
      Future<List<int>?> read() async {
        reads++;
        return sessionInfo(nonce, 7);
      }

      final first = await BleService.getSession(
        vehicle,
        read,
        onUnsupported: () {},
      );
      expect(first!.takeCounter(), 7);
      final second = await BleService.getSession(
        vehicle,
        read,
        onUnsupported: () {},
      );
      expect(second!.takeCounter(), 8);
      expect(reads, 1);
    });

    test('a forgotten session is read again with the new nonce', () async {
      // What happens on reconnect, disconnect and INVALID_HMAC
      final vehicle = createVehicle();
      await BleService.getSession(
        vehicle,
        () async => sessionInfo(nonce, 7),
        onUnsupported: () {},
      );

      vehicle.forgetSession();
      expect(vehicle.session, isNull);
      final next = await BleService.getSession(
        vehicle,
        () async => sessionInfo(otherNonce, 3),
        onUnsupported: () {},
      );
      expect(next!.nonce, otherNonce);
      expect(next.takeCounter(), 3);
    });

    test('INVALID_HMAC only drops the session', () async {
      final vehicle = createVehicle();
      await BleService.getSession(
        vehicle,
        () async => sessionInfo(nonce, 7),
        onUnsupported: () {},
      );
      vehicle.session = null;
      final healed = await BleService.getSession(
        vehicle,
        () async => sessionInfo(nonce, 20),
        onUnsupported: () {},
      );
      expect(healed!.takeCounter(), 20);
    });

    test('a broken session is not cached and not used', () async {
      final vehicle = createVehicle();
      await expectLater(
        BleService.getSession(
          vehicle,
          () async => [1, 2, 3],
          onUnsupported: () {},
        ),
        throwsFormatException,
      );
      expect(vehicle.session, isNull);
    });

    test('old firmware is reported once per connection', () async {
      final vehicle = createVehicle();
      var reports = 0;
      var reads = 0;
      Future<List<int>?> read() async {
        reads++;
        return null;
      }

      for (var i = 0; i < 3; i++) {
        expect(
          await BleService.getSession(
            vehicle,
            read,
            onUnsupported: () => reports++,
          ),
          isNull,
        );
      }
      expect(reports, 1);
      expect(reads, 1);

      // A new connection checks again (the firmware may have been updated)
      vehicle.forgetSession();
      expect(
        await BleService.getSession(
          vehicle,
          read,
          onUnsupported: () => reports++,
        ),
        isNull,
      );
      expect(reports, 2);
    });
  });
}
