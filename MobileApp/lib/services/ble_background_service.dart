import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../types/ble_device.dart';
import '../types/vehicle.dart';
import 'ble_service.dart';
import 'vehicle_service.dart';

@pragma('vm:entry-point')
class BleBackgroundService {
  static List<BackgroundVehicle> vehicles = [];
  static List<String> _proxyLocked = [];
  static final ValueNotifier<MessageData> _onMessageReceived =
      ValueNotifier<MessageData>(MessageData('', ''));
  static List<StreamSubscription?> _subscriptions = [];
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static late SharedPreferences _prefs;
  static bool _proximityKeyEnabled = false;
  static double _proximityStrength = 100;
  static bool _vibrate = true;
  static double _deadZone = 4;
  static double _proximityCooldown = 1;

  // This should be in your main.dart before runApp
  static Future<void> initializeService() async {
    await Permission.notification.request();

    final service = FlutterBackgroundService();

    // Configure local notifications
    // For Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ble_connect_service', // id
      'BLE Background Service', // title
      description: 'Background service for BLE proximity key',
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
        initialNotificationTitle: 'Initializing',
        initialNotificationContent: 'Initializing BLE Service...',
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

    _updateNotification(flutterLocalNotificationsPlugin,
        'Waiting for connection...', 'Go near a vehicle to connect.');

    await BleDeviceStorage.clearBleDevices();

    _prefs = await SharedPreferences.getInstance();
    _proximityKeyEnabled = _prefs.getBool('proximityKey') ?? false;
    _proximityStrength = _prefs.getDouble('triggerStrength') ?? -200;
    _deadZone = _prefs.getDouble('deadZone') ?? 4;
    _vibrate = _prefs.getBool('vibrate') ?? true;
    _proximityCooldown = _prefs.getDouble('proximityCooldown') ?? 1;

    service.on('set_proximity_key').listen((event) async {
      if (event == null) return;
      bool enabled = event['enabled'];
      _proximityKeyEnabled = enabled;

      String message = enabled ? 'PROX_KEY_ON' : 'PROX_KEY_OFF';
      for (final vehicle in vehicles) {
        if (!vehicle.device.isConnected) continue;
        await BleService.sendMessage(vehicle.device, message);
        if (enabled) {
          await Future.delayed(Duration(milliseconds: 200));
          await BleService.sendMessage(vehicle.device,
              'RSSI_TRIG:${_proximityStrength.toStringAsFixed(2)},${_deadZone.toInt()}');
          await Future.delayed(Duration(milliseconds: 200));
          await BleService.sendMessage(vehicle.device,
              'PROX_COOLD:${_proximityCooldown.toStringAsFixed(2)}');
        }
      }
    });

    service.on('set_proximity_cooldown').listen((event) async {
      if (event == null) return;
      double cooldown = event['cooldown'].toDouble();
      _proximityCooldown = cooldown;
      for (final vehicle in vehicles) {
        if (!vehicle.device.isConnected) continue;
        await BleService.sendMessage(
            vehicle.device, 'PROX_COOLD:${cooldown.toStringAsFixed(2)}');
      }
    });

    service.on('set_vibrate').listen((event) {
      if (event == null) return;
      bool enabled = event['enabled'];
      _vibrate = enabled;
    });

    service.on('send_data').listen((event) async {
      for (final vehicle in vehicles) {
        if (!vehicle.device.isConnected) continue;
        await BleService.sendMessage(vehicle.device, 'SEND_DATA');
      }
    });

    service.on('set_dead_zone').listen((event) async {
      if (event == null) return;
      double deadZone = event['deadZone'].toDouble();
      _deadZone = deadZone;
      for (final vehicle in vehicles) {
        if (!vehicle.device.isConnected) continue;
        await BleService.sendMessage(vehicle.device,
            'RSSI_TRIG:${_proximityStrength.toStringAsFixed(2)},${deadZone.toInt()}');
      }
    });

    service.on('set_proximity_strength').listen((event) async {
      if (event == null) return;
      double strength = event['strength'].toDouble();
      _proximityStrength = strength;
      for (final vehicle in vehicles) {
        if (!vehicle.device.isConnected) continue;
        await BleService.sendMessage(vehicle.device,
            'RSSI_TRIG:${strength.toStringAsFixed(2)},${_deadZone.toInt()}');
      }
    });

    service.on('reload_vehicles').listen((event) async {
      await VehicleStorage.reloadPrefs();
      _getVehicles();
    });

    service.on('try_connect_all').listen((event) async {
      for (final vehicle in vehicles) {
        await BleService.connectToDevice(vehicle.device);
      }
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

      BackgroundVehicle? changedVehicle =
          _getChangedVehicle(event.device.remoteId.str);

      if (vehicles.isEmpty || changedVehicle == null) {
        await VehicleStorage.reloadPrefs();
        await _getVehicles();
        changedVehicle = _getChangedVehicle(event.device.remoteId.str);
      }

      if (vehicles.isEmpty || changedVehicle == null) return;

      changedVehicle.device = event.device;

      if (event.connectionState == BluetoothConnectionState.connected) {
        // Give the connection a moment to stabilize
        await Future.delayed(Duration(milliseconds: 500));

        //Sub to notifications from the device
        final services = await event.device.discoverServices();
        final service = services.firstWhere((service) =>
            service.uuid == Guid('0000ffe0-0000-1000-8000-00805f9b34fb'));
        final characteristic = service.characteristics.firstWhere(
            (characteristic) =>
                characteristic.uuid ==
                Guid('0000ffe1-0000-1000-8000-00805f9b34fb'));

        await characteristic.setNotifyValue(true);
        StreamSubscription? notificationSubscription =
            characteristic.onValueReceived.listen((value) {
          _onMessageReceived.value =
              MessageData(event.device.remoteId.str, utf8.decode(value));
        });

        _subscriptions
            .add(notificationSubscription); //TODO: remove if no longer needed

        if (_proximityKeyEnabled) {
          _updateNotification(
              flutterLocalNotificationsPlugin,
              'Connected to ${changedVehicle.data.name}',
              '${changedVehicle.data.name} connected. Go closer to unlock!');
        } else {
          _updateNotification(
              flutterLocalNotificationsPlugin,
              'Connected to ${changedVehicle.data.name}',
              '${changedVehicle.data.name} connected.');
        }
        await BleService.sendMessage(
            changedVehicle.device, 'AUTH:${changedVehicle.data.pin}');
        await Future.delayed(Duration(milliseconds: 200));
        await BleService.sendMessage(changedVehicle.device, 'SEND_DATA');

        if (_proximityKeyEnabled) {
          await Future.delayed(Duration(milliseconds: 200));
          await BleService.sendMessage(changedVehicle.device,
              'RSSI_TRIG:${_proximityStrength.toStringAsFixed(2)},${_deadZone.toInt()}'); //
          await Future.delayed(Duration(milliseconds: 200));
          await BleService.sendMessage(changedVehicle.device,
              'PROX_COOLD:${_proximityCooldown.toStringAsFixed(2)}');
          await Future.delayed(Duration(milliseconds: 200));
          await BleService.sendMessage(changedVehicle.device, 'PROX_KEY_ON');
        }

        await BleDeviceStorage.addDevice(changedVehicle.device.remoteId.str);
      } else if (event.connectionState ==
          BluetoothConnectionState.disconnected) {
        if (_proximityKeyEnabled) {
          _updateNotification(
              flutterLocalNotificationsPlugin,
              'Disconnected from ${changedVehicle.data.name} (Proxy Locked)',
              '${changedVehicle.data.name} disconnected and was locked. Waiting for connection...');
        } else {
          _updateNotification(
              flutterLocalNotificationsPlugin,
              'Disconnected from ${changedVehicle.data.name}',
              '${changedVehicle.data.name} is disconnected. Waiting for connection...');
        }

        //The device was disconnected without having time to say it locked, so let the user know it was locked here
        if (_proximityKeyEnabled &&
            _vibrate &&
            !_proxyLocked.contains(event.device.remoteId.str)) {
          _vibrateLongTwice();
        }

        await BleDeviceStorage.removeDevice(changedVehicle.device.remoteId.str);
      }

      service.invoke(
        'connection_state_changed',
        {
          'macAddress': event.device.remoteId.str,
          'connectionState': event.connectionState.toString(),
        },
      );
    });

    _onMessageReceived.addListener(() {
      final messageData = _onMessageReceived.value;
      print('Message received: ${messageData.message}');

      if (messageData.message.startsWith('LOCKED_PROX')) {
        BackgroundVehicle? changedVehicle =
            _getChangedVehicle(messageData.macAddress);

        _proxyLocked.add(messageData.macAddress);
        if (_vibrate) {
          _vibrateLongTwice();
        }

        _updateNotification(
            flutterLocalNotificationsPlugin,
            'Connected to ${changedVehicle?.data.name ?? '<Failed to load name>'} (Proxy Locked)',
            '${changedVehicle?.data.name ?? '<Failed to load name>'} connected and locked since it is too far away.');
      } else if (messageData.message.startsWith('UNLOCKED_PROX')) {
        BackgroundVehicle? changedVehicle =
            _getChangedVehicle(messageData.macAddress);

        _proxyLocked.remove(messageData.macAddress);
        if (_vibrate) {
          _vibrateLongTwice();
        }

        _updateNotification(
            flutterLocalNotificationsPlugin,
            'Connected to ${changedVehicle?.data.name ?? '<Failed to load name>'} (Proxy Unlocked)',
            '${changedVehicle?.data.name ?? '<Failed to load name>'} connected and was unlocked.');
      }

      service.invoke(
        'message_received',
        {
          'macAddress': messageData.macAddress,
          'message': messageData.message,
        },
      );
    });

    _getVehicles();
  }

  // iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    return true;
  }

  static BackgroundVehicle? _getChangedVehicle(String macAddress) {
    BackgroundVehicle? changedVehicle;
    try {
      changedVehicle = vehicles.firstWhere((backgroundVehicle) =>
          backgroundVehicle.device.remoteId.str == macAddress);
    } catch (e) {
      changedVehicle = null;
    }
    return changedVehicle;
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

  static void _vibrateLongTwice() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 600, 200, 600]);
    }
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

  static void requestData() {
    _service.invoke('send_data', {});
  }

  static void setProximityCooldown(double cooldown) {
    _service.invoke('set_proximity_cooldown', {'cooldown': cooldown});
  }

  static void setVibrate(bool enabled) {
    _service.invoke('set_vibrate', {'enabled': enabled});
  }

  static void setDeadZone(double deadZone) {
    _service.invoke('set_dead_zone', {'deadZone': deadZone});
  }

  static void setProximityKey(bool enabled) {
    _service.invoke('set_proximity_key', {'enabled': enabled});
  }

  static void setProximityStrength(double strength) {
    _service.invoke('set_proximity_strength', {'strength': strength});
  }

  static void reloadVehicles() {
    _service.invoke('reload_vehicles', {});
  }

  static void tryConnectAll() {
    _service.invoke('try_connect_all', {});
  }

  static void disconnectDevice(BleDevice device) {
    _service.invoke('disconnect_device', {'macAddress': device.macAddress});
  }

  static void sendMessage(BleDevice device, String message) {
    _service.invoke(
        'send_message', {'macAddress': device.macAddress, 'message': message});
  }
}
