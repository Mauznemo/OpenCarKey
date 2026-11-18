import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'vehicle_data.dart';
import 'vehicle_session.dart';

class BackgroundVehicle {
  BluetoothDevice device;
  VehicleData data;
  // Cached ffe1 write characteristic for the current connection. Set on connect,
  // cleared on disconnect, so sendCommand can skip re-negotiating MTU and
  // rediscovering services on every command.
  BluetoothCharacteristic? characteristic;
  // Nonce and next counter of the current connection, read from the vehicle
  // before the first command (see BleService). Forgotten on every connect and
  // disconnect, it must never be used on another connection.
  VehicleSession? session;
  // True once this connection turned out to have no session characteristic
  // (firmware older than the app), so that is only checked and reported once.
  bool sessionUnsupported = false;
  bool doorsLocked;
  bool trunkLocked;
  bool engineOn;
  bool windowsOpen;

  BackgroundVehicle({
    required this.device,
    required this.data,
    this.doorsLocked = true,
    this.trunkLocked = true,
    this.engineOn = false,
    this.windowsOpen = false,
  });

  /// Forgets everything that belongs to the session of the current connection.
  void forgetSession() {
    session = null;
    sessionUnsupported = false;
  }
}
