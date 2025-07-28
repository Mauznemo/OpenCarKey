import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../types/ble_commands.dart';

class BleService {
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

  /// Send a command to a device.
  /// - [device] The device to send the command to.
  /// - [command] The command to send.
  /// - [additionalData] Additional data to send with the command (MAX 12 Bytes!).
  static Future<BluetoothCharacteristic?> sendCommand(
      BluetoothDevice device, ClientCommand command,
      {String? additionalData}) async {
    try {
      if (!device.isConnected) {
        print('Device is not connected, isolate: ${Isolate.current.hashCode}');
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

      final List<int> payloadBytes = <int>[];

      // Add 32 dummy bytes for HMAC (will be replaced later)
      payloadBytes.addAll(List.filled(32, 0)); // Placeholder for HMAC

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
          "Sending command: 0x${command.value.toRadixString(16)} with payload: $payloadBytes");

      await characteristic.write(Uint8List.fromList(payloadBytes));
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
