import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BleDevice {
  final String macAddress;
  bool isConnected;
  int rssi;

  BleDevice(
      {required this.macAddress, this.isConnected = false, this.rssi = 0});
}

class BleDeviceStorage {
  static const String _deviceListKey = 'connected_devices';

  // Save list of BLE devices to SharedPreferences
  static Future<void> saveBleDevices(List<BleDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();

    // Convert list of BleDevice to list of JSON strings
    List<String> deviceJsonList = devices
        .map((device) => jsonEncode({
              'macAddress': device.macAddress,
              'isConnected': device.isConnected,
              'rssi': device.rssi,
            }))
        .toList();

    await prefs.setStringList(_deviceListKey, deviceJsonList);
  }

  // Load list of BLE devices from SharedPreferences
  static Future<List<BleDevice>> loadBleDevices() async {
    final prefs = await SharedPreferences.getInstance();

    // Retrieve the list of JSON strings
    List<String>? deviceJsonList = prefs.getStringList(_deviceListKey);

    if (deviceJsonList == null) {
      return []; // Return empty list if no devices are stored
    }

    // Convert JSON strings back to BleDevice objects
    List<BleDevice> devices = deviceJsonList.map((jsonString) {
      Map<String, dynamic> deviceMap = jsonDecode(jsonString);
      return BleDevice(
        macAddress: deviceMap['macAddress'],
        isConnected: deviceMap['isConnected'] ?? false,
        rssi: deviceMap['rssi'] ?? 0,
      );
    }).toList();

    return devices;
  }
}
