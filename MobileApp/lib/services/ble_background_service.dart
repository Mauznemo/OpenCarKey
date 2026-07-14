import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'package:collection/collection.dart';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../types/background_vehicle.dart';
import '../types/ble_commands.dart';
import '../models/ble_device.dart';
import '../types/features.dart';
import 'activity_service.dart';
import 'ble_device_storage_service.dart';
import 'ble_service.dart';
import '../utils/esp32_response_parser.dart';
import 'vehicle_service.dart';
import 'widget_service.dart';

/// Entry point for the foreground task isolate. Must be a top-level function
/// annotated with `@pragma('vm:entry-point')` so it survives tree-shaking and
/// can be looked up by the native side when the service (re)starts.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BleTaskHandler());
}

/// Bridges the `flutter_foreground_task` lifecycle to the static
/// [BleBackgroundService] logic that owns all BLE traffic in this isolate.
class BleTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await BleBackgroundService.onStart();
  }

  // eventAction is ForegroundTaskEventAction.nothing(), so this never fires.
  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      BleBackgroundService.handleTaskData(Map<String, dynamic>.from(data));
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await BleBackgroundService._teardownListeners();
  }
}

@pragma('vm:entry-point')
class BleBackgroundService {
  // ignore: constant_identifier_names
  static const PROTOCOL_VERSION = 'V3';

  static List<BackgroundVehicle> vehicles = [];
  static final ValueNotifier<Esp32ResponseDate?> _onMessageReceived =
      ValueNotifier<Esp32ResponseDate?>(null);
  static final Map<String, StreamSubscription> _subscriptions = {};

  // Top-level listeners registered in [onStart]. Tracked so repeated onStart
  // invocations (service restarts) tear down the previous registration instead
  // of stacking duplicate listeners on top.
  static StreamSubscription<OnConnectionStateChangedEvent>? _connectionStateSub;
  static VoidCallback? _messageListener;
  // MACs that have reached a real connected state, so we only log disconnects
  // for devices that were actually connected (not autoConnect phantoms).
  static final Set<String> _connectedMacs = {};
  // MACs we disconnected on purpose to recover a dead notification pipe on the
  // first connect (see _handleConnected). Reconnected from _handleDisconnected.
  static final Set<String> _autoReconnectPending = {};
  // MACs we've already force-reconnected once this connect session, so a device
  // whose notifications never work can't get stuck in a disconnect/reconnect
  // loop. Cleared as soon as a notification actually arrives.
  static final Set<String> _autoReconnectAttempted = {};
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
  static Future<void> initializeService({
    required bool backgroundServiceEnabled,
  }) async {
    final isolate = Isolate.current;
    debugPrint(
      'Starting BG service from isolate: ${isolate.debugName ?? 'unnamed'} - ${isolate.hashCode}',
    );

    // Configure the foreground task. The notification channel is created by the
    // plugin from these options (reusing the existing 'background_service' id).
    // allowWakeLock: false is the whole point of this migration — it lets the
    // CPU deep-sleep while the service is idle instead of holding a permanent
    // partial wakelock like flutter_background_service did.
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'background_service',
        channelName: 'Background Service',
        channelDescription: 'Background service for proximity key',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        showBadge: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: backgroundServiceEnabled,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: false,
        allowWifiLock: false,
      ),
    );

    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        serviceId: 888,
        notificationTitle: 'Initializing',
        notificationText: 'Initializing BLE Service...',
        callback: startCallback,
      );
    } else {
      debugPrint('Service is already running, not starting again!');
    }
  }

  // This runs in the background isolate (from [BleTaskHandler.onStart]).
  @pragma('vm:entry-point')
  static Future<void> onStart() async {
    DartPluginRegistrant.ensureInitialized();

    debugPrint('Background service started...');

    final isolate = Isolate.current;
    debugPrint(
      'BG started in isolate: ${isolate.debugName ?? 'unnamed'} - ${isolate.hashCode}',
    );

    _updateNotification(
      'Waiting for connection...',
      'Go near a vehicle to connect.',
    );

    await BleDeviceStorageService.clearBleDevices();
    // Keep the in-memory dedup set consistent with the just-cleared storage.
    // Otherwise it can drift across a service restart, making _handleConnected
    // wrongly early-return and skip BLE setup for a freshly reconnected device.
    _connectedMacs.clear();
    _autoReconnectPending.clear();
    _autoReconnectAttempted.clear();

    _prefs = await SharedPreferences.getInstance();
    _proximityKeyEnabled = _prefs.getBool('proximityKey') ?? false;
    _proximityStrength = _prefs.getDouble('triggerStrength') ?? -200;
    _deadZone = _prefs.getDouble('deadZone') ?? 4;
    _vibrate = _prefs.getBool('vibrate') ?? true;
    _proximityCooldown = _prefs.getDouble('proximityCooldown') ?? 1;
    final backgroundService = _prefs.getBool('backgroundService') ?? true;

    WidgetService.initialize(backgroundServiceEnabled: backgroundService);

    // onStart can run again within the same isolate on a service restart. Tear
    // down the previous registration first so listeners don't stack up and fire
    // an event once per past invocation.
    await _teardownListeners();

    _connectionStateSub = FlutterBluePlus.events.onConnectionStateChanged
        .listen(_handleConnectionStateChanged);

    _messageListener = _handleMessageNotifier;
    _onMessageReceived.addListener(_messageListener!);

    _getVehicles();
  }

  /// Cancels every top-level listener registered by [onStart] so it can be
  /// safely re-registered without duplicating.
  static Future<void> _teardownListeners() async {
    await _connectionStateSub?.cancel();
    _connectionStateSub = null;

    if (_messageListener != null) {
      _onMessageReceived.removeListener(_messageListener!);
      _messageListener = null;
    }
  }

  // Per-device queue so connect/disconnect events for the same device are
  // processed strictly in order and never interleave at await points. Without
  // this, the stream fires the async handler without awaiting it, so a slow
  // connect (service discovery + command round-trips) could still be running
  // its final storage write when a disconnect is handled, re-marking the device
  // connected after it was removed and leaving it stuck.
  static final Map<String, Future<void>> _connStateQueues = {};

  static void _handleConnectionStateChanged(
    OnConnectionStateChangedEvent event,
  ) {
    final mac = event.device.remoteId.str;
    final prev = _connStateQueues[mac] ?? Future.value();
    _connStateQueues[mac] = prev
        .then((_) => _processConnectionStateChanged(event))
        .catchError(
          (Object e) =>
              debugPrint('Error processing connection state for $mac: $e'),
        );
  }

  static Future<void> _processConnectionStateChanged(
    OnConnectionStateChangedEvent event,
  ) async {
    debugPrint('Connection state changed: ${event.connectionState}');

    BackgroundVehicle? changedVehicle = _getChangedVehicle(
      event.device.remoteId.str,
    );

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

    // The handlers own their side effects (notification, characteristic
    // subscription, activity log, vibration). Any throw is contained so the
    // authoritative storage reconcile + invoke + widget reload below always run.
    try {
      if (event.connectionState == BluetoothConnectionState.connected) {
        await _handleConnected(event, changedVehicle, ignoreProximityKey);
      } else if (event.connectionState ==
          BluetoothConnectionState.disconnected) {
        await _handleDisconnected(event, changedVehicle, ignoreProximityKey);
      }
    } catch (e) {
      debugPrint('Error handling connection state change: $e');
    }

    // Reconcile the persisted connected_devices list (the single source of truth
    // for the app UI and home-screen widget) from the *real* current connection
    // state, so it can never be left stuck after a race or a handler failure.
    final mac = event.device.remoteId.str;
    final bool isConnected = event.device.isConnected;
    if (isConnected) {
      await BleDeviceStorageService.addDevice(mac);
    } else {
      await BleDeviceStorageService.removeDevice(mac);
      _connectedMacs.remove(mac);
    }

    FlutterForegroundTask.sendDataToMain({
      'event': 'connection_state_changed',
      'macAddress': mac,
      'connectionState':
          (isConnected
                  ? BluetoothConnectionState.connected
                  : BluetoothConnectionState.disconnected)
              .toString(),
    });

    WidgetService.reloadConnectedDevices();
  }

  static Future<void> _handleMessageNotifier() async {
    final espResponseData = _onMessageReceived.value;
    if (espResponseData == null) return;

    debugPrint('Message received: ${espResponseData.command}');

    _handleMessage(espResponseData);

    FlutterForegroundTask.sendDataToMain({
      'event': 'command_received',
      'macAddress': espResponseData.macAddress,
      'data': espResponseData.parser.value,
    });

    WidgetService.processMessage(
      espResponseData.macAddress,
      espResponseData.command,
    );
  }

  static BackgroundVehicle? _getChangedVehicle(String macAddress) {
    BackgroundVehicle? changedVehicle;
    try {
      changedVehicle = vehicles.firstWhere(
        (backgroundVehicle) =>
            backgroundVehicle.device.remoteId.str == macAddress,
      );
    } catch (e) {
      changedVehicle = null;
    }
    return changedVehicle;
  }

  static Future<void> _getVehicles() async {
    final vehiclesData = await VehicleStorage.getVehicles();

    vehicles = vehiclesData
        .map(
          (vehicle) => BackgroundVehicle(
            device: BluetoothDevice.fromId(vehicle.macAddress),
            data: vehicle,
          ),
        )
        .toList();

    _connectDevices();
  }

  static void _connectDevices() async {
    for (final vehicle in vehicles) {
      await BleService.connectToDevice(vehicle.device);
    }
  }

  static void _updateNotification(String title, String message) {
    // The plugin owns the foreground-service notification (id 888). Fire and
    // forget — updateService is a no-op if the service isn't running yet.
    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: message,
    );
  }

  static void _vibrateLongTwice() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 600, 200, 600]);
    }
  }

  static Future<void> _handleConnected(
    OnConnectionStateChangedEvent event,
    BackgroundVehicle vehicle,
    bool ignoreProximityKey,
  ) async {
    // flutter_blue_plus can emit repeated `connected` events for the same
    // device (autoConnect re-arming, repeated connect() calls from
    // _connectDevices/try_connect_all). Handle a connection only once: this
    // both prevents duplicate "connected" log entries and stops the
    // characteristic subscription below from leaking on top of a previous one.
    // The MAC is removed again in _handleDisconnected, so a genuine reconnect
    // is handled normally.
    if (!_connectedMacs.add(event.device.remoteId.str)) {
      debugPrint(
        'Already connected to ${event.device.remoteId.str}, ignoring duplicate connected event',
      );
      return;
    }

    // Give the connection a moment to stabilize
    await Future.delayed(Duration(milliseconds: 500));

    //Sub to notifications from the device
    await event.device.requestMtu(64);
    final services = await event.device.discoverServices();
    final service = services.firstWhere(
      (service) => service.uuid == Guid('0000ffe0-0000-1000-8000-00805f9b34fb'),
    );
    final characteristic = service.characteristics.firstWhere(
      (characteristic) =>
          characteristic.uuid == Guid('0000ffe1-0000-1000-8000-00805f9b34fb'),
    );

    // Set true as soon as *any* notification is delivered on this connection.
    // Proves the GATT notification pipe actually works; used below to detect the
    // first-connect case where setNotifyValue silently fails to deliver.
    bool gotResponse = false;

    await characteristic.setNotifyValue(true);
    final notificationSubscription = characteristic.onValueReceived.listen((
      value,
    ) {
      // A packet arrived → notifications are flowing. Clear the one-shot
      // auto-reconnect guard so a later genuine first-connect can self-heal too.
      gotResponse = true;
      _autoReconnectAttempted.remove(event.device.remoteId.str);

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
        macAddress: event
            .device
            .remoteId
            .str, // Assuming 'event' is available in this scope
        command: command,
        parser: parser,
      );
    });

    _subscriptions[event.device.remoteId.str] = notificationSubscription;

    await BleService.sendCommand(vehicle.device, ClientCommand.GET_VERSION);
    await Future.delayed(Duration(milliseconds: 200));

    if (_proximityKeyEnabled && !ignoreProximityKey) {
      _updateNotification(
        'Connected to ${vehicle.data.name}',
        '${vehicle.data.name} connected. Go closer to unlock!',
      );
    } else {
      _updateNotification(
        'Connected to ${vehicle.data.name}',
        '${vehicle.data.name} connected.',
      );
    }

    await BleService.sendCommand(vehicle.device, ClientCommand.GET_FEATURES);
    await Future.delayed(Duration(milliseconds: 200));

    await BleService.sendCommand(vehicle.device, ClientCommand.GET_DATA);

    if (_proximityKeyEnabled && !ignoreProximityKey) {
      await Future.delayed(Duration(milliseconds: 200));

      await BleService.sendCommandWithFloats(
        vehicle.device,
        ClientCommand.RSSI_TRIGGER,
        [_proximityStrength, _deadZone],
      );

      await Future.delayed(Duration(milliseconds: 200));

      await BleService.sendCommandWithFloat(
        vehicle.device,
        ClientCommand.PROXIMITY_COOLDOWN,
        _proximityCooldown,
      );
      await Future.delayed(Duration(milliseconds: 200));

      await BleService.sendCommand(
        vehicle.device,
        ClientCommand.PROXIMITY_KEY_ON,
      );
    }

    ActivityService.instance.logConnectedToVehicle(vehicle.data);

    // On the very first connection the GATT notification subscription sometimes
    // silently fails to deliver (Android GATT cache / autoConnect timing), so
    // the GET_DATA response (and every later LOCKED/UNLOCKED) never arrives and
    // the UI/widget stay stuck on the default lock state until a manual
    // reconnect. Detect that here and self-heal: re-assert notifications and
    // re-request the state a few times, then force one reconnect as a last
    // resort — the same thing the user does by hand, which fixes it for good.
    // Fire-and-forget: must not delay the connection_state_changed / widget
    // reconcile that runs once this handler returns. The onValueReceived
    // closure keeps [gotResponse] live, so the detached check still sees updates.
    unawaited(_ensureNotificationsWorking(event, vehicle, () => gotResponse));
  }

  /// Verifies that BLE notifications are actually being delivered for a
  /// freshly-connected [vehicle]; retries and, as a last resort, forces a single
  /// disconnect+reconnect. [gotResponse] reports whether any packet has arrived.
  static Future<void> _ensureNotificationsWorking(
    OnConnectionStateChangedEvent event,
    BackgroundVehicle vehicle,
    bool Function() gotResponse,
  ) async {
    final mac = event.device.remoteId.str;
    const int maxRetries = 3;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (gotResponse()) return;
      if (event.device.isDisconnected) return; // nothing to recover anymore

      debugPrint(
        'No notification from $mac after connect (attempt ${attempt + 1}/'
        '$maxRetries) — re-asserting notifications and re-requesting GET_DATA',
      );

      final subscription = _subscriptions[mac];
      // Re-assert the CCCD subscription; the characteristic handle is reused via
      // the existing onValueReceived listener stored in _subscriptions.
      try {
        final services = await event.device.discoverServices();
        final service = services.firstWhereOrNull(
          (s) => s.uuid == Guid('0000ffe0-0000-1000-8000-00805f9b34fb'),
        );
        final characteristic = service?.characteristics.firstWhereOrNull(
          (c) => c.uuid == Guid('0000ffe1-0000-1000-8000-00805f9b34fb'),
        );
        if (subscription != null && characteristic != null) {
          await characteristic.setNotifyValue(true);
        }
      } catch (e) {
        debugPrint('Error re-asserting notifications for $mac: $e');
      }

      await BleService.sendCommand(vehicle.device, ClientCommand.GET_DATA);
    }

    // Give the last GET_DATA a moment before deciding to reconnect.
    await Future.delayed(const Duration(milliseconds: 2500));
    if (gotResponse() || event.device.isDisconnected) return;

    if (_autoReconnectAttempted.add(mac)) {
      debugPrint(
        'Notifications still dead for $mac after retries — forcing one '
        'reconnect to refresh the GATT connection',
      );
      _autoReconnectPending.add(mac);
      // Disconnect here; _handleDisconnected reconnects when it sees the pending
      // flag, so a fresh _handleConnected runs with a clean subscription.
      await BleService.disconnectDevice(vehicle.device);
    } else {
      debugPrint(
        'Already force-reconnected $mac once this session — not retrying again '
        'to avoid a reconnect loop',
      );
    }
  }

  static Future<void> _handleDisconnected(
    OnConnectionStateChangedEvent event,
    BackgroundVehicle vehicle,
    bool ignoreProximityKey,
  ) async {
    final subscription = _subscriptions[event.device.remoteId.str];

    if (subscription != null) {
      subscription.cancel();
      _subscriptions.remove(event.device.remoteId.str);
    }

    // Only treat this as a real disconnect if the device had actually
    // connected. autoConnect can emit a `disconnected` event for a device that
    // was never present (e.g. a vehicle added months ago and out of range),
    // which must not produce a notification or an activity log entry.
    final bool wasConnected = _connectedMacs.remove(event.device.remoteId.str);

    // If we disconnected on purpose to recover a dead notification pipe (see
    // _ensureNotificationsWorking), reconnect right away and skip the
    // user-facing disconnect notification/vibration/log — it isn't a real
    // disconnect from the user's perspective.
    if (_autoReconnectPending.remove(event.device.remoteId.str)) {
      debugPrint(
        'Reconnecting ${event.device.remoteId.str} to recover notifications',
      );
      await BleService.connectToDevice(vehicle.device);
      return;
    }

    if (!wasConnected) {
      debugPrint(
        'Ignoring disconnect for ${event.device.remoteId.str} that was never connected',
      );
      return;
    }

    if (_proximityKeyEnabled && !ignoreProximityKey) {
      _updateNotification(
        'Disconnected from ${vehicle.data.name} (Proxy Locked)',
        '${vehicle.data.name} disconnected and was locked. Waiting for connection...',
      );
    } else {
      _updateNotification(
        'Disconnected from ${vehicle.data.name}',
        '${vehicle.data.name} is disconnected. Waiting for connection...',
      );
    }

    // The device was disconnected without having time to say it locked, so let the user know it was locked here
    if (_proximityKeyEnabled &&
        _vibrate &&
        !ignoreProximityKey &&
        !vehicle.doorsLocked) {
      _vibrateLongTwice();
    } else {
      debugPrint(
        'Not vibrating on disconnect, _proximityKeyEnabled: $_proximityKeyEnabled, _vibrate: $_vibrate, ignoreProximityKey: $ignoreProximityKey, vehicle.doorsLocked: ${vehicle.doorsLocked}',
      );
    }

    ActivityService.instance.logDisconnectedFromVehicle(vehicle.data);
  }

  static Future<void> _handleMessage(Esp32ResponseDate espResponseData) async {
    if (espResponseData.command == Esp32Response.VERSION) {
      await _prefs.reload();
      final ignoreProtocolMismatch =
          _prefs.getBool('ignoreProtocolMismatch') ?? false;
      final deviceProtocolVersion = espResponseData.parser.getString();

      debugPrint(
        'Device protocol version: $deviceProtocolVersion, ignoreProtocolMismatch: $ignoreProtocolMismatch',
      );

      if (deviceProtocolVersion != PROTOCOL_VERSION &&
          !ignoreProtocolMismatch) {
        BackgroundVehicle? changedVehicle = _getChangedVehicle(
          espResponseData.macAddress,
        );

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
    } else if (espResponseData.command == Esp32Response.FEATURES) {
      BackgroundVehicle? changedVehicle = _getChangedVehicle(
        espResponseData.macAddress,
      );

      if (changedVehicle != null) {
        int? featuresBitmask = espResponseData.parser.getInt32();
        if (featuresBitmask == null) {
          return;
        }
        Set<Feature> features = featuresFromMask(featuresBitmask);
        debugPrint('Received features: $features');

        final data = changedVehicle.data;
        await VehicleStorage.updateVehicle(data.copyWith(features: features));

        FlutterForegroundTask.sendDataToMain({
          'event': 'reload_vehicle_data',
          'macAddress': espResponseData.macAddress,
        });

        WidgetService.reloadVehicles();
      }
    } else if (espResponseData.command == Esp32Response.INVALID_HMAC) {
      BackgroundVehicle? changedVehicle = _getChangedVehicle(
        espResponseData.macAddress,
      );

      ActivityService.instance.logAuthenticationFailed(changedVehicle?.data);
    } else if (espResponseData.command == Esp32Response.PROXIMITY_LOCKED) {
      BackgroundVehicle? changedVehicle = _getChangedVehicle(
        espResponseData.macAddress,
      );

      changedVehicle?.doorsLocked = true;

      ActivityService.instance.logProximityLocked(changedVehicle?.data);

      if (_vibrate) {
        _vibrateLongTwice();
      }

      _updateNotification(
        'Connected to ${changedVehicle?.data.name ?? '<Failed to load name>'} (Proxy Locked)',
        '${changedVehicle?.data.name ?? '<Failed to load name>'} connected and locked since it is too far away.',
      );
    } else if (espResponseData.command == Esp32Response.PROXIMITY_UNLOCKED) {
      BackgroundVehicle? changedVehicle = _getChangedVehicle(
        espResponseData.macAddress,
      );

      changedVehicle?.doorsLocked = false;

      ActivityService.instance.logProximityUnlocked(changedVehicle?.data);

      if (_vibrate) {
        _vibrateLongTwice();
      }

      _updateNotification(
        'Connected to ${changedVehicle?.data.name ?? '<Failed to load name>'} (Proxy Unlocked)',
        '${changedVehicle?.data.name ?? '<Failed to load name>'} connected and was unlocked.',
      );
    } else if (espResponseData.command == Esp32Response.LOCKED) {
      BackgroundVehicle? changedVehicle = _getChangedVehicle(
        espResponseData.macAddress,
      );

      changedVehicle?.doorsLocked = true;
    } else if (espResponseData.command == Esp32Response.UNLOCKED) {
      BackgroundVehicle? changedVehicle = _getChangedVehicle(
        espResponseData.macAddress,
      );

      changedVehicle?.doorsLocked = false;
    }
  }

  //---------- Code for handling function calls from the frontend ----------
  // Dispatches messages sent from the UI/widget via
  // [FlutterForegroundTask.sendDataToTask]. flutter_foreground_task has no
  // named-event channel, so every message carries a 'method' discriminator and
  // we switch on it here (replaces the old service.on('method') registrations).
  static Future<void> handleTaskData(Map<String, dynamic> data) async {
    final method = data['method'];

    switch (method) {
      case 'stopService':
        await FlutterForegroundTask.stopService();
        debugPrint('Background service stopped...');
        break;

      case 'handle_app_detached':
        bool backgroundService = _prefs.getBool('backgroundService') ?? true;
        if (!backgroundService) {
          await FlutterForegroundTask.stopService();
          debugPrint('Background service stopped...');
        }
        break;

      case 'reload_homescreen_widget':
        WidgetService.reloadVehicles();
        break;

      case 'change_homescreen_widget_vehicle':
        WidgetService.changeVehicle();
        break;

      case 'set_proximity_key':
        bool enabled = data['enabled'];
        _proximityKeyEnabled = enabled;

        ClientCommand command = enabled
            ? ClientCommand.PROXIMITY_KEY_ON
            : ClientCommand.PROXIMITY_KEY_OFF;
        for (final vehicle in vehicles) {
          if (!vehicle.device.isConnected) continue;
          await BleService.sendCommand(vehicle.device, command);
          if (enabled) {
            await Future.delayed(Duration(milliseconds: 200));
            await BleService.sendCommandWithFloats(
              vehicle.device,
              ClientCommand.RSSI_TRIGGER,
              [_proximityStrength, _deadZone],
            );
            await Future.delayed(Duration(milliseconds: 200));
            await BleService.sendCommandWithFloat(
              vehicle.device,
              ClientCommand.PROXIMITY_COOLDOWN,
              _proximityCooldown,
            );
          }
        }
        break;

      case 'set_proximity_cooldown':
        double cooldown = data['cooldown'].toDouble();
        _proximityCooldown = cooldown;
        for (final vehicle in vehicles) {
          if (!vehicle.device.isConnected) continue;
          await BleService.sendCommandWithFloat(
            vehicle.device,
            ClientCommand.PROXIMITY_COOLDOWN,
            cooldown,
          );
        }
        break;

      case 'set_vibrate':
        _vibrate = data['enabled'];
        break;

      case 'send_data':
        for (final vehicle in vehicles) {
          if (!vehicle.device.isConnected) continue;
          await BleService.sendCommand(vehicle.device, ClientCommand.GET_DATA);
          await Future.delayed(Duration(milliseconds: 200));
          await BleService.sendCommand(
            vehicle.device,
            ClientCommand.GET_VERSION,
          );
        }
        break;

      case 'set_dead_zone':
        double deadZone = data['deadZone'].toDouble();
        _deadZone = deadZone;
        for (final vehicle in vehicles) {
          if (!vehicle.device.isConnected) continue;
          await BleService.sendCommandWithFloats(
            vehicle.device,
            ClientCommand.RSSI_TRIGGER,
            [_proximityStrength, deadZone],
          );
        }
        break;

      case 'set_proximity_strength':
        double strength = data['strength'].toDouble();
        _proximityStrength = strength;
        for (final vehicle in vehicles) {
          if (!vehicle.device.isConnected) continue;
          await BleService.sendCommandWithFloats(
            vehicle.device,
            ClientCommand.RSSI_TRIGGER,
            [_proximityStrength, _deadZone],
          );
        }
        break;

      case 'reload_vehicles':
        await VehicleStorage.reloadPrefs();
        BleService.reloadPrefs();
        _getVehicles();
        break;

      case 'try_connect_all':
        for (final vehicle in vehicles) {
          await BleService.connectToDevice(vehicle.device);
        }
        break;

      case 'widget_action':
        await _handleWidgetAction(data['action'], data['macAddress']);
        break;

      case 'send_command':
        {
          final String? correlationId = data['correlationId'];
          BluetoothDevice device = BluetoothDevice.fromId(data['macAddress']);
          ClientCommand? command = ClientCommand.fromValue(data['command']);
          final rawData = data['additionalData'];
          Uint8List? additionalData = rawData == null
              ? null
              : Uint8List.fromList(List<int>.from(rawData));

          if (command == null) return;

          try {
            await BleService.sendCommand(
              device,
              command,
              additionalData: additionalData,
            );

            final vehicle = vehicles.firstWhereOrNull(
              (v) => v.data.macAddress == device.remoteId.str,
            );
            ActivityService.instance.logFromCommand(command, vehicle?.data);

            FlutterForegroundTask.sendDataToMain({
              'event': 'send_command_result',
              'correlationId': correlationId,
              'success': true,
            });
          } catch (e) {
            FlutterForegroundTask.sendDataToMain({
              'event': 'send_command_result',
              'correlationId': correlationId,
              'success': false,
              'error': e.toString(),
            });
          }
        }
        break;

      case 'disconnect_device':
        {
          BluetoothDevice device = BluetoothDevice.fromId(data['macAddress']);
          BleService.disconnectDevice(device);
        }
        break;

      case 'connect_to_device':
        {
          final macAddress = data['macAddress'];
          final requestId = data['requestId'];

          if (macAddress == null || requestId == null) {
            return;
          }

          try {
            final bluetoothDevice = await BleService.connectToDevice(
              BluetoothDevice.fromId(macAddress),
            );

            // Send the result back
            FlutterForegroundTask.sendDataToMain({
              'event': 'connect_result',
              'requestId': requestId,
              'macAddress': bluetoothDevice?.remoteId.str,
            });
          } catch (e) {
            FlutterForegroundTask.sendDataToMain({
              'event': 'connect_result',
              'requestId': requestId,
              'error': e.toString(),
            });
          }
        }
        break;
    }
  }

  /// Handles a home-screen widget button press. Runs in the background task
  /// isolate (where [WidgetService]'s connected-vehicle state is populated), so
  /// the pending spinner and widget refresh use real state instead of wiping
  /// the widget to "nothing connected". Mirrors the in-app button behavior.
  static Future<void> _handleWidgetAction(
    String action,
    String macAddress,
  ) async {
    final device = BluetoothDevice.fromId(macAddress);
    final vehicle = vehicles.firstWhereOrNull(
      (v) => v.data.macAddress == macAddress,
    );

    switch (action) {
      case 'lock':
      case 'unlock':
        // Spinner cleared by WidgetService.processMessage on the ESP's
        // LOCKED/UNLOCKED confirmation (or the pending safety timeout).
        WidgetService.setPending(macAddress, 'doors');
        final command = action == 'lock'
            ? ClientCommand.LOCK_DOORS
            : ClientCommand.UNLOCK_DOORS;
        await BleService.sendCommand(device, command);
        ActivityService.instance.logFromCommand(command, vehicle?.data);
        break;
      case 'open_trunk':
        // The trunk has no ESP state confirmation, so clear the spinner when the
        // command write round-trip completes (or on the safety timeout).
        WidgetService.setPending(macAddress, 'trunk');
        try {
          await BleService.sendCommand(device, ClientCommand.OPEN_TRUNK);
          ActivityService.instance.logFromCommand(
            ClientCommand.OPEN_TRUNK,
            vehicle?.data,
          );
        } finally {
          WidgetService.clearPending(macAddress, 'trunk');
        }
        break;
      case 'start_engine':
        //TODO: Implement engine start
        break;
    }
  }

  //Functions to call from app/foreground
  static void reloadHomescreenWidget() {
    FlutterForegroundTask.sendDataToTask({'method': 'reload_homescreen_widget'});
  }

  static void changeHomescreenWidgetVehicle() {
    FlutterForegroundTask.sendDataToTask({
      'method': 'change_homescreen_widget_vehicle',
    });
  }

  /// Forwards a home-screen widget button press to the background task isolate.
  /// Called from home_widget's isolate (via [WidgetService.backgroundCallback]).
  static void sendWidgetAction(String macAddress, String action) {
    FlutterForegroundTask.sendDataToTask({
      'method': 'widget_action',
      'action': action,
      'macAddress': macAddress,
    });
  }

  static void handleAppDetached() {
    FlutterForegroundTask.sendDataToTask({'method': 'handle_app_detached'});
  }

  static Future<void> disableBackgroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }

    await Future.delayed(Duration(seconds: 5));

    initializeService(backgroundServiceEnabled: false);
  }

  static Future<void> enableBackgroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }

    await Future.delayed(Duration(seconds: 5));

    initializeService(backgroundServiceEnabled: true);
  }

  static Future<List<BleDevice>> getConnectedDevices() async {
    return await BleDeviceStorageService.loadBleDevices();
  }

  static Future<BleDevice> connectToDevice(BluetoothDevice device) async {
    // Create a unique ID for this request
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();

    final completer = Completer<BleDevice>();

    late void Function(Object) callback;
    callback = (responseData) {
      if (responseData is! Map) return;
      if (responseData['event'] != 'connect_result') return;
      if (responseData['requestId'] != requestId) return;

      FlutterForegroundTask.removeTaskDataCallback(callback);
      if (completer.isCompleted) return;

      if (responseData.containsKey('error')) {
        completer.completeError(responseData['error']);
      } else {
        completer.complete(BleDevice(macAddress: responseData['macAddress']));
      }
    };
    FlutterForegroundTask.addTaskDataCallback(callback);

    // Send the request with the request ID
    FlutterForegroundTask.sendDataToTask({
      'method': 'connect_to_device',
      'macAddress': device.remoteId.str,
      'requestId': requestId,
    });

    // Add timeout handling
    Timer(Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError('Connection timeout');
      }
    });

    return completer.future.whenComplete(
      () => FlutterForegroundTask.removeTaskDataCallback(callback),
    );
  }

  static void requestData() {
    FlutterForegroundTask.sendDataToTask({'method': 'send_data'});
  }

  static void setProximityCooldown(double cooldown) {
    FlutterForegroundTask.sendDataToTask({
      'method': 'set_proximity_cooldown',
      'cooldown': cooldown,
    });
  }

  static void setVibrate(bool enabled) {
    FlutterForegroundTask.sendDataToTask({
      'method': 'set_vibrate',
      'enabled': enabled,
    });
  }

  static void setDeadZone(double deadZone) {
    FlutterForegroundTask.sendDataToTask({
      'method': 'set_dead_zone',
      'deadZone': deadZone,
    });
  }

  static void setProximityKey(bool enabled) {
    FlutterForegroundTask.sendDataToTask({
      'method': 'set_proximity_key',
      'enabled': enabled,
    });
  }

  static void setProximityStrength(double strength) {
    FlutterForegroundTask.sendDataToTask({
      'method': 'set_proximity_strength',
      'strength': strength,
    });
  }

  static void reloadVehicles() {
    FlutterForegroundTask.sendDataToTask({'method': 'reload_vehicles'});
  }

  static void tryConnectAll() {
    FlutterForegroundTask.sendDataToTask({'method': 'try_connect_all'});
  }

  static void disconnectDevice(BleDevice device) {
    FlutterForegroundTask.sendDataToTask({
      'method': 'disconnect_device',
      'macAddress': device.macAddress,
    });
  }

  /// Send a command to a device.
  static Future<void> sendCommand(
    BleDevice device,
    ClientCommand command, {
    Uint8List? additionalData,
  }) async {
    final String correlationId = DateTime.now().microsecondsSinceEpoch
        .toString();

    final completer = Completer<void>();

    // Set up a timeout so we don't wait forever
    final timeout = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('sendCommand timed out'));
      }
    });

    // Listen for the matching result
    late void Function(Object) callback;
    callback = (responseData) {
      if (responseData is! Map) return;
      if (responseData['event'] != 'send_command_result') return;
      if (responseData['correlationId'] != correlationId) return; // Not ours

      FlutterForegroundTask.removeTaskDataCallback(callback);
      timeout.cancel();

      if (completer.isCompleted) return;

      if (responseData['success'] == true) {
        Future.delayed(Duration(milliseconds: 100), () {
          if (!completer.isCompleted) completer.complete();
        });
      } else {
        completer.completeError(
          Exception(responseData['error'] ?? 'Unknown error'),
        );
      }
    };
    FlutterForegroundTask.addTaskDataCallback(callback);

    // Send the command
    FlutterForegroundTask.sendDataToTask({
      'method': 'send_command',
      'correlationId': correlationId,
      'macAddress': device.macAddress,
      'command': command.value,
      'additionalData': additionalData?.toList(),
    });

    return completer.future.whenComplete(() {
      timeout.cancel();
      FlutterForegroundTask.removeTaskDataCallback(callback);
    });
  }
}
