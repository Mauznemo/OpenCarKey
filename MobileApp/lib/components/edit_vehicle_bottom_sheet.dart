import 'package:flutter/material.dart';

import '../services/ble_background_service.dart';
import '../services/vehicle_service.dart';
import '../types/vehicle.dart';
import 'custom_text_form_field.dart';

typedef EditVehicleBottomSheetCallback = void Function(Vehicle vehicle);

class EditVehicleBottomSheet extends StatefulWidget {
  final Vehicle vehicle;

  const EditVehicleBottomSheet({super.key, required this.vehicle});

  static Future<void> showBottomSheet(
      BuildContext context, Vehicle vehicle) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return EditVehicleBottomSheet(
            vehicle: vehicle,
          );
        });
  }

  @override
  State<EditVehicleBottomSheet> createState() => _EditVehicleBottomSheetState();
}

class _EditVehicleBottomSheetState extends State<EditVehicleBottomSheet> {
  final formKey = GlobalKey<FormState>();
  final vehicleNameController = TextEditingController();
  final pinController = TextEditingController();

  bool hasTrunkUnlock = false;
  bool hasEngineStart = false;

  bool isValid = true;

  @override
  void initState() {
    super.initState();
    vehicleNameController.text = widget.vehicle.data.name;
    pinController.text = widget.vehicle.data.pin;
    hasTrunkUnlock = widget.vehicle.data.hasTrunkUnlock;
    hasEngineStart = widget.vehicle.data.hasEngineStart;
  }

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
              'Edit Vehicle',
              style: TextStyle(fontSize: 24),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomTextFormField(
                controller: vehicleNameController,
                labelText: 'Vehicle Name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a vehicle name';
                  }
                  return null;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomTextFormField(
                controller: pinController,
                labelText: 'Pin',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a pin';
                  }
                  return null;
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Switch(
                  value: hasTrunkUnlock,
                  onChanged: (value) {
                    setState(() {
                      hasTrunkUnlock = value;
                    });
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
                    setState(() {
                      hasEngineStart = value;
                    });
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

                  BleBackgroundService.sendMessage(
                      widget.vehicle.device, 'AUTH:${pinController.text}');

                  await VehicleStorage.updateVehicle(VehicleData(
                      name: vehicleNameController.text,
                      macAddress: widget.vehicle.data.macAddress,
                      pin: pinController.text,
                      hasTrunkUnlock: hasTrunkUnlock,
                      hasEngineStart: hasEngineStart));
                  vehicleNameController.clear();
                  pinController.clear();
                  if (context.mounted) Navigator.pop(context);
                  setState(() {});
                },
                icon: Icon(Icons.check),
                label: Text('Done')),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
