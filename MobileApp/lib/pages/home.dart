import 'package:flutter/material.dart';
import 'package:native_shared_preferences/native_shared_preferences.dart';
import 'package:open_car_key_app/services/ble_service.dart';
import 'package:open_car_key_app/services/vehicle.dart';
import 'package:permission_handler/permission_handler.dart';

import '../components/add_vehicle_bottom_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<NativeSharedPreferences> _prefs =
      NativeSharedPreferences.getInstance();

  List<Vehicle> _vehicles = [];

  late String _deviceName = "Not associated";
  Future<void> _requestPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();
  }

  void _getVehicles() async {
    _vehicles = await VehicleStorage.getVehicles();
    setState(() {});
  }

  void init() async {
    final NativeSharedPreferences prefs = await _prefs;
    await prefs.reload();
    _deviceName = prefs.getString('device_mac_address') ?? 'Not associated';
    setState(() {});
    var associated = await BleService.getAssociated();
    print("!!!!!!!!!!!!!!!!!!!!!!!!!!Associated: $associated");
  }

  @override
  void initState() {
    super.initState();
    init();
    _getVehicles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ListView.builder(
            shrinkWrap: true,
            itemCount: _vehicles.length,
            itemBuilder: (context, index) {
              Vehicle vehicle = _vehicles[index];
              return ListTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, style: const TextStyle(fontSize: 20)),
                    Text(
                        "Mac Address: ${vehicle.macAddress}, Association ID: ${vehicle.associationId}",
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    // Delete vehicle from Hive box
                    VehicleStorage.removeVehicle(vehicle.macAddress);

                    print("Removing Association ID: ${vehicle.associationId}");
                    await BleService.disassociateBle(
                        vehicle.associationId, vehicle.macAddress);

                    _getVehicles();
                    setState(() {});
                  },
                ),
              );
            }),
        Text("Device Mac Address: $_deviceName"),
        FilledButton(
            onPressed: () async {
              await _requestPermission();
              await AddVehicleBottomSheet.showBottomSheet(context);
              //BleService.associateBle();
              final NativeSharedPreferences prefs = await _prefs;
              await prefs.reload();
              _deviceName =
                  prefs.getString('device_mac_address') ?? 'Not associated';
              setState(() {});
              _getVehicles();
            },
            child: const Text("Add a Vehicle")),
      ],
    ));
  }
}
