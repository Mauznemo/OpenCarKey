import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/image_utils.dart';

class VehicleImagePicker extends StatefulWidget {
  final String imagePath;
  final Function(String imagePath) onImageSelected;
  const VehicleImagePicker({
    super.key,
    required this.imagePath,
    required this.onImageSelected,
  });

  @override
  State<VehicleImagePicker> createState() => _VehicleImagePickerState();
}

class _VehicleImagePickerState extends State<VehicleImagePicker> {
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    _selectedImage = ImageUtils.loadSavedImage(widget.imagePath);
    setState(() {});
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.3),
      builder: (BuildContext mContext) {
        final rootContext = context;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 10),
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Gallery'),
                  onTap: () async {
                    Navigator.pop(mContext);
                    await ImageUtils.deleteImage(widget.imagePath);
                    _selectedImage = await ImageUtils.pickImageFromGallery(
                      rootContext,
                    );
                    setState(() {});
                    widget.onImageSelected(_selectedImage?.path ?? '');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Camera'),
                  onTap: () async {
                    Navigator.pop(context);
                    await ImageUtils.deleteImage(widget.imagePath);
                    _selectedImage = await ImageUtils.pickImageFromCamera(
                      rootContext,
                    );
                    setState(() {});
                    widget.onImageSelected(_selectedImage?.path ?? '');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(36),
      ),
      child: _selectedImage != null
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(35),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(150),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => _showImageSourceOptions(),
                        icon: Icon(Icons.edit, color: Colors.white, size: 25),
                        padding: EdgeInsets.all(4),
                        constraints: BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(150),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () async {
                          await ImageUtils.deleteImage(widget.imagePath);
                          _selectedImage = null;
                          setState(() {});
                          widget.onImageSelected('');
                        },
                        icon: Icon(Icons.delete, color: Colors.white, size: 25),
                        padding: EdgeInsets.all(4),
                        constraints: BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
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
                    Icon(Icons.add_a_photo, size: 30, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No background image selected',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
