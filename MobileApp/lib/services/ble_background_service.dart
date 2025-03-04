import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BleBackgroundService {
  // This should be in your main.dart before runApp
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Configure local notifications
    // For Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ble_connect_service', // id
      'BLE Auto Connect Service', // title
      description: 'Background service for BLE auto connect',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Configure background service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background
        onStart: onStart,
        // auto start service
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: 'ble_connect_service',
        initialNotificationTitle: 'BLE Auto Connect Service',
        initialNotificationContent: 'Background service for BLE auto connect',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: true,
        // this will be executed when app is in foreground or background
        onForeground: onStart,
        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );

    // Start the service
    //service.startService();
  }

// This is the background isolate function
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground')!.listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground')!.listen((event) {
        service.setAsBackgroundService();
      });

      service.on('stopService')!.listen((event) {
        service.stopSelf();
      });
    }

    print('Background service started...');

    // Periodic task
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Perform your background task here
          print('Background service running...');

          flutterLocalNotificationsPlugin.show(
            888,
            'COOL SERVICE',
            'Awesome ${DateTime.now()}',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'ble_connect_service',
                'MY FOREGROUND SERVICE',
                icon: 'ic_launcher_foreground',
                ongoing: true,
              ),
            ),
          );

          // Optional: Send data back to the main isolate
          service.invoke('update', {
            'current_date': DateTime.now().toIso8601String(),
          });
        }
      } else {
        // iOS-specific background task
        print('iOS background service running...');
      }
    });
  }

// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    return true;
  }
}
