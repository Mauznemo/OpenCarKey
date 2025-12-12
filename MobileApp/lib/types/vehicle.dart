import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_device.dart';
import 'features.dart';

class Vehicle {
  BleDevice device;
  VehicleData data;
  bool doorsLocked;
  bool trunkLocked;
  bool engineOn;
  File? imageFile;

  Vehicle({
    required this.device,
    required this.data,
    this.doorsLocked = true,
    this.trunkLocked = true,
    this.engineOn = false,
    this.imageFile,
  });
}

class BackgroundVehicle {
  BluetoothDevice device;
  VehicleData data;
  bool doorsLocked;
  bool trunkLocked;
  bool engineOn;

  BackgroundVehicle({
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
  final String password;
  final Uint8List sharedSecret;
  final Set<Feature> features;
  final bool noProximityKey;
  final String imagePath;

  VehicleData({
    required this.name,
    required this.macAddress,
    required this.password,
    required this.sharedSecret,
    required this.features,
    this.noProximityKey = false,
    this.imagePath = '',
  });

  factory VehicleData.fromJson(Map<String, dynamic> json) {
    return VehicleData(
      name: json['name'],
      macAddress: json['macAddress'],
      password: json['password'] ?? '',
      sharedSecret: Uint8List.fromList(
          (json['sharedSecret'] as List<dynamic>).cast<int>()),
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => Feature.fromJson(e as String))
              .toSet() ??
          {},
      noProximityKey: json['noProximityKey'] ?? false,
      imagePath: json['imagePath'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'macAddress': macAddress,
      'password': password,
      'sharedSecret': sharedSecret.toList(),
      'features': features.map((f) => f.toJson()).toList(),
      'noProximityKey': noProximityKey,
      'imagePath': imagePath,
    };
  }
}
