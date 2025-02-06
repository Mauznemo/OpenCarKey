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
}

class BleAssociationResult {
  final bool success;
  final String macAddress;
  final int associationId;
  final String errorMessage;

  BleAssociationResult(
      this.success, this.associationId, this.macAddress, this.errorMessage);
}
