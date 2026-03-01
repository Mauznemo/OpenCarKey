import 'package:freezed_annotation/freezed_annotation.dart';

import 'vehicle.dart';

part 'vehicles_state.freezed.dart';

@freezed
abstract class VehiclesState with _$VehiclesState {
  const VehiclesState._();

  const factory VehiclesState({
    @Default([]) List<Vehicle> vehicles,
    @Default([]) List<String> unauthenticatedVehicles,
    @Default([]) List<String> outdatedVehicles,
  }) = _VehiclesState;

  List<Vehicle> get connectedVehicles =>
      vehicles.where((vehicle) => vehicle.device.isConnected).toList();
}
