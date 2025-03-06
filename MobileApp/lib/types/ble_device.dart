import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BleDevice {
  final String macAddress;
  bool isConnected;

  BleDevice({required this.macAddress, this.isConnected = false});
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
      );
    }).toList();

    return devices;
  }

  // Add a BLE device by MAC address
  static Future<bool> addDevice(String macAddress,
      {bool isConnected = true}) async {
    List<BleDevice> devices = await loadBleDevices();

    // Check if device with same MAC already exists
    bool deviceExists =
        devices.any((device) => device.macAddress == macAddress);

    if (deviceExists) {
      return false; // Device already exists, return false
    }

    // Add new device
    devices.add(BleDevice(macAddress: macAddress, isConnected: isConnected));

    // Save updated list
    await saveBleDevices(devices);
    return true; // Successfully added
  }

  // Remove a BLE device by MAC address
  static Future<bool> removeDevice(String macAddress) async {
    List<BleDevice> devices = await loadBleDevices();

    // Find the index of the device with the given MAC
    int initialLength = devices.length;

    // Remove the device if found
    devices.removeWhere((device) => device.macAddress == macAddress);

    // If list length changed, a device was removed
    bool removed = devices.length < initialLength;

    if (removed) {
      // Save updated list
      await saveBleDevices(devices);
    }

    return removed; // Return true if device was removed, false otherwise
  }
}
