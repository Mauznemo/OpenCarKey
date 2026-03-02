import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/vehicles_state.dart';
import '../models/ble_device.dart';
import '../models/vehicle.dart';
import '../types/vehicle_data.dart';

part 'vehicles_provider.g.dart';

@riverpod
class VehiclesNotifier extends _$VehiclesNotifier {
  @override
  VehiclesState build() => const VehiclesState();

  void setVehicles(List<Vehicle> vehicles) {
    state = state.copyWith(vehicles: vehicles);
  }

  void updateVehicle(Vehicle vehicle) {
    state = state.copyWith(
      vehicles: state.vehicles
          .map(
              (v) => v.data.macAddress == vehicle.data.macAddress ? vehicle : v)
          .toList(),
    );
  }

  void addVehicle(VehicleData vehicle) {
    state = state.copyWith(
      vehicles: [
        ...state.vehicles,
        Vehicle(
            device: BleDevice(macAddress: vehicle.macAddress), data: vehicle)
      ],
    );
  }

  void removeVehicle(String macAddress) {
    state = state.copyWith(
      vehicles:
          state.vehicles.where((v) => v.data.macAddress != macAddress).toList(),
    );
  }

  void updateVehicleData(VehicleData vehicle) {
    state = state.copyWith(
      vehicles: state.vehicles.map((v) {
        if (v.data.macAddress == vehicle.macAddress) {
          return v.copyWith(data: vehicle);
        }
        return v;
      }).toList(),
    );
  }

  void addOutdatedVehicle(String macAddress) {
    state = state.copyWith(
      outdatedVehicles: [...state.outdatedVehicles, macAddress],
    );
  }

  void removeOutdatedVehicle(String macAddress) {
    if (!state.outdatedVehicles.contains(macAddress)) {
      return;
    }

    state = state.copyWith(
      outdatedVehicles:
          state.outdatedVehicles.where((v) => v != macAddress).toList(),
    );
  }

  void addUnauthenticatedVehicle(String macAddress) {
    state = state.copyWith(
      unauthenticatedVehicles: [...state.unauthenticatedVehicles, macAddress],
    );
  }

  void removeUnauthenticatedVehicle(String macAddress) {
    if (!state.unauthenticatedVehicles.contains(macAddress)) {
      return;
    }

    state = state.copyWith(
      unauthenticatedVehicles:
          state.unauthenticatedVehicles.where((v) => v != macAddress).toList(),
    );
  }

  void setVehicleConnected(macAddress, bool isConnected) {
    state = state.copyWith(
      vehicles: state.vehicles.map((vehicle) {
        if (vehicle.data.macAddress == macAddress) {
          return vehicle.copyWith(
              device: vehicle.device.copyWith(isConnected: isConnected));
        }
        return vehicle;
      }).toList(),
    );
  }

  void setVehicleLocked(String macAddress, bool locked) {
    state = state.copyWith(
      vehicles: state.vehicles.map((vehicle) {
        if (vehicle.data.macAddress == macAddress) {
          return vehicle.copyWith(doorsLocked: locked); // return new instance
        }
        return vehicle;
      }).toList(),
    );
  }
}
