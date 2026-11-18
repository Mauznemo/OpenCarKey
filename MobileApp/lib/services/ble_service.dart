import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../types/background_vehicle.dart';
import '../types/ble_commands.dart';
import '../types/vehicle_session.dart';
import 'ble_background_service.dart';
import '../utils/esp32_response_parser.dart';
import '../utils/rolling_code.dart';

class BleService {
  /// Protocol version reported for firmware without the session
  /// characteristic, it can't check the messages this app sends.
  static const legacyProtocolVersion = 'V4 or older';

  /// Serializes [sendCommand] per device, so counters are allocated and written
  /// in the same order. Two commands sent at the same time (e.g. a user action
  /// while the post-connect sequence is still running) could otherwise reach
  /// the firmware out of order, and the lower counter is rejected.
  static final Map<String, Future<void>> _sendQueues = {};

  static Future<void> requestBluetoothPermissions() async {
    if (await Permission.bluetoothScan.request().isGranted &&
        await Permission.bluetoothConnect.request().isGranted &&
        await Permission.locationWhenInUse.request().isGranted) {
      print("All Bluetooth permissions granted");
    } else {
      print("Bluetooth permissions denied");
    }
  }

  static Future<bool> scanForDevices() async {
    try {
      await FlutterBluePlus.adapterState
          .where((val) => val == BluetoothAdapterState.on)
          .first;

      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 15),
      );

      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      return true;
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
      return false;
    }
  }

  static Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
    }
  }

  static Future<BluetoothDevice?> connectToDevice(
      BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: true, mtu: null).catchError((e) {
        print('Connection error: $e');
      });

      print(
          'Connected to device: ${device.advName} on isolate ${Isolate.current.hashCode}');

      return device;
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
      return null;
    }
  }

  static Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
    }
  }

  static Future<List<BluetoothDevice>> getConnectedDevices() async {
    try {
      final devices = FlutterBluePlus.connectedDevices;
      return devices;
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
      return [];
    }
  }

  /// Returns the session (nonce + next counter) of the current connection to
  /// [vehicle], reading it with [readSessionInfo] the first time.
  ///
  /// The vehicle picks a new nonce on every connect and tells its current
  /// counter with it, so the app keeps no counter of its own and a fake
  /// vehicle can't make it burn counters. [readSessionInfo] returns null if
  /// the vehicle has no session characteristic (firmware older than this
  /// app), [onUnsupported] is then called once for this connection and no
  /// command is sent.
  @visibleForTesting
  static Future<VehicleSession?> getSession(
    BackgroundVehicle vehicle,
    Future<List<int>?> Function() readSessionInfo, {
    required void Function() onUnsupported,
  }) async {
    final cached = vehicle.session;
    if (cached != null) return cached;
    if (vehicle.sessionUnsupported) return null;

    final value = await readSessionInfo();
    if (value == null) {
      vehicle.sessionUnsupported = true;
      onUnsupported();
      return null;
    }

    final session = parseSessionInfo(value);
    vehicle.session = session;
    return session;
  }

  /// Reads the session characteristic (ffe2), null if the vehicle has none.
  static Future<List<int>?> _readSessionInfo(BluetoothDevice device) async {
    var characteristic = _findSessionCharacteristic(device.servicesList);
    if (characteristic == null) {
      // Android caches the GATT table per device, so a firmware update that
      // added ffe2 stays invisible until that cache is cleared.
      if (Platform.isAndroid) {
        try {
          await device.clearGattCache();
        } catch (e) {
          print('Error clearing the GATT cache: $e');
        }
      }
      characteristic =
          _findSessionCharacteristic(await device.discoverServices());
    }
    if (characteristic == null) return null;
    return characteristic.read();
  }

  static BluetoothCharacteristic? _findSessionCharacteristic(
      List<BluetoothService> services) {
    for (final service in services) {
      if (service.uuid != Guid('0000ffe0-0000-1000-8000-00805f9b34fb')) {
        continue;
      }
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid ==
            Guid('0000ffe2-0000-1000-8000-00805f9b34fb')) {
          return characteristic;
        }
      }
    }
    return null;
  }

  /// Send a command to a device.
  /// - [device] The device to send the command to.
  /// - [command] The command to send.
  /// - [additionalData] Additional data to send with the command (at most
  ///   [maxAdditionalDataLength] bytes, more throws).
  static Future<BluetoothCharacteristic?> sendCommand(
      BluetoothDevice device, ClientCommand command,
      {Uint8List? additionalData}) {
    // Queue behind whatever is already being sent to this device so the
    // rolling codes reach the firmware in the order they were allocated.
    final macAddress = device.remoteId.str;
    final previous = _sendQueues[macAddress] ?? Future.value();
    final result = previous.then(
        (_) => _sendCommand(device, command, additionalData: additionalData));
    _sendQueues[macAddress] = result.then((_) {}, onError: (_) {});
    return result;
  }

  static Future<BluetoothCharacteristic?> _sendCommand(
      BluetoothDevice device, ClientCommand command,
      {Uint8List? additionalData}) async {
    try {
      if (!device.isConnected) {
        print('Device is not connected');
        return null;
      }
      final vehicle = BleBackgroundService.vehicles.firstWhere(
          (vehicle) => vehicle.device.remoteId.str == device.remoteId.str);
      final sharedSecret = vehicle.data.sharedSecret;

      // Reuse the characteristic cached on connect. MTU + service discovery are
      // already done in _handleConnected, so we only rediscover as a fallback
      // when the cache is cold (e.g. after a service restart).
      var characteristic = vehicle.characteristic;
      if (characteristic == null || characteristic.device.isDisconnected) {
        final services = await device.discoverServices();
        final service = services.firstWhere((service) =>
            service.uuid == Guid('0000ffe0-0000-1000-8000-00805f9b34fb'));
        characteristic = service.characteristics.firstWhere((characteristic) =>
            characteristic.uuid ==
            Guid('0000ffe1-0000-1000-8000-00805f9b34fb'));
        vehicle.characteristic = characteristic;
      }

      if (characteristic.device.isDisconnected) {
        print('Device is not connected');
        return null;
      }

      if (additionalData != null &&
          additionalData.length > maxAdditionalDataLength) {
        throw ArgumentError.value(additionalData.length, 'additionalData',
            'At most $maxAdditionalDataLength bytes are allowed');
      }

      final VehicleSession? session;
      try {
        session = await getSession(
          vehicle,
          () => _readSessionInfo(device),
          onUnsupported: () {
            print('${device.remoteId.str} has no session characteristic, '
                'its firmware is too old for this app');
            BleBackgroundService.reportProtocolMismatch(
                device.remoteId.str, legacyProtocolVersion);
          },
        );
      } catch (e) {
        print('Error reading the session from the vehicle: $e');
        return null;
      }
      if (session == null) return null;

      final counter = session.takeCounter();
      final payload = buildCommandPayload(
          session.nonce, counter, command, sharedSecret,
          additionalData: additionalData);

      // Neither the secret, the nonce nor the payload is logged: a payload
      // whose write failed is still valid for the vehicle until a newer
      // counter arrives on the same connection.
      print(
          "Sending command: 0x${command.value.toRadixString(16)} counter at $counter");

      try {
        await characteristic.write(payload);
      } catch (e) {
        // The counter is deliberately not rolled back here: a write can fail
        // locally (timeout, link drop) after the firmware already received and
        // consumed it, and reusing that counter looks like a replay, which is
        // answered with INVALID_HMAC. Skipping one is harmless instead, the
        // firmware's acceptance window covers it.
        print('Error writing to characteristic: $e');
        return null;
      }

      return characteristic;
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
      return null;
    }
  }

  /// Send command with a float value
  static Future<BluetoothCharacteristic?> sendCommandWithFloat(
      BluetoothDevice device, ClientCommand command, double value) {
    final byteData = ByteData(4);
    byteData.setFloat32(0, value, Endian.little);
    return sendCommand(device, command,
        additionalData: byteData.buffer.asUint8List());
  }

  /// Send command with an int32 value
  static Future<BluetoothCharacteristic?> sendCommandWithInt32(
      BluetoothDevice device, ClientCommand command, int value) {
    final byteData = ByteData(4);
    byteData.setInt32(0, value, Endian.little);
    return sendCommand(device, command,
        additionalData: byteData.buffer.asUint8List());
  }

  /// Send command with an int16 value
  static Future<BluetoothCharacteristic?> sendCommandWithInt16(
      BluetoothDevice device, ClientCommand command, int value) {
    final byteData = ByteData(2);
    byteData.setInt16(0, value, Endian.little);
    return sendCommand(device, command,
        additionalData: byteData.buffer.asUint8List());
  }

  /// Send command with a string
  static Future<BluetoothCharacteristic?> sendCommandWithString(
      BluetoothDevice device, ClientCommand command, String value) {
    final stringBytes = utf8.encode(value);
    return sendCommand(device, command,
        additionalData: Uint8List.fromList(stringBytes));
  }

  /// Send command with multiple values packed together
  /// Example: two floats (lat, lng) = 8 bytes total
  static Future<BluetoothCharacteristic?> sendCommandWithFloats(
      BluetoothDevice device, ClientCommand command, List<double> values) {
    final byteData = ByteData(values.length * 4);
    for (int i = 0; i < values.length; i++) {
      byteData.setFloat32(i * 4, values[i], Endian.little);
    }
    return sendCommand(device, command,
        additionalData: byteData.buffer.asUint8List());
  }
}

class Esp32ResponseDate {
  final String macAddress;
  final Esp32Response command;
  final Esp32ResponseParser parser;

  Esp32ResponseDate(
      {required this.macAddress, required this.command, required this.parser});
}

/*class MessageData {
  final String macAddress;
  final String message;

  MessageData(this.macAddress, this.message);
}*/
