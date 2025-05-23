import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

  static Future<File?> pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 80,
      );

      if (image != null) {
        final tempImage = File(image.path);
        final savedImage = await saveImagePermanently(tempImage);

        if (savedImage != null) {
          return savedImage;
        }
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  static Future<File?> pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 80,
      );

      if (image != null) {
        final tempImage = File(image.path);
        final savedImage = await saveImagePermanently(tempImage);

        if (savedImage != null) {
          return savedImage;
        }
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
