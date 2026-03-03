import 'package:flutter/material.dart';

import '../services/ble_service.dart';
import '../services/vehicle_service.dart';
import '../models/ble_device.dart';
import '../types/features.dart';
import '../types/vehicle_data.dart';
import '../widgets/vehicle_image_picker.dart';
import 'scan_dialog.dart';

class AddVehicleBottomSheet extends StatefulWidget {
  const AddVehicleBottomSheet({super.key});

  static Future<void> showBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.3),
      builder: (BuildContext context) {
        return AddVehicleBottomSheet();
      },
    );
  }

  @override
  State<AddVehicleBottomSheet> createState() => _AddVehicleBottomSheetState();
}

class _AddVehicleBottomSheetState extends State<AddVehicleBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _imagePath = '';

  @override
  void dispose() {
    _vehicleNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connectAndAdd() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await BleService.requestBluetoothPermissions();

    if (!mounted) return;

    final connectedDevice =
        await showDialog(
              context: context,
              builder: (context) => const ScanDialog(),
            )
            as BleDevice?;

    if (connectedDevice == null) return;

    final sharedSecret = BleService.generateSharedSecret(
      _passwordController.text.trim(),
    );

    VehicleService.instance.addVehicle(
      VehicleData(
        name: _vehicleNameController.text.trim(),
        macAddress: connectedDevice.macAddress,
        sharedSecret: sharedSecret,
        features: {Feature.doorsLock},
        imagePath: _imagePath,
      ),
    );

    _vehicleNameController.clear();
    _passwordController.clear();

    if (mounted) Navigator.pop(context);
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
                      'Add New Vehicle',
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
                            'Password',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              hintText: 'Enter password',
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
                                return 'Please enter a password';
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _connectAndAdd,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            icon: Icon(Icons.add),
                            label: Text('Connect and save'),
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
