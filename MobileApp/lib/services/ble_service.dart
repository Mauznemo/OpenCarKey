import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../types/ble_commands.dart';
import 'ble_background_service.dart';
import '../utils/esp32_response_parser.dart';

class BleService {
  static SharedPreferences? _prefs;

  /// Last rolling code counter handed out per device, kept in memory so it can
  /// never go backwards inside this isolate. SharedPreferences is only the
  /// backup across restarts: [reloadPrefs] (and the prefs reloads done
  /// elsewhere in the app) replace the whole prefs cache with the on-disk
  /// snapshot, which can be older than a counter that was just handed out, and
  /// a reused counter is seen as a replay by the firmware.
  static final Map<String, int> _counters = {};

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

  static Future<void> reloadPrefs() async {
    await _prefs?.reload();

    // Forget counters of vehicles that are gone (removed in the main isolate,
    // which also deletes their counter), so re-adding one starts from scratch.
    _counters.removeWhere((macAddress, _) =>
        !(_prefs?.containsKey(_counterKey(macAddress)) ?? true));
  }

  static String _counterKey(String macAddress) => 'counter_$macAddress';

  /// Returns the next rolling code counter for [macAddress] and persists it.
  ///
  /// Counters are never reused: the firmware accepts a counter at or ahead of
  /// its own (within a window) and treats everything below as a replay.
  /// Skipping a counter is harmless, handing the same one out twice is not.
  static Future<int> _nextCounter(
      SharedPreferences prefs, String macAddress) async {
    final key = _counterKey(macAddress);
    final counter =
        max(prefs.getInt(key) ?? -1, _counters[macAddress] ?? -1) + 1;
    _counters[macAddress] = counter;
    await prefs.setInt(key, counter);
    return counter;
  }

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Generate HMAC-SHA256 for a counter and 1-byte command
  static Uint8List generateHmac(
      int counter, ClientCommand command, Uint8List sharedSecret) {
    final counterBytes = Uint8List(4)
      ..buffer.asByteData().setUint32(0, counter, Endian.little);
    final commandBytes = Uint8List(1)..[0] = command.value;
    final data = Uint8List.fromList([...counterBytes, ...commandBytes]);
    final hmac = Hmac(sha256, sharedSecret);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  static Uint8List generateSharedSecret(String password) {
    String cleanedPassword = password.replaceAll('\u0000', '');
    final inputBytes = utf8.encode(cleanedPassword);
    final digest = sha256.convert(inputBytes);
    final key = Uint8List.fromList(digest.bytes);

    print(
        'Generated 32-byte key (from: $cleanedPassword): ${key.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

    return key;
  }

  /// Send a command to a device.
  /// - [device] The device to send the command to.
  /// - [command] The command to send.
  /// - [additionalData] Additional data to send with the command (MAX 12 Bytes!).
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

      final List<int> payloadBytes = <int>[];

      final prefs = await _getPrefs();

      if (characteristic.device.isDisconnected) {
        print('Device is not connected');
        return null;
      }

      final counter = await _nextCounter(prefs, device.remoteId.str);
      final hmac = generateHmac(counter, command, sharedSecret);
      payloadBytes.addAll(hmac);

      payloadBytes.add(command.value);

      if (additionalData != null) {
        int dataLength = additionalData.length;

        if (dataLength > 12) {
          print('Additional data is too long, truncating to 12 bytes.');
          dataLength = 12;
        }

        payloadBytes.add(dataLength);
        payloadBytes.addAll(additionalData.sublist(0, dataLength));
      }

      print(
          "Sending command: 0x${command.value.toRadixString(16)} counter at $counter with payload: $payloadBytes");
      print(
          'Shared secret: ${sharedSecret.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

      try {
        await characteristic.write(Uint8List.fromList(payloadBytes));
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
