import 'dart:convert';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:home_widget/home_widget.dart';

import '../types/ble_commands.dart';
import '../types/ble_device.dart';
import '../types/features.dart';
import '../types/vehicle.dart';
import 'ble_background_service.dart';
import 'vehicle_service.dart';

@pragma('vm:entry-point')
class WidgetService {
  static FlutterBackgroundService service = FlutterBackgroundService();
  static List<Vehicle> vehicles = [];
  static List<Vehicle> connectedVehicles = [];
  static int selectedVehicleIndex = 0;

  /// Initializes the widget service. (ONLY call from Background service isolate)
  static Future<void> initialize({bool backgroundServiceEnabled = true}) async {
    await HomeWidget.saveWidgetData<bool>(
        'backgroundService', backgroundServiceEnabled);
    await _getVehicles();
    reloadConnectedDevices();
  }

  /// Updates the widget with the new state of the current connected vehicle. (ONLY call from Background service isolate)
  static void processMessage(String macAddress, Esp32Response command) {
    if (connectedVehicles.isEmpty ||
        connectedVehicles.length < selectedVehicleIndex) {
      return;
    }

    if (macAddress ==
        connectedVehicles[selectedVehicleIndex].device.macAddress) {
      if (command == Esp32Response.LOCKED) {
        connectedVehicles[selectedVehicleIndex].doorsLocked = true;
      } else if (command == Esp32Response.UNLOCKED) {
        connectedVehicles[selectedVehicleIndex].doorsLocked = false;
      }
    }

    updateConnectedVehicle();
  }

  /// Reloads vehicles for when their config was updated. (ONLY call from Background service isolate)
  static Future<void> reloadVehicles() async {
    await _getVehicles();
    reloadConnectedDevices();
  }

  /// Reloads the connected devices and updates widget. (ONLY call from Background service isolate)
  static Future<void> reloadConnectedDevices() async {
    HomeWidget.registerInteractivityCallback(
        backgroundCallback); //Re-register callback in case it was killed by the system
    connectedVehicles.clear();
    final connectedDevices = await BleBackgroundService.getConnectedDevices();
    List<String> connectedDeviceMacs =
        connectedDevices.map((e) => e.macAddress).toList();

    for (final vehicle in vehicles) {
      final connectedDevice = connectedDevices.firstWhere(
        (device) => device.macAddress == vehicle.device.macAddress,
        orElse: () => vehicle.device,
      );

      vehicle.device = connectedDevice;
      vehicle.device.isConnected =
          connectedDeviceMacs.contains(vehicle.device.macAddress);
      if (vehicle.device.isConnected) {
        connectedVehicles.add(vehicle);
      }
    }

    if (connectedVehicles.length < selectedVehicleIndex) {
      selectedVehicleIndex = 0;
    }
    updateConnectedVehicle();
  }

  static Future<void> _getVehicles() async {
    await VehicleStorage.reloadPrefs();
    final vehiclesData = await VehicleStorage.getVehicles();

    vehicles.clear();
    for (final vehicleData in vehiclesData) {
      vehicles.add(Vehicle(
        device: BleDevice(macAddress: vehicleData.macAddress),
        data: vehicleData,
      ));
    }
  }

  static void changeVehicle() {
    selectedVehicleIndex =
        (selectedVehicleIndex + 1) % connectedVehicles.length;
    updateConnectedVehicle();
  }

  @pragma('vm:entry-point')
  static void backgroundCallback(Uri? uri) {
    if (uri != null) {
      final actionType = uri.queryParameters['action_type'] ?? 'unknown_action';
      final macAddress = uri.queryParameters['mac_address'] ?? 'unknown_mac';

      if (actionType == 'change_vehicle') {
        BleBackgroundService.changeHomescreenWidgetVehicle();
        return;
      }

      if (macAddress == 'unknown_mac') {
        return;
      }

      print('Action type: $actionType');

      switch (actionType) {
        case 'lock':
          BleBackgroundService.sendCommand(
              BleDevice(macAddress: macAddress), ClientCommand.LOCK_DOORS);
          break;
        case 'unlock':
          BleBackgroundService.sendCommand(
              BleDevice(macAddress: macAddress), ClientCommand.UNLOCK_DOORS);
          break;
        case 'open_trunk':
          BleBackgroundService.sendCommand(
              BleDevice(macAddress: macAddress), ClientCommand.OPEN_TRUNK);
          break;
        case 'start_engine':
          //TODO: Implement engine start
          break;
        default:
          print('Unknown action type: $actionType');
      }
      _updateWidget();
    }
  }

  /// Updates the widget with the current connected vehicle. (ONLY call from Background service isolate)
  static void updateConnectedVehicle() async {
    if (connectedVehicles.isEmpty) {
      await HomeWidget.saveWidgetData<String>('currentVehicle', 'none');
    } else {
      final currentVehicle = connectedVehicles[selectedVehicleIndex];
      await HomeWidget.saveWidgetData<String>(
          'currentVehicle',
          json.encode({
            'name': currentVehicle.data.name,
            'macAddress': currentVehicle.device.macAddress,
            'hasEngineStart':
                currentVehicle.data.features.contains(Feature.engine),
            'hasTrunkUnlock':
                currentVehicle.data.features.contains(Feature.trunkOpen),
            'isLocked': currentVehicle.doorsLocked,
            'engineOn': currentVehicle.engineOn,
            'multipleConnectedDevices': connectedVehicles.length > 1
          }));
    }

    _updateWidget();
  }

  static void _updateWidget() {
    HomeWidget.updateWidget(
      name: 'HomescreenWidgetReceiver',
    );
  }
}
