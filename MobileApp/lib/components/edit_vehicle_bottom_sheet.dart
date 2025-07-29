import 'dart:io';

import 'package:flutter/material.dart';

import '../services/ble_background_service.dart';
import '../services/ble_service.dart';
import '../services/vehicle_service.dart';
import '../types/vehicle.dart';
import '../utils/image_utils.dart';
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
  final passwordController = TextEditingController();

  File? _selectedImage;
  String imagePath = '';

  bool hasTrunkUnlock = false;
  bool hasEngineStart = false;

  bool noProximityKey = false;

  bool isValid = true;

  Future<void> loadImage() async {
    _selectedImage =
        await ImageUtils.loadSavedImage(widget.vehicle.data.imagePath);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    vehicleNameController.text = widget.vehicle.data.name;
    passwordController.text = widget.vehicle.data.password;
    hasTrunkUnlock = widget.vehicle.data.hasTrunkUnlock;
    hasEngineStart = widget.vehicle.data.hasEngineStart;
    noProximityKey = widget.vehicle.data.noProximityKey;
    imagePath = widget.vehicle.data.imagePath;

    loadImage();
  }

  @override
  void dispose() {
    vehicleNameController.dispose();
    passwordController.dispose();
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
                controller: passwordController,
                labelText: 'Password',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
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
                    setState(() {
                      hasTrunkUnlock = value;
                    });
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
                    setState(() {
                      hasEngineStart = value;
                    });
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Switch(
                  value: noProximityKey,
                  onChanged: (value) {
                    setState(() {
                      noProximityKey = value;
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
            const SizedBox(
              height: 20,
            ),
            FilledButton.icon(
                onPressed: () async {
                  isValid = formKey.currentState!.validate() == true;

                  if (!isValid) return;

                  final sharedSecret = BleService.generateSharedSecret(
                      passwordController.text.trim());

                  await VehicleStorage.updateVehicle(VehicleData(
                      name: vehicleNameController.text,
                      macAddress: widget.vehicle.data.macAddress,
                      password: passwordController.text.trim(),
                      sharedSecret: sharedSecret,
                      hasTrunkUnlock: hasTrunkUnlock,
                      hasEngineStart: hasEngineStart,
                      noProximityKey: noProximityKey,
                      imagePath: imagePath));

                  vehicleNameController.clear();
                  passwordController.clear();
                  if (context.mounted) Navigator.pop(context);
                  setState(() {});

                  BleBackgroundService.reloadHomescreenWidget();
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
