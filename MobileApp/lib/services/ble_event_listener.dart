import 'package:flutter/services.dart';

class BleEventListener {
  static Function(String)? onDeviceAppeared;
  static Function(String)? onDeviceConnected;
  static Function(String)? onDeviceDisconnected;
  static Function(String)? onDeviceDeviceReady;

  static Function(/*Mac Address:*/ String, /*Message:*/ String)?
      onMessageReceived;
  static Function(/*Mac Address:*/ String, /*Message:*/ String)? onMessageSent;

  static const EventChannel _eventChannel =
      EventChannel('com.smartify_os.open_car_key_app/ble_events');

  static void listenForBleEvents(Function(String) onEventReceived) {
    _eventChannel.receiveBroadcastStream().listen((event) {
      print("BLE Event: $event");
      String eventString = event.toString();
      onEventReceived(event);
      if (eventString.startsWith("DEVICE_APPEARED:")) {
        onDeviceAppeared?.call(eventString.substringAfter(":"));
      } else if (eventString.startsWith("DEVICE_CONNECTED:")) {
        onDeviceConnected?.call(eventString.substringAfter(":"));
      } else if (eventString.startsWith("DEVICE_DISCONNECTED:")) {
        onDeviceDisconnected?.call(eventString.substringAfter(":"));
      } else if (eventString.startsWith("DEVICE_READY:")) {
        onDeviceDeviceReady?.call(eventString.substringAfter(":"));
      } else if (eventString.startsWith("MESSAGE_RECEIVED:")) {
        var parts = eventString.substringAfter(":").split(";");
        onMessageReceived?.call(parts[1], parts[0]);
      } else if (eventString.startsWith("MESSAGE_SENT:")) {
        onMessageSent?.call(eventString.substringAfter(":"), "");
      }
    }, onError: (error) {
      print("BLE Event Error: $error");
    });
  }
}

extension on String {
  String substringAfter(String s) {
    int index = this.indexOf(s);
    if (index == -1) {
      return this;
    } else {
      return this.substring(index + s.length);
    }
  }
}
