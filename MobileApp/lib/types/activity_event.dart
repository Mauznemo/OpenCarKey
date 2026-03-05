import 'dart:convert';

enum ActivityEventType {
  connectedToVehicle,
  disconnectedFromVehicle,
  userLockedVehicle,
  userUnlockedVehicle,
  userOpenedTrunk,
  userStartedEngine,
  userStoppedEngine,
  proximityLocked,
  proximityUnlocked,
  authenticationFailed,
}

extension ActivityEventTypeExtension on ActivityEventType {
  String get label {
    switch (this) {
      case ActivityEventType.connectedToVehicle:
        return 'Connected to Vehicle';
      case ActivityEventType.disconnectedFromVehicle:
        return 'Disconnected from Vehicle';
      case ActivityEventType.userLockedVehicle:
        return 'User Locked Vehicle';
      case ActivityEventType.userUnlockedVehicle:
        return 'User Unlocked Vehicle';
      case ActivityEventType.userOpenedTrunk:
        return 'User Opened Trunk';
      case ActivityEventType.userStartedEngine:
        return 'User Started Engine';
      case ActivityEventType.userStoppedEngine:
        return 'User Stopped Engine';
      case ActivityEventType.proximityLocked:
        return 'Vehicle Proximity Locked';
      case ActivityEventType.proximityUnlocked:
        return 'Vehicle Proximity Unlocked';
      case ActivityEventType.authenticationFailed:
        return 'Authentication Failed';
    }
  }

  String get iconName {
    switch (this) {
      case ActivityEventType.connectedToVehicle:
        return 'bluetooth_connected';
      case ActivityEventType.disconnectedFromVehicle:
        return 'bluetooth_disabled';
      case ActivityEventType.userLockedVehicle:
        return 'lock';
      case ActivityEventType.userUnlockedVehicle:
        return 'lock_open';
      case ActivityEventType.userOpenedTrunk:
        return 'car_repair';
      case ActivityEventType.userStartedEngine:
        return 'power_settings_new';
      case ActivityEventType.userStoppedEngine:
        return 'power_off';
      case ActivityEventType.proximityLocked:
        return 'sensors';
      case ActivityEventType.proximityUnlocked:
        return 'sensors';
      case ActivityEventType.authenticationFailed:
        return 'gpp_bad';
    }
  }

  String get key => name;

  static ActivityEventType fromKey(String key) {
    return ActivityEventType.values.firstWhere((e) => e.name == key);
  }
}

class ActivityEvent {
  final String id;
  final ActivityEventType type;
  final DateTime timestamp;
  final String vehicleName;
  final String macAddress;

  ActivityEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.vehicleName,
    required this.macAddress,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.key,
    'timestamp': timestamp.toIso8601String(),
    'vehicleName': vehicleName,
    'macAddress': macAddress,
  };

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
    id: json['id'] as String,
    type: ActivityEventTypeExtension.fromKey(json['type'] as String),
    timestamp: DateTime.parse(json['timestamp'] as String),
    vehicleName: json['vehicleName'] as String,
    macAddress: json['macAddress'] as String,
  );

  String toJsonString() => jsonEncode(toJson());

  factory ActivityEvent.fromJsonString(String jsonString) =>
      ActivityEvent.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}
