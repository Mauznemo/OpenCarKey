import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BleDevice {
  final String macAddress;
  bool isConnected;

  BleDevice({required this.macAddress, this.isConnected = false});
}

class BleDeviceStorage {
  static const String _deviceListKey = 'connected_devices';

  static Future<void> reloadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  static Future<void> clearBleDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceListKey);
  }

  static Future<void> saveBleDevices(List<BleDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> deviceJsonList = devices
        .map((device) => jsonEncode({
              'macAddress': device.macAddress,
              'isConnected': device.isConnected,
            }))
        .toList();

    await prefs.setStringList(_deviceListKey, deviceJsonList);
  }

  static Future<List<BleDevice>> loadBleDevices() async {
    final prefs = await SharedPreferences.getInstance();

    List<String>? deviceJsonList = prefs.getStringList(_deviceListKey);

    if (deviceJsonList == null) {
      return [];
    }

    List<BleDevice> devices = deviceJsonList.map((jsonString) {
      Map<String, dynamic> deviceMap = jsonDecode(jsonString);
      return BleDevice(
        macAddress: deviceMap['macAddress'],
        isConnected: deviceMap['isConnected'] ?? false,
      );
    }).toList();

    return devices;
  }

  static Future<bool> addDevice(String macAddress,
      {bool isConnected = true}) async {
    List<BleDevice> devices = await loadBleDevices();

    bool deviceExists =
        devices.any((device) => device.macAddress == macAddress);

    if (deviceExists) {
      return false;
    }

    devices.add(BleDevice(macAddress: macAddress, isConnected: isConnected));

    await saveBleDevices(devices);

    return true;
  }

  static Future<bool> removeDevice(String macAddress) async {
    List<BleDevice> devices = await loadBleDevices();

    int initialLength = devices.length;

    devices.removeWhere((device) => device.macAddress == macAddress);

    bool removed = devices.length < initialLength;

    if (removed) {
      await saveBleDevices(devices);
    }

    return removed;
  }
}
