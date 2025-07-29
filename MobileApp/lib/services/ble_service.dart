import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../types/ble_commands.dart';
import 'ble_background_service.dart';

class BleService {
  static SharedPreferences? _prefs;

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

  static void reloadPrefs() async {
    await _prefs?.reload();
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
    final inputBytes = utf8.encode(password);
    final digest = sha256.convert(inputBytes);
    final key = Uint8List.fromList(digest.bytes);

    print(
        'Generated 32-byte key (from: $password): ${key.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

    return key;
  }

  /// Send a command to a device.
  /// - [device] The device to send the command to.
  /// - [command] The command to send.
  /// - [additionalData] Additional data to send with the command (MAX 12 Bytes!).
  static Future<BluetoothCharacteristic?> sendCommand(
      BluetoothDevice device, ClientCommand command,
      {String? additionalData}) async {
    try {
      if (!device.isConnected) {
        print('Device is not connected');
        return null;
      }
      await device.requestMtu(64);
      final services = await device.discoverServices();
      final service = services.firstWhere((service) =>
          service.uuid == Guid('0000ffe0-0000-1000-8000-00805f9b34fb'));
      final characteristic = service.characteristics.firstWhere(
          (characteristic) =>
              characteristic.uuid ==
              Guid('0000ffe1-0000-1000-8000-00805f9b34fb'));

      final vehicle = BleBackgroundService.vehicles.firstWhere(
          (vehicle) => vehicle.device.remoteId.str == device.remoteId.str);
      final sharedSecret = vehicle.data.sharedSecret;

      final List<int> payloadBytes = <int>[];

      final prefs = await _getPrefs();

      if (characteristic.device.isDisconnected) {
        print('Device is not connected');

        return null;
      }

      var counter = prefs.getInt('counter_${device.remoteId.str}') ?? 0;
      counter++;
      prefs.setInt('counter_${device.remoteId.str}', counter);
      print('updated counter: counter_${device.remoteId.str}');
      final hmac = generateHmac(counter, command, sharedSecret);
      payloadBytes.addAll(hmac);

      payloadBytes.add(command.value);

      if (additionalData != null) {
        final List<int> stringBytes =
            utf8.encode(additionalData); // eg. "10.22,115.22"

        if (stringBytes.length > 12) {
          print('Additional data is too long, truncating to 12 bytes.');
          payloadBytes.add(12);
          payloadBytes.addAll(stringBytes.sublist(0, 12));
        } else {
          payloadBytes.add(stringBytes.length);
          payloadBytes.addAll(stringBytes);
        }
      }

      print(
          "Sending command: 0x${command.value.toRadixString(16)} counter at $counter with payload: $payloadBytes");
      print(
          'Shared secret: ${sharedSecret.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

      try {
        await characteristic.write(Uint8List.fromList(payloadBytes));
      } catch (e) {
        print('Error writing to characteristic (revering counter): $e');
        var counter = prefs.getInt('counter_${device.remoteId.str}') ?? 0;
        counter--;
        prefs.setInt('counter_${device.remoteId.str}', counter);
        return null;
      }

      //final response = utf8.decode(await characteristic.read());

      return characteristic;
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
      return null;
    }
  }
}

class Esp32ResponseDate {
  final String macAddress;
  final Esp32Response command;
  final String? additionalData;

  Esp32ResponseDate(
      {required this.macAddress, required this.command, this.additionalData});
}

/*class MessageData {
  final String macAddress;
  final String message;

  MessageData(this.macAddress, this.message);
}*/
