import 'dart:io';

import 'package:flutter/material.dart';

import '../services/ble_background_service.dart';
import '../services/ble_service.dart';
import '../services/vehicle_service.dart';
import '../types/ble_device.dart';
import '../types/vehicle.dart';
import '../utils/image_utils.dart';
import 'custom_text_form_field.dart';
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

  File? _selectedImage;
  String imagePath = '';

  bool isValid = true;

  @override
  void dispose() {
    vehicleNameController.dispose();
    pinController.dispose();
    super.dispose();
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext mContext) {
        final rootContext = context;
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Gallery'),
                onTap: () async {
                  Navigator.pop(mContext);
                  await ImageUtils.deleteImage(imagePath);
                  _selectedImage =
                      await ImageUtils.pickImageFromGallery(rootContext);
                  setState(() {});
                  imagePath = _selectedImage?.path ?? '';
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  await ImageUtils.deleteImage(imagePath);
                  _selectedImage =
                      await ImageUtils.pickImageFromCamera(rootContext);
                  setState(() {});
                  imagePath = _selectedImage?.path ?? '';
                },
              ),
            ],
          ),
        );
      },
    );
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: _selectedImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha(150),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () => _showImageSourceOptions(),
                                  icon: Icon(Icons.edit,
                                      color: Colors.white, size: 25),
                                  padding: EdgeInsets.all(4),
                                  constraints: BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha(150),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () async {
                                    await ImageUtils.deleteImage(imagePath);
                                    imagePath = '';
                                    _selectedImage = null;
                                    setState(() {});
                                  },
                                  icon: Icon(Icons.delete,
                                      color: Colors.white, size: 25),
                                  padding: EdgeInsets.all(4),
                                  constraints: BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: _showImageSourceOptions,
                        borderRadius: BorderRadius.circular(50),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 30,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No background image selected',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                SizedBox(
                  width: 180,
                  child: const Text(
                    'Has Trunk Unlock',
                    style: TextStyle(fontSize: 16),
                  ),
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
                SizedBox(
                  width: 180,
                  child: const Text(
                    'Has Remote Engine Start',
                    style: TextStyle(fontSize: 16),
                  ),
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

                  await BleService.requestBluetoothPermissions();

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
                        imagePath: imagePath),
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
