import 'dart:io';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ble_device.dart';
import '../types/vehicle_data.dart';

part 'vehicle.freezed.dart';

@freezed
abstract class Vehicle with _$Vehicle {
  const factory Vehicle({
    required BleDevice device,
    required VehicleData data,
    @Default(true) bool doorsLocked,
    @Default(true) bool trunkLocked,
    @Default(false) bool engineOn,
  }) = _Vehicle;
}
