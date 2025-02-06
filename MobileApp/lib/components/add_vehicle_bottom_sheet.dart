import 'package:flutter/material.dart';

import '../services/ble_service.dart';

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
          FilledButton.icon(
              onPressed: () async {
                if (_vehicleNameController.text.isEmpty ||
                    _pinController.text.isEmpty) {
                  return;
                }

                await BleService.associateBle();
                _vehicleNameController.clear();
                _pinController.clear();
                Navigator.pop(context);
                //_vehicles = ObjectBox.instance.getVehicles();
                setState(() {});
              },
              icon: Icon(Icons.add),
              label: Text("Connect now")),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
