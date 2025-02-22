import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Vehicle {
  BluetoothDevice device;
  VehicleData data;
  bool doorsLocked;
  bool trunkLocked;
  bool engineOn;

  Vehicle({
    required this.device,
    required this.data,
    this.doorsLocked = true,
    this.trunkLocked = true,
    this.engineOn = false,
  });
}

class VehicleData {
  final String name;
  final String macAddress;
  final String pin;
  final bool hasTrunkUnlock;
  final bool hasEngineStart;

  VehicleData({
    required this.name,
    required this.macAddress,
    required this.pin,
    required this.hasTrunkUnlock,
    required this.hasEngineStart,
  });

  factory VehicleData.fromJson(Map<String, dynamic> json) {
    return VehicleData(
      name: json['name'],
      macAddress: json['macAddress'],
      pin: json['pin'],
      hasTrunkUnlock: json['hasTrunkUnlock'],
      hasEngineStart: json['hasEngineStart'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'macAddress': macAddress,
      'pin': pin,
      'hasTrunkUnlock': hasTrunkUnlock,
      'hasEngineStart': hasEngineStart,
    };
  }
}