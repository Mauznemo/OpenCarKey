import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/custom_dropdown_button.dart';
import '../providers/vehicles_provider.dart';
import '../services/ble_background_service.dart';
import '../services/ble_service.dart';
import '../services/settings_service.dart';
import '../types/ble_commands.dart';
import '../models/vehicle.dart';
import '../utils/esp32_response_parser.dart';

class RangeCalibrationPage extends ConsumerStatefulWidget {
  const RangeCalibrationPage({super.key});

  @override
  ConsumerState<RangeCalibrationPage> createState() =>
      _RangeCalibrationPageState();
}

class _RangeCalibrationPageState extends ConsumerState<RangeCalibrationPage> {
  final FlutterBackgroundService service = FlutterBackgroundService();

  Vehicle? selectedVehicle;
  late Timer timer;
  late StreamSubscription<Map<String, dynamic>?> sub;

  double triggerStrength = -200;

  void readSignalStrength() async {
    if (selectedVehicle == null) return;
    BleBackgroundService.sendCommand(
        selectedVehicle!.device, ClientCommand.GET_RSSI);
  }

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      readSignalStrength();
    });

    sub = service.on('command_received').listen((event) {
      if (event != null) {
        Esp32ResponseParser parser =
            Esp32ResponseParser(List<int>.from(event['data']));
        Esp32Response? command = Esp32Response.fromValue(parser.command);
        if (command == null) {
          return;
        }
        Esp32ResponseDate data = Esp32ResponseDate(
            macAddress: event['macAddress'], command: command, parser: parser);

        if (data.command == Esp32Response.RSSI) {
          setState(() {
            triggerStrength = data.parser.getFloat() ?? -200;
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
    final vehiclesState = ref.watch(vehiclesProvider);

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
            CustomDropdownButton<Vehicle>(
              value: selectedVehicle,
              hint: const Text('Select a device'),
              onChanged: (Vehicle? newValue) {
                setState(() {
                  selectedVehicle = newValue;
                });
              },
              items: vehiclesState.connectedVehicles
                  .map<DropdownMenuItem<Vehicle>>(
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
                    const SizedBox(height: 20),
                    Text(
                        '(Please keep in mind that that objects in between you and the vehicle also effect the signal strength)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 50),
                    Text(
                        'Current signal strength: ${triggerStrength.toStringAsFixed(2)} dBm'),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                          '(This is the unlock strength, lock strength is calculated on the dead zone you set, meaning it is further away)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                    FilledButton(
                        onPressed: () async {
                          SettingsService.instance
                              .setTriggerStrength(triggerStrength);
                          Navigator.pop(context);
                        },
                        child: Text('Set as trigger strength'))
                  ])
          ],
        ),
      ),
    );
  }
}
