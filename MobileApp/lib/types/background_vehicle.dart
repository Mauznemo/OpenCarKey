import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'vehicle_data.dart';

class BackgroundVehicle {
  BluetoothDevice device;
  VehicleData data;
  // Cached ffe1 write characteristic for the current connection. Set on connect,
  // cleared on disconnect, so sendCommand can skip re-negotiating MTU and
  // rediscovering services on every command.
  BluetoothCharacteristic? characteristic;
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
}
