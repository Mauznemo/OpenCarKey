import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';
import '../providers/vehicles_provider.dart';
import '../types/ble_commands.dart';
import '../models/ble_device.dart';
import '../models/vehicle.dart';
import '../types/vehicle_data.dart';
import '../utils/esp32_response_parser.dart';
import '../utils/image_utils.dart';
import 'ble_background_service.dart';
import 'ble_service.dart';
import 'settings_service.dart';

class VehicleService {
  VehicleService._();

  static VehicleService? _instance;
  static VehicleService get instance => _instance ??= VehicleService._();

  late BuildContext context;
  late WidgetRef ref;

  final FlutterBackgroundService service = FlutterBackgroundService();

  StreamSubscription<Map<String, dynamic>?>? commandStream;
  StreamSubscription<Map<String, dynamic>?>? connectionStateStream;
  StreamSubscription<Map<String, dynamic>?>? reloadStream;

  void init(BuildContext context, WidgetRef ref) {
    this.context = context;
    this.ref = ref;

    commandStream = service.on('command_received').listen((event) {
      if (event != null) {
        Esp32ResponseParser parser =
            Esp32ResponseParser(List<int>.from(event['data']));
        Esp32Response? command = Esp32Response.fromValue(parser.command);
        if (command == null) {
          return;
        }
        Esp32ResponseDate data = Esp32ResponseDate(
            macAddress: event['macAddress'], command: command, parser: parser);
        processMessage(data);
      }
    });
    connectionStateStream =
        service.on('connection_state_changed').listen((event) {
      if (event != null) {
        final macAddress = event['macAddress'];
        final connectionState = event['connectionState'];
        final isConnected =
            connectionState == 'BluetoothConnectionState.connected';

        debugPrint(
            '[VehicleService] Connection state changed for $macAddress: $isConnected');

        final vehiclesNotifier = ref.read(vehiclesProvider.notifier);

        vehiclesNotifier.removeOutdatedVehicle(macAddress);
        vehiclesNotifier.setVehicleConnected(macAddress, isConnected);
      }
    });
    reloadStream = service.on('reload_vehicle_data').listen((event) {
      if (event != null) {
        reloadVehicleData(event['macAddress']);
      }
    });

    getVehicles();
  }

  void getVehicles() async {
    final vehiclesNotifier = ref.read(vehiclesProvider.notifier);

    final vehiclesData = await VehicleStorage.getVehicles();

    List<Vehicle> newVehicles = [];
    for (final vehicleData in vehiclesData) {
      newVehicles.add(Vehicle(
        device: BleDevice(macAddress: vehicleData.macAddress),
        data: vehicleData,
      ));
    }

    vehiclesNotifier.setVehicles(newVehicles);

    BleBackgroundService.tryConnectAll();

    _getConnectedDevices();
  }

  void reloadVehicleData(String macAddress) async {
    final vehiclesState = ref.read(vehiclesProvider);

    await VehicleStorage.reloadPrefs();
    final vehiclesData = await VehicleStorage.getVehicle(macAddress);

    final vehicle = vehiclesState.vehicles.firstWhere(
      (element) => element.data.macAddress == macAddress,
    );

    ref
        .read(vehiclesProvider.notifier)
        .updateVehicle(vehicle.copyWith(data: vehiclesData));
  }

  void _getConnectedDevices() async {
    final vehiclesState = ref.read(vehiclesProvider);

    await VehicleStorage.reloadPrefs();
    final connectedDevices = await BleBackgroundService.getConnectedDevices();
    List<String> connectedDeviceMacs =
        connectedDevices.map((e) => e.macAddress).toList();

    final vehicles = vehiclesState.vehicles.toList();
    for (int i = 0; i < vehicles.length; i++) {
      final vehicle = vehicles[i];

      final connectedDevice = connectedDevices.firstWhere(
        (device) => device.macAddress == vehicle.device.macAddress,
        orElse: () => vehicle.device,
      );

      vehicles[i] = vehicle.copyWith(
          device: connectedDevice.copyWith(
              isConnected:
                  connectedDeviceMacs.contains(vehicle.device.macAddress)));

      debugPrint(
          '[VehicleService] Checking connected device: ${vehicle.device.macAddress}: Connected: ${vehicle.device.isConnected}');
    }

    ref.read(vehiclesProvider.notifier).setVehicles(vehicles);

    BleBackgroundService.requestData();
  }

  void processMessage(Esp32ResponseDate data) {
    final vehiclesState = ref.read(vehiclesProvider);
    final settingsState = ref.read(settingsProvider);
    final vehiclesNotifier = ref.read(vehiclesProvider.notifier);

    if (data.command == Esp32Response.VERSION) {
      final deviceProtocolVersion = data.parser.getString();

      if (deviceProtocolVersion == BleBackgroundService.PROTOCOL_VERSION) {
        return;
      }

      if (vehiclesState.outdatedVehicles.contains(data.macAddress)) {
        return;
      }
      vehiclesNotifier.addOutdatedVehicle(data.macAddress);

      if (settingsState.ignoreProtocolMismatch) {
        return;
      }

      final vehicleName = vehiclesState.vehicles
          .firstWhere((element) => element.data.macAddress == data.macAddress)
          .data
          .name;

      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Protocol Version Mismatch'),
                content: Text(
                    '$vehicleName is on protocol version $deviceProtocolVersion and the app is on ${BleBackgroundService.PROTOCOL_VERSION}. Everything you need might still work, but if not please update your ESP32/app to the newest version.'),
                actions: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Okay')),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        SettingsService.instance
                            .setIgnoreProtocolMismatch(true);
                      },
                      child: const Text("Don't show this again")),
                ],
              ));
    } else if (data.command == Esp32Response.INVALID_HMAC) {
      if (vehiclesState.unauthenticatedVehicles.contains(data.macAddress)) {
        return;
      }
      vehiclesNotifier.addUnauthenticatedVehicle(data.macAddress);

      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Invalid HMAC'),
                content: Text(
                    'Invalid HMAC/rolling code for device ${data.macAddress}. Please remove the vehicle then hold down the button labeled BOOT on yor ESP32 for 5 sec and re-add it to the app.'),
                actions: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Okay'))
                ],
              ));
    } else if (data.command == Esp32Response.LOCKED ||
        data.command == Esp32Response.PROXIMITY_LOCKED) {
      debugPrint('[VehicleService] set vehicle locked');
      vehiclesNotifier.setVehicleLocked(data.macAddress, true);
    } else if (data.command == Esp32Response.UNLOCKED ||
        data.command == Esp32Response.PROXIMITY_UNLOCKED) {
      debugPrint('[VehicleService] set vehicle unlocked');
      vehiclesNotifier.setVehicleLocked(data.macAddress, false);
    }
  }

  void addVehicle(VehicleData vehicle) async {
    await VehicleStorage.addVehicle(vehicle);
    ref.read(vehiclesProvider.notifier).addVehicle(vehicle);

    BleBackgroundService.reloadVehicles();
    BleBackgroundService.reloadHomescreenWidget();
  }

  void updateVehicleData(VehicleData vehicle) async {
    await VehicleStorage.updateVehicle(vehicle);
    ref.read(vehiclesProvider.notifier).updateVehicleData(vehicle);

    BleBackgroundService.reloadVehicles();
    BleBackgroundService.reloadHomescreenWidget();
  }

  void removeVehicle(String macAddress) async {
    await VehicleStorage.removeVehicle(macAddress);
    ref.read(vehiclesProvider.notifier).removeVehicle(macAddress);

    BleBackgroundService.reloadVehicles();
    BleBackgroundService.reloadHomescreenWidget();

    BleBackgroundService.disconnectDevice(BleDevice(macAddress: macAddress));
  }

  void dispose() {
    commandStream?.cancel();
    connectionStateStream?.cancel();
    reloadStream?.cancel();
    _instance = null;
  }
}

class VehicleStorage {
  static const String _key = 'vehicles';

  static Future<void> reloadPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  static Future<void> saveVehicles(List<VehicleData> vehicles) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      vehicles.map((vehicle) => vehicle.toJson()).toList(),
    );
    await prefs.setString(_key, encodedData);
  }

  static Future<List<VehicleData>> getVehicles() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_key);

    if (encodedData == null) return [];

    final List<dynamic> decodedData = json.decode(encodedData);
    return decodedData.map((item) => VehicleData.fromJson(item)).toList();
  }

  static Future<VehicleData> getVehicle(String macAddress) async {
    final vehicles = await getVehicles();
    return vehicles.firstWhere((vehicle) => vehicle.macAddress == macAddress);
  }

  static Future<void> addVehicle(VehicleData vehicle) async {
    final vehicles = await getVehicles();
    vehicles.add(vehicle);
    await saveVehicles(vehicles);
  }

  static Future<void> updateVehicle(VehicleData updatedVehicle) async {
    final vehicles = await getVehicles();
    final index = vehicles.indexWhere(
        (vehicle) => vehicle.macAddress == updatedVehicle.macAddress);
    if (index != -1) {
      vehicles[index] = updatedVehicle;
      await saveVehicles(vehicles);
    }
  }

  static Future<void> removeVehicle(String macAddress) async {
    final vehicles = await getVehicles();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('counter_$macAddress');
    vehicles.removeWhere((vehicle) => vehicle.macAddress == macAddress);
    await saveVehicles(vehicles);
  }

  static Future<void> clearVehicles() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
