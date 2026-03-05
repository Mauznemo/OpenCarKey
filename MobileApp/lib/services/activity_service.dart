import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../types/activity_event.dart';
import '../types/ble_commands.dart';
import '../types/vehicle_data.dart';

/// Call [ActivityService.instance] to access the service.
///
/// Usage from your background service:
///   await ActivityService.instance.logConnectedToVehicle(vehicleName: 'My Car', macAddress: 'AA:BB:CC:DD:EE:FF');
class ActivityService {
  ActivityService._();
  static final ActivityService instance = ActivityService._();

  static const String _storageKey = 'car_key_activity_events';

  Future<void> logConnectedToVehicle(VehicleData? vehicleData) =>
      _log(ActivityEventType.connectedToVehicle, vehicleData);

  Future<void> logDisconnectedFromVehicle(VehicleData? vehicleData) =>
      _log(ActivityEventType.disconnectedFromVehicle, vehicleData);

  Future<void> logUserLockedVehicle(VehicleData? vehicleData) =>
      _log(ActivityEventType.userLockedVehicle, vehicleData);

  Future<void> logUserUnlockedVehicle(VehicleData? vehicleData) =>
      _log(ActivityEventType.userUnlockedVehicle, vehicleData);

  Future<void> logUserOpenedTrunk(VehicleData? vehicleData) =>
      _log(ActivityEventType.userOpenedTrunk, vehicleData);

  Future<void> logUserStartedEngine(VehicleData? vehicleData) =>
      _log(ActivityEventType.userStartedEngine, vehicleData);

  Future<void> logUserStoppedEngine(VehicleData? vehicleData) =>
      _log(ActivityEventType.userStoppedEngine, vehicleData);

  Future<void> logProximityLocked(VehicleData? vehicleData) =>
      _log(ActivityEventType.proximityLocked, vehicleData);

  Future<void> logProximityUnlocked(VehicleData? vehicleData) =>
      _log(ActivityEventType.proximityUnlocked, vehicleData);

  Future<void> logAuthenticationFailed(VehicleData? vehicleData) =>
      _log(ActivityEventType.authenticationFailed, vehicleData);

  void logFromCommand(ClientCommand command, VehicleData? vehicleData) {
    debugPrint(
      '[ActivityService] Logging event command: $command, vehicle: $vehicleData',
    );
    switch (command) {
      case ClientCommand.LOCK_DOORS:
        logUserLockedVehicle(vehicleData);
        break;
      case ClientCommand.UNLOCK_DOORS:
        logUserUnlockedVehicle(vehicleData);
        break;
      case ClientCommand.OPEN_TRUNK:
        logUserOpenedTrunk(vehicleData);
        break;
      case ClientCommand.START_ENGINE:
        logUserStartedEngine(vehicleData);
        break;
      case ClientCommand.STOP_ENGINE:
        logUserStoppedEngine(vehicleData);
        break;
      default:
        break;
    }
  }

  /// Returns all events from the past 30 days, newest first.
  Future<List<ActivityEvent>> getRecentEvents() async {
    final all = await _loadAll(forceReload: true);
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return all.where((e) => e.timestamp.isAfter(cutoff)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Returns all stored events, newest first.
  Future<List<ActivityEvent>> getAllEvents() async {
    final all = await _loadAll();
    return all..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Deletes all stored activity events.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _log(ActivityEventType type, VehicleData? vehicleData) async {
    final event = ActivityEvent(
      id: '${DateTime.now().millisecondsSinceEpoch}_${type.key}',
      type: type,
      timestamp: DateTime.now(),
      vehicleName: vehicleData?.name ?? 'unknown',
      macAddress: vehicleData?.macAddress ?? 'unknown',
    );

    final events = await _loadAll();

    // Prune anything older than 30 days before saving
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    events.removeWhere((e) => e.timestamp.isBefore(cutoff));
    events.add(event);

    await _saveAll(events);
  }

  Future<List<ActivityEvent>> _loadAll({bool forceReload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (forceReload) await prefs.reload();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<ActivityEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
