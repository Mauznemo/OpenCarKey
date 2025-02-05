import 'package:flutter/services.dart';

class BleService {
  static const MethodChannel _channel =
      MethodChannel('com.smartify_os.open_car_key_app/ble');

  static Future<void> associateBle() async {
    try {
      final String result = await _channel.invokeMethod('associateBle');
      print(result); // Should print: BLE associated successfully
    } catch (e) {
      print("Failed to associate BLE: $e");
    }
  }
}
