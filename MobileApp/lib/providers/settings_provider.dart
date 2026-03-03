import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/settings_state.dart';

part 'settings_provider.g.dart';

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();

  void init(
      {required bool proximityKey,
      required bool ignoreProtocolMismatch,
      required bool showMacAddress,
      required double triggerStrength,
      required bool vibrate,
      required double deadZone,
      required double proximityCooldown,
      required bool backgroundService}) {
    state = state.copyWith(
        proximityKey: proximityKey,
        ignoreProtocolMismatch: ignoreProtocolMismatch,
        showMacAddress: showMacAddress,
        triggerStrength: triggerStrength,
        vibrate: vibrate,
        deadZone: deadZone,
        proximityCooldown: proximityCooldown,
        backgroundService: backgroundService);
  }

  void setProximityKey(bool value) {
    state = state.copyWith(proximityKey: value);
  }

  void setIgnoreProtocolMismatch(bool value) {
    state = state.copyWith(ignoreProtocolMismatch: value);
  }

  void setShowMacAddress(bool value) {
    state = state.copyWith(showMacAddress: value);
  }

  void setTriggerStrength(double value) {
    state = state.copyWith(triggerStrength: value);
  }

  void setVibrate(bool value) {
    state = state.copyWith(vibrate: value);
  }

  void setDeadZone(double value) {
    state = state.copyWith(deadZone: value);
  }

  void setProximityCooldown(double value) {
    state = state.copyWith(proximityCooldown: value);
  }

  void setBackgroundService(bool enabled) {
    state = state.copyWith(backgroundService: enabled);
  }
}
