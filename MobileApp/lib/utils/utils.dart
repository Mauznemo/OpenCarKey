import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> initializeApp() async {
  await initializeBle();
}

Future<void> initializeBle() async {
  if (await FlutterBluePlus.isSupported == false) {
    print('Bluetooth not supported by this device');
    return;
  }

  if (!kIsWeb && Platform.isAndroid) {
    await FlutterBluePlus.turnOn();
  }
}

IconData getConnectionStateIcon(BluetoothConnectionState state) {
  switch (state) {
    case BluetoothConnectionState.connected:
      return Icons.bluetooth_connected_rounded;
    case BluetoothConnectionState.disconnected:
      return Icons.bluetooth_disabled_rounded;
    default:
      return Icons.bluetooth_disabled_rounded;
  }
}