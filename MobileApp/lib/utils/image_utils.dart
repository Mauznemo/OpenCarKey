import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../components/image_crop_screen.dart';
import '../services/vehicle_service.dart';

class ImageUtils {
  static Future<File?> saveImagePermanently(File tempImage) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'saved_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = File(path.join(directory.path, fileName));

      await tempImage.copy(savedImage.path);

      return savedImage;
    } catch (e) {
      print('Error saving image: $e');
      return null;
    }
  }

  static Future<void> deleteUnusedImages() async {
    final vehiclesData = await VehicleStorage.getVehicles();
    final directory = await getApplicationDocumentsDirectory();

    final List<File> imageFiles = directory
        .listSync()
        .where((item) => item.path.endsWith('.jpg'))
        .map((item) => File(item.path))
        .toList();

    for (var imageFile in imageFiles) {
      if (!vehiclesData.any((vehicle) => vehicle.imagePath == imageFile.path)) {
        await deleteImage(imageFile.path);
      }
    }
  }

  static Future<File?> loadSavedImage(String imagePath) async {
    try {
      if (imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          return file;
        }
      }
      return null;
    } catch (e) {
      print('Error loading saved image: $e');
      return null;
    }
  }

  static Future<File?> pickImageFromGallery(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 80,
      );
      if (image != null) {
        final Uint8List imageData = await image.readAsBytes();

        final Uint8List? croppedData = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(
            builder: (_) => CropImageScreen(imageData: imageData),
          ),
        );

        if (croppedData == null) return null;

        final dir = await getApplicationDocumentsDirectory();
        final file = File(
            '${dir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(croppedData);
        return file;
      }

      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  static Future<File?> pickImageFromCamera(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 80,
      );

      if (image != null) {
        final Uint8List imageData = await image.readAsBytes();

        final Uint8List? croppedData = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(
            builder: (_) => CropImageScreen(imageData: imageData),
          ),
        );

        if (croppedData == null) return null;

        final dir = await getApplicationDocumentsDirectory();
        final file = File(
            '${dir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(croppedData);
        return file;
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  static Future<void> deleteImage(String imagePath) async {
    try {
      if (imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        } else {
          print('Image file does not exist.');
        }
      }
    } catch (e) {
      print('Error deleting image: $e');
    }
  }
}
