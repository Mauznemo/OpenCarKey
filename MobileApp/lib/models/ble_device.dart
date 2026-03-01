import 'package:freezed_annotation/freezed_annotation.dart';

part 'ble_device.freezed.dart';

@freezed
abstract class BleDevice with _$BleDevice {
  const factory BleDevice(
      {required String macAddress,
      @Default(false) bool isConnected}) = _BleDevice;
}
