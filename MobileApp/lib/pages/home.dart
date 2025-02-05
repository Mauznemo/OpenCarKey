import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/ble_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _requestPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: FilledButton(
          onPressed: () async {
            await _requestPermission();
            BleService.associateBle();
          },
          child: const Text("associateBle")),
    ));
  }
}
