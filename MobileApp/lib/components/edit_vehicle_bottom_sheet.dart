import 'package:flutter/material.dart';

import '../services/vehicle_service.dart';
import '../models/vehicle.dart';
import '../types/vehicle_data.dart';
import '../widgets/vehicle_image_picker.dart';

class EditVehicleBottomSheet extends StatefulWidget {
  final Vehicle vehicle;

  const EditVehicleBottomSheet({super.key, required this.vehicle});

  static Future<void> showBottomSheet(
    BuildContext context,
    Vehicle vehicle,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.3),
      builder: (BuildContext context) {
        return EditVehicleBottomSheet(vehicle: vehicle);
      },
    );
  }

  @override
  State<EditVehicleBottomSheet> createState() => _EditVehicleBottomSheetState();
}

class _EditVehicleBottomSheetState extends State<EditVehicleBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNameController = TextEditingController();

  String _imagePath = '';

  bool _noProximityKey = false;

  @override
  void initState() {
    super.initState();
    _vehicleNameController.text = widget.vehicle.data.name;
    _noProximityKey = widget.vehicle.data.noProximityKey;
    _imagePath = widget.vehicle.data.imagePath;
  }

  @override
  void dispose() {
    _vehicleNameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    VehicleService.instance.updateVehicleData(
      VehicleData(
        name: _vehicleNameController.text.trim(),
        macAddress: widget.vehicle.data.macAddress,
        sharedSecret: widget.vehicle.data.sharedSecret,
        features: widget.vehicle.data.features,
        noProximityKey: _noProximityKey,
        imagePath: _imagePath,
      ),
    );

    _vehicleNameController.clear();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 32),
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit Vehicle',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle Name',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _vehicleNameController,
                            decoration: InputDecoration(
                              hintText: 'Enter vehicle name',
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withAlpha(66),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a vehicle name';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 16),

                          Text(
                            'Background Image',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 8),

                          VehicleImagePicker(
                            imagePath: _imagePath,
                            onImageSelected: (imagePath) {
                              setState(() {
                                _imagePath = imagePath;
                              });
                            },
                          ),

                          SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Switch(
                                value: _noProximityKey,
                                onChanged: (value) {
                                  setState(() {
                                    _noProximityKey = value;
                                  });
                                },
                              ),
                              SizedBox(width: 10),
                              SizedBox(
                                width: 180,
                                child: const Text(
                                  'Ignore Proximity Key',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            icon: Icon(Icons.check),
                            label: Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
