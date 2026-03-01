import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';
import 'ble_background_service.dart';

class SettingsService {
  SettingsService._();

  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();

  late BuildContext context;
  late WidgetRef ref;
  late SharedPreferences prefs;

  Future<void> init(BuildContext context, WidgetRef ref) async {
    this.context = context;
    this.ref = ref;

    prefs = await SharedPreferences.getInstance();

    final proximityKey = prefs.getBool('proximityKey') ?? false;
    final ignoreProtocolMismatch =
        prefs.getBool('ignoreProtocolMismatch') ?? false;
    final showMacAddress = prefs.getBool('showMacAddress') ?? true;
    final triggerStrength = prefs.getDouble('triggerStrength') ?? -200;
    final vibrate = prefs.getBool('vibrate') ?? true;
    final deadZone = prefs.getDouble('deadZone') ?? 4;
    final proximityCooldown = prefs.getDouble('proximityCooldown') ?? 1;
    final backgroundService = prefs.getBool('backgroundService') ?? true;

    ref.read(settingsProvider.notifier).init(
        proximityKey: proximityKey,
        ignoreProtocolMismatch: ignoreProtocolMismatch,
        showMacAddress: showMacAddress,
        triggerStrength: triggerStrength,
        vibrate: vibrate,
        deadZone: deadZone,
        proximityCooldown: proximityCooldown,
        backgroundService: backgroundService);
  }

  void setIgnoreProtocolMismatch(bool value) {
    prefs.setBool('ignoreProtocolMismatch', value);
    ref.read(settingsProvider.notifier).setIgnoreProtocolMismatch(value);
  }

  void setShowMacAddress(bool value) {
    prefs.setBool('showMacAddress', value);
    ref.read(settingsProvider.notifier).setShowMacAddress(value);
  }

  void setProximityKey(bool value) {
    prefs.setBool('proximityKey', value);
    BleBackgroundService.setProximityKey(value);
    ref.read(settingsProvider.notifier).setProximityKey(value);
  }

  void setTriggerStrength(double value) {
    BleBackgroundService.setProximityStrength(-200);
    prefs.setDouble('triggerStrength', value);
    ref.read(settingsProvider.notifier).setTriggerStrength(value);
  }

  void setVibrate(bool value) {
    BleBackgroundService.setVibrate(value);
    prefs.setBool('vibrate', value);
    ref.read(settingsProvider.notifier).setVibrate(value);
  }

  void setDeadZone(double value) {
    BleBackgroundService.setDeadZone(value);
    prefs.setDouble('deadZone', value);
    ref.read(settingsProvider.notifier).setDeadZone(value);
  }

  void setProximityCooldown(double value) {
    BleBackgroundService.setProximityCooldown(value);
    prefs.setDouble('proximityCooldown', value);
    ref.read(settingsProvider.notifier).setProximityCooldown(value);
  }

  void setBackgroundService(bool enabled) {
    final wasEnabled = ref.read(settingsProvider).backgroundService;

    if (enabled) {
      if (wasEnabled) return;
      BleBackgroundService.enableBackgroundService();
    } else {
      if (!wasEnabled) return;
      BleBackgroundService.disableBackgroundService();
    }
    prefs.setBool('backgroundService', enabled);
    ref.read(settingsProvider.notifier).setBackgroundService(enabled);
  }

  void dispose() {
    _instance = null;
  }
}
