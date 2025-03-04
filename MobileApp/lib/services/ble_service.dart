import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
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

      print('Connected to device: ${device.advName}');

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

  static Future<BluetoothCharacteristic?> sendMessage(
      BluetoothDevice device, String message) async {
    try {
      if (!device.isConnected) {
        print('Device is not connected');
        return null;
      }

      final services = await device.discoverServices();
      final service = services.firstWhere((service) =>
          service.uuid == Guid('0000ffe0-0000-1000-8000-00805f9b34fb'));
      final characteristic = service.characteristics.firstWhere(
          (characteristic) =>
              characteristic.uuid ==
              Guid('0000ffe1-0000-1000-8000-00805f9b34fb'));

      print('Sending message: $message');
      await characteristic.write(utf8.encode(message));
      final response = utf8.decode(await characteristic.read());
      print('Response: $response');
      return characteristic;
    } on PlatformException catch (e) {
      print('Error: ${e.message}');
      return null;
    }
  }
}
