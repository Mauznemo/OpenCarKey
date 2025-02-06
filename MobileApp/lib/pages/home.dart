import 'package:flutter/material.dart';
import 'package:native_shared_preferences/native_shared_preferences.dart';
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

  late String _deviceName = "Not associated";
  Future<void> _requestPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();
  }

  void init() async {
    final NativeSharedPreferences prefs = await _prefs;
    await prefs.reload();
    _deviceName = prefs.getString('device_mac_address') ?? 'Not associated';
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            },
            child: const Text("Add a Vehicle")),
      ],
    ));
  }
}
