import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ble_background_service.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> initializeApp() async {
  // Registers the port the background isolate uses to send data back to the
  // main isolate (FlutterForegroundTask.sendDataToMain). Must run before any
  // FlutterForegroundTask.addTaskDataCallback in the UI.
  FlutterForegroundTask.initCommunicationPort();
  await _requestForegroundTaskPermissions();
  await initializeBle();
  initializeBackgroundService();
}

Future<void> _requestForegroundTaskPermissions() async {
  // Needed on Android 13+ so the foreground-service notification is shown.
  final NotificationPermission notificationPermission =
      await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  if (kIsWeb || !Platform.isAndroid) return;

  // A reliable proximity key needs the service exempt from battery
  // optimization; prompt the user if it isn't already.
  if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }
}

Future<void> initializeBackgroundService() async {
  final prefs = await SharedPreferences.getInstance();
  final bool backgroundServiceEnabled =
      prefs.getBool('backgroundService') ?? true;
  await BleBackgroundService.initializeService(
      backgroundServiceEnabled: backgroundServiceEnabled);
  print('Background service initialized!');
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
