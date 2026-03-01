import 'dart:typed_data';

import 'features.dart';

class VehicleData {
  final String name;
  final String macAddress;
  final Uint8List sharedSecret;
  final Set<Feature> features;
  final bool noProximityKey;
  final String imagePath;

  VehicleData({
    required this.name,
    required this.macAddress,
    required this.sharedSecret,
    required this.features,
    this.noProximityKey = false,
    this.imagePath = '',
  });

  factory VehicleData.fromJson(Map<String, dynamic> json) {
    return VehicleData(
      name: json['name'],
      macAddress: json['macAddress'],
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
      'sharedSecret': sharedSecret.toList(),
      'features': features.map((f) => f.toJson()).toList(),
      'noProximityKey': noProximityKey,
      'imagePath': imagePath,
    };
  }
}
