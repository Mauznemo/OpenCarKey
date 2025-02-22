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
      print("Error: ${e.message}");
      return false;
    }
  }

  static Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
    }
  }

  static Future<BluetoothDevice?> connectToDevice(
      BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: true, mtu: null).catchError((e) {
        print("Connection error: $e");
      });

      print("Connected to device: ${device.advName}");

      return device;
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return null;
    }
  }

  static Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
    }
  }

  static Future<List<BluetoothDevice>> getConnectedDevices() async {
    try {
      final devices = FlutterBluePlus.connectedDevices;
      return devices;
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return [];
    }
  }

  static Future<BluetoothCharacteristic?> sendMessage(
      BluetoothDevice device, String message) async {
    try {
      if (!device.isConnected) {
        print("Device is not connected");
        return null;
      }

      final services = await device.discoverServices();
      final service = services.firstWhere((service) =>
          service.uuid == Guid("0000ffe0-0000-1000-8000-00805f9b34fb"));
      final characteristic = service.characteristics.firstWhere(
          (characteristic) =>
              characteristic.uuid ==
              Guid("0000ffe1-0000-1000-8000-00805f9b34fb"));

      print("Sending message: $message");
      await characteristic.write(utf8.encode(message));
      final response = utf8.decode(await characteristic.read());
      print("Response: $response");
      return characteristic;
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return null;
    }
  }

  static const MethodChannel _channel =
      MethodChannel('com.smartify_os.open_car_key_app/ble');

  static Future<BleAssociationResult> associateBle() async {
    try {
      final String result = await _channel.invokeMethod('associateBle');
      print("Success: $result");
      var results = result.split(", ");
      return BleAssociationResult(true, int.parse(results[1]), results[0], "");
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return BleAssociationResult(false, -1, "", e.message ?? "");
    }
  }

  static Future<void> disassociateBle(
      int associationId, String macAddress) async {
    try {
      await _channel.invokeMethod('disassociateBle',
          {'associationId': associationId, 'macAddress': macAddress});
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
    }
  }

  static Future<String> getAssociated() async {
    try {
      var result = await _channel.invokeMethod('getAssociated');
      return result.toString();
      //final List<dynamic> result = await _channel.invokeMethod('getAssociated');
      //return result.map((item) => AssociationInfo.fromJson(item)).toList();
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return "";
    }
  }

  static Future<void> postEvent(String message) async {
    try {
      await _channel.invokeMethod('postEvent', {'message': message});
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
    }
  }

  static Future<List<String>> getConnectedDevicesOld() async {
    try {
      var result = await _channel.invokeMethod('getConnectedDevices');
      print("Success: $result");

      // Ensure the result is a valid string
      if (result == null || result.toString().isEmpty) {
        return [];
      }

      // Option 1: If the Kotlin side sends a JSON string (recommended)
      try {
        return List<String>.from(jsonDecode(result));
      } catch (e) {
        print("JSON parsing error, falling back to split: $e");
      }

      // Option 2: If the Kotlin side sends a comma-separated string (e.g., "Device1,Device2")
      return result.toString().split(",").map((e) => e.trim()).toList();
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return [];
    }
  }
}

class BleAssociationResult {
  final bool success;
  final String macAddress;
  final int associationId;
  final String errorMessage;

  BleAssociationResult(
      this.success, this.associationId, this.macAddress, this.errorMessage);
}
