import 'package:flutter/material.dart';

import '../services/ble_background_service.dart';
import '../services/vehicle_service.dart';
import '../types/ble_device.dart';
import '../types/vehicle.dart';
import 'scan_dialog.dart';

class AddVehicleBottomSheet extends StatefulWidget {
  const AddVehicleBottomSheet({super.key});

  static Future<void> showBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return AddVehicleBottomSheet();
        });
  }

  @override
  State<AddVehicleBottomSheet> createState() => _AddVehicleBottomSheetState();
}

class _AddVehicleBottomSheetState extends State<AddVehicleBottomSheet> {
  final formKey = GlobalKey<FormState>();
  final vehicleNameController = TextEditingController();
  final pinController = TextEditingController();

  bool hasTrunkUnlock = false;
  bool hasEngineStart = false;

  bool isValid = true;

  @override
  void dispose() {
    vehicleNameController.dispose();
    pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: formKey,
        onChanged: () {
          if (!isValid) formKey.currentState?.validate();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 200),
              child: Divider(thickness: 4),
            ),
            const Text(
              'Add Vehicle',
              style: TextStyle(fontSize: 24),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: vehicleNameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a vehicle name';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Vehicle Name',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: pinController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a pin';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Pin',
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Switch(
                  value: hasTrunkUnlock,
                  onChanged: (value) {
                    setState(() => hasTrunkUnlock = value);
                  },
                ),
                SizedBox(width: 10),
                const Text(
                  'Has Trunk Unlock',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Switch(
                  value: hasEngineStart,
                  onChanged: (value) {
                    setState(() => hasEngineStart = value);
                  },
                ),
                SizedBox(width: 10),
                const Text(
                  'Has Remote Engine Start',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.icon(
                onPressed: () async {
                  isValid = formKey.currentState!.validate() == true;

                  if (!isValid) return;

                  final connectedDevice = await showDialog(
                    context: context,
                    builder: (context) => const ScanDialog(),
                  ) as BleDevice?;

                  print(connectedDevice);

                  if (connectedDevice == null)
                    return print('No device connected');

                  BleBackgroundService.sendMessage(
                      connectedDevice, 'AUTH:${pinController.text.trim()}');

                  VehicleStorage.addVehicle(
                    VehicleData(
                      name: vehicleNameController.text.trim(),
                      macAddress: connectedDevice.macAddress,
                      pin: pinController.text.trim(),
                      hasTrunkUnlock: hasTrunkUnlock,
                      hasEngineStart: hasEngineStart,
                    ),
                  );
                  vehicleNameController.clear();
                  pinController.clear();
                  if (context.mounted) Navigator.pop(context);
                  setState(() {});
                },
                icon: Icon(Icons.add),
                label: Text('Connect now')),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
