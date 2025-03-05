import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../types/ble_device.dart';
import '../types/vehicle.dart';
import 'ble_service.dart';
import 'vehicle_service.dart';

class BleBackgroundService {
  static List<BackgroundVehicle> vehicles = [];
  static final FlutterBackgroundService _service = FlutterBackgroundService();
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
        initialNotificationTitle: 'Waiting for connection',
        initialNotificationContent: 'Go near your vehicle to connect',
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
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });

      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }

    print('Background service started...');

    service.on('reload_vehicles').listen((event) async {
      await VehicleStorage.reloadPrefs();
      _getVehicles();
    });

    service.on('send_message').listen((event) {
      if (event == null) return;
      BluetoothDevice device = BluetoothDevice.fromId(event['macAddress']);
      String message = event['message'];
      BleService.sendMessage(device, message);
    });

    service.on('disconnect_device').listen((event) {
      if (event == null) return;
      BluetoothDevice device = BluetoothDevice.fromId(event['macAddress']);
      BleService.disconnectDevice(device);
    });

    service.on('connect_to_device').listen((event) async {
      final macAddress = event?['macAddress'];
      final requestId = event?['requestId'];

      if (macAddress == null || requestId == null) {
        return;
      }

      try {
        final bluetoothDevice = await BleService.connectToDevice(
            BluetoothDevice.fromId(macAddress));

        // Send the result back
        service.invoke('connect_result', {
          'requestId': requestId,
          'macAddress': bluetoothDevice?.remoteId.str
        });
      } catch (e) {
        service.invoke(
            'connect_result', {'requestId': requestId, 'error': e.toString()});
      }
    });

    FlutterBluePlus.events.onConnectionStateChanged.listen((event) async {
      print('Connection state changed: ${event.connectionState}');

      if (vehicles.isEmpty) {
        await VehicleStorage.reloadPrefs();
        await _getVehicles();
      }

      if (vehicles.isEmpty) return;

      BackgroundVehicle changedVehicle = vehicles.firstWhere(
          (backgroundVehicle) =>
              backgroundVehicle.device.remoteId == event.device.remoteId);

      changedVehicle.device = event.device;

      if (event.connectionState == BluetoothConnectionState.connected) {
        _updateNotification(
            flutterLocalNotificationsPlugin,
            'Connected to ${changedVehicle.data.name}',
            '${changedVehicle.data.name} is connected');
        // Give the connection a moment to stabilize
        await Future.delayed(Duration(milliseconds: 500));
        await BleService.sendMessage(
            changedVehicle.device, 'AUTH:${changedVehicle.data.pin}');
        await BleService.sendMessage(changedVehicle.device, 'ds');

        int rssi = await changedVehicle.device.readRssi();
        List<BleDevice> connectedDevicesMacs = [];
        for (var vehicle in vehicles) {
          if (vehicle.device.isConnected) {
            connectedDevicesMacs.add(BleDevice(
                macAddress: vehicle.device.remoteId.str,
                isConnected: true,
                rssi: rssi));
          }
        }
        await BleDeviceStorage.saveBleDevices(connectedDevicesMacs);

        service.invoke(
          'connection_state_changed',
          {
            'macAddress': event.device.remoteId.toString(),
            'connectionState': event.connectionState.toString(),
          },
        );
      } else if (event.connectionState ==
          BluetoothConnectionState.disconnected) {
        _updateNotification(
            flutterLocalNotificationsPlugin,
            'Disconnected from ${changedVehicle.data.name}',
            '${changedVehicle.data.name} is disconnected. Waiting for connection');
      }
    });

    FlutterBluePlus.events.onCharacteristicReceived.listen((event) {
      print('Characteristic received: ${utf8.decode(event.value)}');

      service.invoke(
        'message_received',
        {
          'macAddress': event.device.remoteId.toString(),
          'message': utf8.decode(event.value),
        },
      );
      //processMessage(event.device.remoteId.toString(), utf8.decode(event.value));
    });

    _getVehicles();

    // Periodic task
    /*Timer.periodic(const Duration(hours: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Perform your background task here
          print('Background service running...');



          // Optional: Send data back to the main isolate
          service.invoke('update', {
            'current_date': DateTime.now().toIso8601String(),
          });
        }
      } else {
        // iOS-specific background task
        print('iOS background service running...');
      }
    });*/
  }

  // iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    return true;
  }

  static Future<void> _getVehicles() async {
    final vehiclesData = await VehicleStorage.getVehicles();

    vehicles = vehiclesData
        .map((vehicle) => BackgroundVehicle(
              device: BluetoothDevice.fromId(vehicle.macAddress),
              data: vehicle,
            ))
        .toList();

    _connectDevices();
  }

  static void _connectDevices() async {
    for (final vehicle in vehicles) {
      await BleService.connectToDevice(vehicle.device);
    }
  }

  static void _updateNotification(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
      String title,
      String message) {
    flutterLocalNotificationsPlugin.show(
      888,
      title,
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ble_connect_service',
          'Background service for BLE auto connect',
          icon: 'ic_launcher_foreground',
          ongoing: true,
        ),
      ),
    );
  }

  //Functions to call from app/foreground
  static Future<List<BleDevice>> getConnectedDevices() async {
    return await BleDeviceStorage.loadBleDevices();
  }

  static Future<BleDevice> connectToDevice(BluetoothDevice device) async {
    // Create a unique ID for this request
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();

    final completer = Completer<BleDevice>();

    final subscription = _service.on('connect_result').listen((response) {
      if (response != null && response['requestId'] == requestId) {
        if (response.containsKey('error')) {
          completer.completeError(response['error']);
        } else {
          completer.complete(BleDevice(macAddress: response['macAddress']));
        }
        //subscription.cancel(); //TODO: Cancel the subscription after getting the response
      }
    });

    // Send the request with the request ID
    _service.invoke('connect_to_device',
        {'macAddress': device.remoteId.str, 'requestId': requestId});

    // Add timeout handling
    Timer(Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError('Connection timeout');
        subscription.cancel();
      }
    });

    return completer.future;
  }

  static void reloadVehicles() {
    _service.invoke('reload_vehicles', {});
  }

  static void disconnectDevice(BleDevice device) {
    _service.invoke('disconnect_device', {'macAddress': device.macAddress});
  }

  static void sendMessage(BleDevice device, String message) {
    _service.invoke(
        'send_message', {'macAddress': device.macAddress, 'message': message});
  }
}
