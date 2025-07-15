import 'dart:typed_data';
import 'dart:ui';

import 'package:crop_image/crop_image.dart';
import 'package:flutter/material.dart';

class CropImageScreen extends StatefulWidget {
  final Uint8List imageData;
  final double aspectRatio;

  const CropImageScreen({
    Key? key,
    required this.imageData,
    this.aspectRatio = 500 / 150,
  }) : super(key: key);

  @override
  State<CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends State<CropImageScreen> {
  late CropController controller;

  @override
  void initState() {
    super.initState();
    print('init state');
    controller = CropController(
      aspectRatio: widget.aspectRatio,
      defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    );
  }

  @override
  void dispose() {
    print('dispose');
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDone() async {
    final bitmap = await controller.croppedBitmap();
    final data = await bitmap.toByteData(format: ImageByteFormat.png);
    final croppedImage = data!.buffer.asUint8List();
    Navigator.of(context).pop(croppedImage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
        actions: [
          TextButton(
            onPressed: _onDone,
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Center(
        child: CropImage(
          controller: controller,
          image: Image.memory(widget.imageData),
          paddingSize: 25.0,
          alwaysMove: true,
          minimumImageSize: 200,
          maximumImageSize: 1800,
        ),
      ),
    );
  }
}
