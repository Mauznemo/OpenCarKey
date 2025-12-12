// ignore_for_file: constant_identifier_names

/// Commands sent by the client/app to the ESP32
enum ClientCommand {
  /// Gets the protocol version of the ESP32
  GET_VERSION(0x00),

  /// Triggers a doors locked or unlocked event depending on the state
  GET_DATA(0x01),

  /// Locks the doors
  LOCK_DOORS(0x02),

  /// Unlocks the doors
  UNLOCK_DOORS(0x03),

  /// Opens the trunk
  OPEN_TRUNK(0x04),

  /// Starts the engine
  START_ENGINE(0x05),

  /// Stops the engine
  STOP_ENGINE(0x06),

  /// Enables proximity key
  PROXIMITY_KEY_ON(0x07),

  /// Disables proximity key
  PROXIMITY_KEY_OFF(0x08),

  /// Sets the proximity cooldown
  ///
  /// Needs additional data: `float` proximity cooldown in minutes
  PROXIMITY_COOLDOWN(0x09),

  /// Sets the RSSI trigger values
  ///
  /// Needs additional data: `float` RSSI trigger, `float` RSSI dead zone
  RSSI_TRIGGER(0x0A),

  /// Gets the current RSSI
  GET_RSSI(0x0B);

  const ClientCommand(this.value);
  final int value;

  /// Convert from integer value to enum
  static ClientCommand? fromValue(int value) {
    for (ClientCommand command in ClientCommand.values) {
      if (command.value == value) {
        return command;
      }
    }
    return null;
  }
}

/// ESP32-to-Client Commands
enum Esp32Response {
  /// The HMAC was invalid
  INVALID_HMAC(0x00),

  /// The protocol version
  VERSION(0x01),

  /// Car was locked manually
  LOCKED(0x02),

  /// Car was locked by proximity
  PROXIMITY_LOCKED(0x03),

  /// Car was unlocked manually
  UNLOCKED(0x04),

  /// Car was unlocked by proximity
  PROXIMITY_UNLOCKED(0x05),

  /// Current RSSI
  ///
  /// Additional data: `float` RSSI
  RSSI(0x06);

  const Esp32Response(this.value);
  final int value;

  /// Convert from integer value to enum
  static Esp32Response? fromValue(int value) {
    for (Esp32Response response in Esp32Response.values) {
      if (response.value == value) {
        return response;
      }
    }
    return null;
  }
}
