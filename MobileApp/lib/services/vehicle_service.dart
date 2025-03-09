import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../types/vehicle.dart';

class VehicleStorage {
  static const String _key = 'vehicles';

  static Future<void> reloadPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  static Future<void> saveVehicles(List<VehicleData> vehicles) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      vehicles.map((vehicle) => vehicle.toJson()).toList(),
    );
    await prefs.setString(_key, encodedData);
  }

  static Future<List<VehicleData>> getVehicles() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_key);

    if (encodedData == null) return [];

    final List<dynamic> decodedData = json.decode(encodedData);
    return decodedData.map((item) => VehicleData.fromJson(item)).toList();
  }

  static Future<void> addVehicle(VehicleData vehicle) async {
    final vehicles = await getVehicles();
    vehicles.add(vehicle);
    await saveVehicles(vehicles);
  }

  static Future<void> updateVehicle(VehicleData updatedVehicle) async {
    final vehicles = await getVehicles();
    final index = vehicles.indexWhere(
        (vehicle) => vehicle.macAddress == updatedVehicle.macAddress);
    if (index != -1) {
      vehicles[index] = updatedVehicle;
      await saveVehicles(vehicles);
    }
  }

  static Future<void> removeVehicle(String macAddress) async {
    final vehicles = await getVehicles();
    vehicles.removeWhere((vehicle) => vehicle.macAddress == macAddress);
    await saveVehicles(vehicles);
  }

  static Future<void> clearVehicles() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
