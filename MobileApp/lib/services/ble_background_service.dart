import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../types/ble_commands.dart';
import '../types/ble_device.dart';
import '../types/vehicle.dart';
import 'ble_service.dart';
import '../utils/esp32_response_parser.dart';
import 'vehicle_service.dart';
import 'widget_service.dart';

@pragma('vm:entry-point')
class BleBackgroundService {
  // ignore: constant_identifier_names
  static const PROTOCOL_VERSION = 'V3';

  static List<BackgroundVehicle> vehicles = [];
  static final ValueNotifier<Esp32ResponseDate?> _onMessageReceived =
      ValueNotifier<Esp32ResponseDate?>(null);
  static final List<StreamSubscription?> _subscriptions = [];
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static late SharedPreferences _prefs;
  static bool _proximityKeyEnabled = false;
  static double _proximityStrength = 100;
  static bool _vibrate = true;
  static double _deadZone = 4;
  static double _proximityCooldown = 1;
  static final List<int> _sentMismatchNotifications = [];

  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Initialize the background service
  ///
  /// This should be in your main.dart before runApp
  static Future<void> initializeService(
      {required bool backgroundServiceEnabled}) async {
    await Permission.notification.request();

    final isolate = Isolate.current;
    debugPrint(
        'Starting BG service from isolate: ${isolate.debugName ?? 'unnamed'} - ${isolate.hashCode}');

    final service = FlutterBackgroundService();

    // Configure local notifications
    // For Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'background_service', // id
      'Background Service', // title
      description: 'Background service for proximity key',
      importance: Importance.low,
      showBadge: false,
    );

    await _flutterLocalNotificationsPlugin
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
        autoStartOnBoot: backgroundServiceEnabled,
        isForegroundMode: true,
        notificationChannelId: 'background_service',
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
        onBackground: backgroundServiceEnabled ? onIosBackground : null,
      ),
    );
  }

// This is the background isolate function
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

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

    debugPrint('Background service started...');

    final isolate = Isolate.current;
    debugPrint(
        'BG started in isolate: ${isolate.debugName ?? 'unnamed'} - ${isolate.hashCode}');

    _updateNotification(
        'Waiting for connection...', 'Go near a vehicle to connect.');

    await BleDeviceStorage.clearBleDevices();

    _prefs = await SharedPreferences.getInstance();
    _proximityKeyEnabled = _prefs.getBool('proximityKey') ?? false;
    _proximityStrength = _prefs.getDouble('triggerStrength') ?? -200;
    _deadZone = _prefs.getDouble('deadZone') ?? 4;
    _vibrate = _prefs.getBool('vibrate') ?? true;
    _proximityCooldown = _prefs.getDouble('proximityCooldown') ?? 1;
    final backgroundService = _prefs.getBool('backgroundService') ?? true;

    WidgetService.initialize(backgroundServiceEnabled: backgroundService);

    _handleServiceEvents(service);

    FlutterBluePlus.events.onConnectionStateChanged.listen((event) async {
      debugPrint('Connection state changed: ${event.connectionState}');

      BackgroundVehicle? changedVehicle =
          _getChangedVehicle(event.device.remoteId.str);

      if (vehicles.isEmpty || changedVehicle == null) {
        await VehicleStorage.reloadPrefs();
        await _getVehicles();
        changedVehicle = _getChangedVehicle(event.device.remoteId.str);
      }

      if (vehicles.isEmpty || changedVehicle == null) {
        debugPrint('No vehicle found, not updating connection state');
        return;
      }

      changedVehicle.device = event.device;

      final bool ignoreProximityKey = changedVehicle.data.noProximityKey;

      if (event.connectionState == BluetoothConnectionState.connected) {
        await _handleConnected(event, changedVehicle, ignoreProximityKey);
      } else if (event.connectionState ==
          BluetoothConnectionState.disconnected) {
        await _handleDisconnected(event, changedVehicle, ignoreProximityKey);
      }

      service.invoke(
        'connection_state_changed',
        {
          'macAddress': event.device.remoteId.str,
          'connectionState': event.connectionState.toString(),
        },
      );

      WidgetService.reloadConnectedDevices();
    });

    _onMessageReceived.addListener(() async {
      final espResponseData = _onMessageReceived.value;
      if (espResponseData == null) return;

      debugPrint('Message received: ${espResponseData.command}');

      _handleMessage(espResponseData);

      service.invoke(
        'command_received',
        {
          'macAddress': espResponseData.macAddress,
          'data': espResponseData.parser.value,
        },
      );

      WidgetService.processMessage(
          espResponseData.macAddress, espResponseData.command);
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

  static void _updateNotification(String title, String message) {
    _flutterLocalNotificationsPlugin.show(
      888,
      title,
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'background_service',
          'Background service for BLE auto connect',
          icon: 'ic_launcher_foreground',
          ongoing: true,
        ),
      ),
    );
  }

  static void _vibrateLongTwice() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 600, 200, 600]);
    }
  }

  static Future<void> _handleConnected(OnConnectionStateChangedEvent event,
      BackgroundVehicle vehicle, bool ignoreProximityKey) async {
    // Give the connection a moment to stabilize
    await Future.delayed(Duration(milliseconds: 500));

    //Sub to notifications from the device
    await event.device.requestMtu(64);
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
      if (value.isEmpty) {
        debugPrint('Received empty value from characteristic.');
        return;
      }

      final parser = Esp32ResponseParser(value);
      final Esp32Response? command = Esp32Response.fromValue(parser.command);

      if (command == null) {
        debugPrint('Unknown command byte: ${parser.command}');
        return;
      }

      _onMessageReceived.value = Esp32ResponseDate(
          macAddress: event.device.remoteId
              .str, // Assuming 'event' is available in this scope
          command: command,
          parser: parser);
    });

    _subscriptions
        .add(notificationSubscription); //TODO: remove if no longer needed

    await BleService.sendCommand(vehicle.device, ClientCommand.GET_VERSION);
    await Future.delayed(Duration(milliseconds: 200));

    if (_proximityKeyEnabled && !ignoreProximityKey) {
      _updateNotification('Connected to ${vehicle.data.name}',
          '${vehicle.data.name} connected. Go closer to unlock!');
    } else {
      _updateNotification('Connected to ${vehicle.data.name}',
          '${vehicle.data.name} connected.');
    }

    await BleService.sendCommand(vehicle.device, ClientCommand.GET_DATA);

    if (_proximityKeyEnabled && !ignoreProximityKey) {
      await Future.delayed(Duration(milliseconds: 200));

      await BleService.sendCommandWithFloats(vehicle.device,
          ClientCommand.RSSI_TRIGGER, [_proximityStrength, _deadZone]);

      await Future.delayed(Duration(milliseconds: 200));

      await BleService.sendCommandWithFloat(
          vehicle.device, ClientCommand.PROXIMITY_COOLDOWN, _proximityCooldown);
      await Future.delayed(Duration(milliseconds: 200));

      await BleService.sendCommand(
          vehicle.device, ClientCommand.PROXIMITY_KEY_ON);
    }

    await BleDeviceStorage.addDevice(vehicle.device.remoteId.str);
  }

  static Future<void> _handleDisconnected(OnConnectionStateChangedEvent event,
      BackgroundVehicle vehicle, bool ignoreProximityKey) async {
    if (_proximityKeyEnabled && !ignoreProximityKey) {
      _updateNotification(
          'Disconnected from ${vehicle.data.name} (Proxy Locked)',
          '${vehicle.data.name} disconnected and was locked. Waiting for connection...');
    } else {
      _updateNotification('Disconnected from ${vehicle.data.name}',
          '${vehicle.data.name} is disconnected. Waiting for connection...');
    }

    // The device was disconnected without having time to say it locked, so let the user know it was locked here
    if (_proximityKeyEnabled &&
        _vibrate &&
        !ignoreProximityKey &&
        !vehicle.doorsLocked) {
      _vibrateLongTwice();
    }

    await BleDeviceStorage.removeDevice(vehicle.device.remoteId.str);
  }

  static Future<void> _handleMessage(Esp32ResponseDate espResponseData) async {
    if (espResponseData.command == Esp32Response.VERSION) {
      await _prefs.reload();
      final ignoreProtocolMismatch =
          _prefs.getBool('ignoreProtocolMismatch') ?? false;
      final deviceProtocolVersion = espResponseData.parser.getString();

      debugPrint(
          'Device protocol version: $deviceProtocolVersion, ignoreProtocolMismatch: $ignoreProtocolMismatch');

      if (deviceProtocolVersion != PROTOCOL_VERSION &&
          !ignoreProtocolMismatch) {
        BackgroundVehicle? changedVehicle =
            _getChangedVehicle(espResponseData.macAddress);

        if (changedVehicle != null) {
          int notificationId =
              changedVehicle.data.macAddress.hashCode & 0x7FFFFFFF;

          if (!_sentMismatchNotifications.contains(notificationId)) {
            _sentMismatchNotifications.add(notificationId);

            _flutterLocalNotificationsPlugin.show(
              notificationId,
              'Protocol version mismatch',
              '${changedVehicle.data.name} is on protocol version $deviceProtocolVersion and the app is on $PROTOCOL_VERSION. Some features might not work.',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'protocol_mismatch',
                  'Protocol version mismatch',
                  icon: 'ic_launcher_foreground',
                ),
              ),
            );
          }
        }
      }
    }

    if (espResponseData.command == Esp32Response.PROXIMITY_LOCKED) {
      BackgroundVehicle? changedVehicle =
          _getChangedVehicle(espResponseData.macAddress);

      if (_vibrate) {
        _vibrateLongTwice();
      }

      _updateNotification(
          'Connected to ${changedVehicle?.data.name ?? '<Failed to load name>'} (Proxy Locked)',
          '${changedVehicle?.data.name ?? '<Failed to load name>'} connected and locked since it is too far away.');
    } else if (espResponseData.command == Esp32Response.PROXIMITY_UNLOCKED) {
      BackgroundVehicle? changedVehicle =
          _getChangedVehicle(espResponseData.macAddress);

      if (_vibrate) {
        _vibrateLongTwice();
      }

      _updateNotification(
          'Connected to ${changedVehicle?.data.name ?? '<Failed to load name>'} (Proxy Unlocked)',
          '${changedVehicle?.data.name ?? '<Failed to load name>'} connected and was unlocked.');
    }
  }

  //---------- Code for handling function calls from the frontend ----------
  static void _handleServiceEvents(ServiceInstance service) {
    service.on('handle_app_detached').listen((event) async {
      bool backgroundService = _prefs.getBool('backgroundService') ?? true;
      if (!backgroundService) {
        service.stopSelf();
        debugPrint('Background service stopped...');
      }
    });

    service.on('reload_homescreen_widget').listen((event) async {
      WidgetService.reloadVehicles();
    });

    service.on('change_homescreen_widget_vehicle').listen((event) async {
      WidgetService.changeVehicle();
    });

    service.on('set_proximity_key').listen((event) async {
      if (event == null) return;
      bool enabled = event['enabled'];
      _proximityKeyEnabled = enabled;

      ClientCommand command = enabled
          ? ClientCommand.PROXIMITY_KEY_ON
          : ClientCommand.PROXIMITY_KEY_OFF;
      for (final vehicle in vehicles) {
        if (!vehicle.device.isConnected) continue;
        await BleService.sendCommand(vehicle.device, command);
        if (enabled) {
          await Future.delayed(Duration(milliseconds: 200));
          await BleService.sendCommandWithFloats(vehicle.device,
              ClientCommand.RSSI_TRIGGER, [_proximityStrength, _deadZone]);
          await Future.delayed(Duration(milliseconds: 200));
          await BleService.sendCommandWithFloat(vehicle.device,
              ClientCommand.PROXIMITY_COOLDOWN, _proximityCooldown);
        }
      }
    });

    service.on('set_proximity_cooldown').listen((event) async {
      if (event == null) return;
      double cooldown = event['cooldown'].toDouble();
      _proximityCooldown = cooldown;
      for (final vehicle in vehicles) {
        if (!vehicle.device.isConnected) continue;
        await BleService.sendCommandWithFloat(
            vehicle.device, ClientCommand.PROXIMITY_COOLDOWN, cooldown);
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
        await BleService.sendCommand(vehicle.device, ClientCommand.GET_DATA);
        await Future.delayed(Duration(milliseconds: 200));
        await BleService.sendCommand(vehicle.device, ClientCommand.GET_VERSION);
      }
    });

    service.on('set_dead_zone').listen((event) async {
      if (event == null) return;
      double deadZone = event['deadZone'].toDouble();
      _deadZone = deadZone;
      for (final vehicle in vehicles) {
        if (!vehicle.device.isConnected) continue;
        await BleService.sendCommandWithFloats(vehicle.device,
            ClientCommand.RSSI_TRIGGER, [_proximityStrength, deadZone]);
      }
    });

    service.on('set_proximity_strength').listen((event) async {
      if (event == null) return;
      double strength = event['strength'].toDouble();
      _proximityStrength = strength;
      for (final vehicle in vehicles) {
        if (!vehicle.device.isConnected) continue;
        await BleService.sendCommandWithFloats(vehicle.device,
            ClientCommand.RSSI_TRIGGER, [_proximityStrength, _deadZone]);
      }
    });

    service.on('reload_vehicles').listen((event) async {
      await VehicleStorage.reloadPrefs();
      BleService.reloadPrefs();
      _getVehicles();
    });

    service.on('try_connect_all').listen((event) async {
      for (final vehicle in vehicles) {
        await BleService.connectToDevice(vehicle.device);
      }
    });

    service.on('send_command').listen((event) {
      if (event == null) return;
      BluetoothDevice device = BluetoothDevice.fromId(event['macAddress']);
      ClientCommand? command = ClientCommand.fromValue(event['command']);
      Uint8List? additionalData = event['additionalData'];

      if (command == null) return;

      BleService.sendCommand(device, command, additionalData: additionalData);
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
  }

  //Functions to call from app/foreground
  static void reloadHomescreenWidget() {
    _service.invoke('reload_homescreen_widget');
  }

  static void changeHomescreenWidgetVehicle() {
    _service.invoke('change_homescreen_widget_vehicle');
  }

  static void handleAppDetached() {
    _service.invoke('handle_app_detached');
  }

  static Future<void> disableBackgroundService() async {
    if (await _service.isRunning()) {
      _service.invoke('stopService');
    }

    await Future.delayed(Duration(seconds: 5));

    initializeService(backgroundServiceEnabled: false);
  }

  static Future<void> enableBackgroundService() async {
    if (await _service.isRunning()) {
      _service.invoke('stopService');
    }

    await Future.delayed(Duration(seconds: 5));

    initializeService(backgroundServiceEnabled: true);
  }

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

  /// Send a command to a device.
  static void sendCommand(BleDevice device, ClientCommand command,
      {Uint8List? additionalData}) {
    _service.invoke('send_command', {
      'macAddress': device.macAddress,
      'command': command.value,
      'additionalData': additionalData
    });
  }
}
