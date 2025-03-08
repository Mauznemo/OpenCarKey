import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ble_background_service.dart';
import '../services/vehicle_service.dart';
import '../types/ble_device.dart';
import '../types/vehicle.dart';

class RangeCalibrationPage extends StatefulWidget {
  const RangeCalibrationPage({super.key});

  @override
  State<RangeCalibrationPage> createState() => _RangeCalibrationPageState();
}

class _RangeCalibrationPageState extends State<RangeCalibrationPage> {
  final FlutterBackgroundService service = FlutterBackgroundService();
  late SharedPreferences prefs;
  List<Vehicle> connectedVehicles = [];
  List<BleDevice> connectedDevices = [];
  Vehicle? selectedVehicle;
  late Timer timer;
  late StreamSubscription<Map<String, dynamic>?> sub;

  double triggerStrength = -200;

  void loadPrefs() async {
    prefs = await SharedPreferences.getInstance();

    triggerStrength = prefs.getDouble('triggerStrength') ?? -200;

    final vehiclesData = await VehicleStorage.getVehicles();

    setState(() {
      connectedVehicles = vehiclesData
          .map((vehicle) => Vehicle(
                device: BleDevice(
                    macAddress: vehicle.macAddress,
                    isConnected: connectedDevices.any(
                        (element) => element.macAddress == vehicle.macAddress)),
                data: vehicle,
              ))
          .toList()
          .where((element) => element.device.isConnected)
          .toList();
    });
  }

  void getConnectedDevices() async {
    if (!mounted) return;

    setState(() {});

    connectedDevices = await BleBackgroundService.getConnectedDevices();
  }

  void readSignalStrength() async {
    if (selectedVehicle == null) return;
    BleBackgroundService.sendMessage(selectedVehicle!.device, 'RSSI');
  }

  @override
  void initState() {
    super.initState();
    getConnectedDevices();
    loadPrefs();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      readSignalStrength();
    });

    sub = service.on('message_received').listen((event) {
      if (event != null) {
        if (event['message'].startsWith('RSSI:')) {
          setState(() {
            triggerStrength = double.parse(event['message'].split(':')[1]);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Range Calibration')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select a vehicle to use as reference (needs to be connected)',
              ),
            ),
            DropdownButton<Vehicle>(
              value: selectedVehicle,
              isExpanded: true,
              hint: const Text('Select a device'),
              onChanged: (Vehicle? newValue) {
                setState(() {
                  selectedVehicle = newValue;
                });
              },
              items: connectedVehicles.map<DropdownMenuItem<Vehicle>>(
                (Vehicle vehicle) {
                  return DropdownMenuItem<Vehicle>(
                    value: vehicle,
                    child: Text(
                      vehicle.data.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ).toList(),
            ),
            selectedVehicle == null
                ? Container()
                : Column(children: [
                    const SizedBox(height: 150),
                    Text(
                        'Now go away from you vehicle until you are at the distance where proximity key should unlock and lock.',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 50),
                    Text(
                        'Current signal strength: ${triggerStrength.toStringAsFixed(2)} dBm'),
                    const SizedBox(height: 10),
                    FilledButton(
                        onPressed: () async {
                          await prefs.setDouble(
                              'triggerStrength', triggerStrength);
                          BleBackgroundService.setProximityStrength(
                              triggerStrength);
                          setState(() {});
                          Navigator.pop(context);
                        },
                        child: Text('Set distance'))
                  ])
          ],
        ),
      ),
    );
  }
}
