import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<void> initializeApp() async {
  await initializeBle();
}

Future<void> initializeBle() async {
  if (await FlutterBluePlus.isSupported == false) {
    print("Bluetooth not supported by this device");
    return;
  }

  if (!kIsWeb && Platform.isAndroid) {
    await FlutterBluePlus.turnOn();
  }
}