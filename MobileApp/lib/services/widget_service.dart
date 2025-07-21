import 'dart:convert';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:home_widget/home_widget.dart';

import '../types/ble_device.dart';
import '../types/vehicle.dart';
import 'ble_background_service.dart';
import 'vehicle_service.dart';

@pragma('vm:entry-point')
class WidgetService {
  static FlutterBackgroundService service = FlutterBackgroundService();
  static List<Vehicle> vehicles = [];
  static List<Vehicle> connectedVehicles = [];

  /// Initializes the widget service. (ONLY call from Background service isolate)
  static Future<void> initialize({bool backgroundServiceEnabled = true}) async {
    await HomeWidget.saveWidgetData<bool>(
        'backgroundService', backgroundServiceEnabled);
    await _getVehicles();
    reloadConnectedDevices();
  }

  /// Updates the widget with the new state of the current connected vehicle. (ONLY call from Background service isolate)
  static void processMessage(String macAddress, String message) {
    if (connectedVehicles.isEmpty) {
      return;
    }

    if (macAddress == connectedVehicles.first.device.macAddress) {
      if (message.startsWith('LOCKED')) {
        connectedVehicles.first.doorsLocked = true;
      } else if (message.startsWith('UNLOCKED')) {
        connectedVehicles.first.doorsLocked = false;
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
    await VehicleStorage.reloadPrefs();
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

  @pragma('vm:entry-point')
  static void backgroundCallback(Uri? uri) {
    if (uri != null) {
      final actionType = uri.queryParameters['action_type'] ?? 'unknown_action';
      final macAddress = uri.queryParameters['mac_address'] ?? 'unknown_mac';

      if (macAddress == 'unknown_mac') {
        return;
      }

      print('Action type: $actionType');

      switch (actionType) {
        case 'lock':
          BleBackgroundService.sendMessage(
              BleDevice(macAddress: macAddress), 'LOCK');
          break;
        case 'unlock':
          BleBackgroundService.sendMessage(
              BleDevice(macAddress: macAddress), 'UNLOCK');
          break;
        case 'open_trunk':
          BleBackgroundService.sendMessage(
              BleDevice(macAddress: macAddress), 'OPEN_TRUNK');
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
      final currentVehicle = connectedVehicles.first;
      await HomeWidget.saveWidgetData<String>(
          'currentVehicle',
          json.encode({
            'name': currentVehicle.data.name,
            'macAddress': currentVehicle.device.macAddress,
            'hasEngineStart': currentVehicle.data.hasEngineStart,
            'hasTrunkUnlock': currentVehicle.data.hasTrunkUnlock,
            'isLocked': currentVehicle.doorsLocked,
            'engineOn': currentVehicle.engineOn,
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
