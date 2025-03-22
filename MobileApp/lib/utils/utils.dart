import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_background_service.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> initializeApp() async {
  await initializeBle();
  await initializeBackgroundService();
}

Future<void> initializeBackgroundService() async {
  await BleBackgroundService.initializeService();
}

Future<void> initializeBle() async {
  if (await FlutterBluePlus.isSupported == false) {
    print('Bluetooth not supported by this device');
    return;
  }

  if (!kIsWeb && Platform.isAndroid) {
    try {
      await FlutterBluePlus.turnOn();
    } on Exception catch (e) {
      print('Error while turning on Bluetooth: $e');
    }
  }

  FlutterBluePlus.setOptions(restoreState: true);
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
