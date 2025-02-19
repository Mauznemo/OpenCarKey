import 'dart:convert';

import 'package:native_shared_preferences/native_shared_preferences.dart';

// Vehicle model class
class Vehicle {
  final String name;
  final String macAddress;
  final int associationId;
  final String pin;
  final bool hasTrunkUnlock;
  final bool hasEngineStart;

  Vehicle({
    required this.name,
    required this.macAddress,
    required this.associationId,
    required this.pin,
    required this.hasTrunkUnlock,
    required this.hasEngineStart,
  });

  // Convert vehicle to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'macAddress': macAddress,
      'associationId': associationId,
      'pin': pin,
      'hasTrunkUnlock': hasTrunkUnlock,
      'hasEngineStart': hasEngineStart,
    };
  }

  // Create vehicle from JSON
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      name: json['name'],
      macAddress: json['macAddress'],
      associationId: json['associationId'],
      pin: json['pin'],
      hasTrunkUnlock: json['hasTrunkUnlock'] ?? false,
      hasEngineStart: json['hasEngineStart'] ?? false,
    );
  }
}

// Vehicle storage class
class VehicleStorage {
  static const String _key = 'vehicles';

  // Save list of vehicles
  static Future<void> saveVehicles(List<Vehicle> vehicles) async {
    final NativeSharedPreferences prefs =
        await NativeSharedPreferences.getInstance();
    final String encodedData = json.encode(
      vehicles.map((vehicle) => vehicle.toJson()).toList(),
    );
    await prefs.setString(_key, encodedData);
  }

  // Get list of vehicles
  static Future<List<Vehicle>> getVehicles() async {
    final NativeSharedPreferences prefs =
        await NativeSharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_key);

    if (encodedData == null) return [];

    final List<dynamic> decodedData = json.decode(encodedData);
    return decodedData.map((item) => Vehicle.fromJson(item)).toList();
  }

  // Add a single vehicle
  static Future<void> addVehicle(Vehicle vehicle) async {
    final vehicles = await getVehicles();
    vehicles.add(vehicle);
    await saveVehicles(vehicles);
  }

  // Update an existing vehicle by mac address
  static Future<void> updateVehicle(Vehicle updatedVehicle) async {
    final vehicles = await getVehicles();
    final index = vehicles.indexWhere(
        (vehicle) => vehicle.macAddress == updatedVehicle.macAddress);
    if (index != -1) {
      vehicles[index] = updatedVehicle;
      await saveVehicles(vehicles);
    }
  }

  // Remove a vehicle by mac address
  static Future<void> removeVehicle(String macAddress) async {
    final vehicles = await getVehicles();
    vehicles.removeWhere((vehicle) => vehicle.macAddress == macAddress);
    await saveVehicles(vehicles);
  }

  // Clear all vehicles
  static Future<void> clearVehicles() async {
    final NativeSharedPreferences prefs =
        await NativeSharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
