import 'dart:convert';

import 'package:flutter/services.dart';

class BleService {
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

  static Future<List<String>> getConnectedDevices() async {
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
