import 'package:flutter/material.dart';

import '../services/vehicle.dart';

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
  final _vehicleNameController = TextEditingController();
  final _pinController = TextEditingController();

  bool _hasTrunkUnlock = false;
  bool _hasEngineStart = false;

  @override
  void initState() {
    super.initState();
    _vehicleNameController.text = widget.vehicle.name;
    _pinController.text = widget.vehicle.pin;
    _hasTrunkUnlock = widget.vehicle.hasTrunkUnlock;
    _hasEngineStart = widget.vehicle.hasEngineStart;
  }

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
            'Edit Vehicle',
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
                    _pinController.text.isEmpty ||
                    widget.vehicle.macAddress.isEmpty) {
                  return;
                }

                await VehicleStorage.updateVehicle(Vehicle(
                    name: _vehicleNameController.text,
                    macAddress: widget.vehicle.macAddress,
                    associationId: widget.vehicle.associationId,
                    pin: _pinController.text,
                    hasTrunkUnlock: _hasTrunkUnlock,
                    hasEngineStart: _hasEngineStart));
                _vehicleNameController.clear();
                _pinController.clear();
                Navigator.pop(context);
                //_vehicles = ObjectBox.instance.getVehicles();
                setState(() {});
              },
              icon: Icon(Icons.check),
              label: Text("Done")),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
