import 'package:flutter/material.dart';

import '../services/ble_service.dart';
import '../services/vehicle.dart';

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
  final _vehicleNameController = TextEditingController();
  final _pinController = TextEditingController();

  bool _hasTrunkUnlock = false;
  bool _hasEngineStart = false;

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed.
    _vehicleNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            child: TextField(
              controller: _vehicleNameController,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                labelText: 'Vehicle Name',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _pinController,
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
                value: _hasTrunkUnlock,
                onChanged: (value) {
                  setState(() {
                    _hasTrunkUnlock = value;
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
                value: _hasEngineStart,
                onChanged: (value) {
                  setState(() {
                    _hasEngineStart = value;
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
                if (_vehicleNameController.text.isEmpty ||
                    _pinController.text.isEmpty) {
                  return;
                }

                var result = await BleService.associateBle();
                if (!result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result.errorMessage),
                  ));
                } else {
                  VehicleStorage.addVehicle(Vehicle(
                      name: _vehicleNameController.text,
                      macAddress: result.macAddress,
                      associationId: result.associationId,
                      pin: _pinController.text,
                      hasTrunkUnlock: _hasTrunkUnlock,
                      hasEngineStart: _hasEngineStart));
                  _vehicleNameController.clear();
                  _pinController.clear();
                  Navigator.pop(context);
                  //_vehicles = ObjectBox.instance.getVehicles();
                  setState(() {});
                }
              },
              icon: Icon(Icons.add),
              label: Text("Connect now")),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
