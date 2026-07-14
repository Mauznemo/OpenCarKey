import 'dart:async';
import 'dart:convert';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:home_widget/home_widget.dart';

import '../types/ble_commands.dart';
import '../models/ble_device.dart';
import '../types/background_vehicle.dart';
import '../types/features.dart';
import '../models/vehicle.dart';
import 'ble_background_service.dart';
import 'vehicle_service.dart';

@pragma('vm:entry-point')
class WidgetService {
  static FlutterBackgroundService service = FlutterBackgroundService();
  static List<Vehicle> vehicles = [];
  static List<Vehicle> connectedVehicles = [];
  static int selectedVehicleIndex = 0;

  /// In-flight widget button commands, keyed by MAC → set of action keys
  /// ('doors', 'trunk'). Drives the loading spinner on the home-screen widget,
  /// mirroring the in-app buttons. Doors clear on the ESP's LOCKED/UNLOCKED
  /// confirmation; trunk clears when the command write completes; both have a
  /// safety timeout so the spinner can never spin forever.
  static const Duration _pendingTimeout = Duration(seconds: 10);
  static final Map<String, Set<String>> _pendingActions = {};
  static final Map<String, Timer> _pendingTimers = {};

  static void _setPending(String macAddress, String action) {
    _pendingActions.putIfAbsent(macAddress, () => <String>{}).add(action);
    _pendingTimers['$macAddress|$action']?.cancel();
    _pendingTimers['$macAddress|$action'] = Timer(_pendingTimeout, () {
      _clearPending(macAddress, action);
      updateConnectedVehicle();
    });
    updateConnectedVehicle();
  }

  static void _clearPending(String macAddress, String action) {
    _pendingActions[macAddress]?.remove(action);
    if (_pendingActions[macAddress]?.isEmpty ?? false) {
      _pendingActions.remove(macAddress);
    }
    _pendingTimers.remove('$macAddress|$action')?.cancel();
  }

  static bool _isPending(String macAddress, String action) =>
      _pendingActions[macAddress]?.contains(action) ?? false;

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
        connectedVehicles.length <= selectedVehicleIndex) {
      return;
    }

    // Any lock-state confirmation clears the doors spinner for that vehicle.
    if (command == Esp32Response.LOCKED ||
        command == Esp32Response.UNLOCKED ||
        command == Esp32Response.PROXIMITY_LOCKED ||
        command == Esp32Response.PROXIMITY_UNLOCKED) {
      _clearPending(macAddress, 'doors');
    }

    // Lock state is read straight from the authoritative BackgroundVehicle in
    // [updateConnectedVehicle], so we don't mutate a local copy here (that copy
    // was the source of the "widget stuck locked after reconnect" bug: it was
    // reset to the doorsLocked=true default on every reloadConnectedDevices).
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

    for (int i = 0; i < vehicles.length; i++) {
      final vehicle = vehicles[i];

      final connectedDevice = connectedDevices.firstWhere(
        (device) => device.macAddress == vehicle.device.macAddress,
        orElse: () => vehicle.device,
      );

      final updatedVehicle = vehicle.copyWith(
        device: connectedDevice.copyWith(
          isConnected: connectedDeviceMacs.contains(vehicle.device.macAddress),
        ),
      );

      vehicles[i] = updatedVehicle;

      if (updatedVehicle.device.isConnected) {
        connectedVehicles.add(updatedVehicle);
      }
    }

    if (connectedVehicles.length <= selectedVehicleIndex) {
      selectedVehicleIndex = 0;
    }
    updateConnectedVehicle();
  }

  /// Returns the authoritative background vehicle for [macAddress] (the one
  /// whose [BackgroundVehicle.doorsLocked] is kept up to date by
  /// [BleBackgroundService], reliably, regardless of widget reload timing).
  static BackgroundVehicle? _authoritativeVehicle(String macAddress) {
    for (final vehicle in BleBackgroundService.vehicles) {
      if (vehicle.device.remoteId.str == macAddress) {
        return vehicle;
      }
    }
    return null;
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
        case 'unlock':
          // Show the spinner until the ESP confirms the new lock state (cleared
          // in processMessage) or the safety timeout fires.
          _setPending(macAddress, 'doors');
          BleBackgroundService.sendCommand(
              BleDevice(macAddress: macAddress),
              actionType == 'lock'
                  ? ClientCommand.LOCK_DOORS
                  : ClientCommand.UNLOCK_DOORS);
          break;
        case 'open_trunk':
          // The trunk has no ESP state confirmation, so clear the spinner when
          // the command write round-trip completes (or on the safety timeout).
          _setPending(macAddress, 'trunk');
          BleBackgroundService.sendCommand(
                  BleDevice(macAddress: macAddress), ClientCommand.OPEN_TRUNK)
              .whenComplete(() {
            _clearPending(macAddress, 'trunk');
            updateConnectedVehicle();
          });
          break;
        case 'start_engine':
          //TODO: Implement engine start
          break;
        default:
          print('Unknown action type: $actionType');
      }
    }
  }

  /// Updates the widget with the current connected vehicle. (ONLY call from Background service isolate)
  static void updateConnectedVehicle() async {
    if (connectedVehicles.isEmpty) {
      await HomeWidget.saveWidgetData<String>('currentVehicle', 'none');
    } else {
      final currentVehicle = connectedVehicles[selectedVehicleIndex];
      // Read lock/engine state from the authoritative BackgroundVehicle instead
      // of the local (reset-on-reload) copy, so the widget can't get stuck on
      // the doorsLocked=true default after a reconnect.
      final authoritative =
          _authoritativeVehicle(currentVehicle.device.macAddress);
      final isLocked = authoritative?.doorsLocked ?? currentVehicle.doorsLocked;
      final engineOn = authoritative?.engineOn ?? currentVehicle.engineOn;

      await HomeWidget.saveWidgetData<String>(
          'currentVehicle',
          json.encode({
            'name': currentVehicle.data.name,
            'macAddress': currentVehicle.device.macAddress,
            'hasEngineStart':
                currentVehicle.data.features.contains(Feature.engine),
            'hasTrunkUnlock':
                currentVehicle.data.features.contains(Feature.trunkOpen),
            'isLocked': isLocked,
            'engineOn': engineOn,
            'pendingDoors':
                _isPending(currentVehicle.device.macAddress, 'doors'),
            'pendingTrunk':
                _isPending(currentVehicle.device.macAddress, 'trunk'),
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
