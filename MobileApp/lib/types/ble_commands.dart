// Protocol version: V2

/// Commands sent by the client/app to the ESP32
enum ClientCommand {
  GET_VERSION(0x00),
  GET_DATA(0x01),
  LOCK_DOORS(0x02),
  UNLOCK_DOORS(0x03),
  OPEN_TRUNK(0x04),
  START_ENGINE(0x05),
  STOP_ENGINE(0x06),
  PROXIMITY_KEY_ON(0x07),
  PROXIMITY_KEY_OFF(0x08),
  PROXIMITY_COOLDOWN(0x09), // includes proximity cooldown float in min
  RSSI_TRIGGER(0x0A), // includes Rssi float, Rssi dead zone float
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
  INVALID_HMAC(0x00),
  VERSION(0x01),
  LOCKED(0x02),
  PROXIMITY_LOCKED(0x03),
  UNLOCKED(0x04),
  PROXIMITY_UNLOCKED(0x05),
  RSSI(0x06); // includes Rssi float

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
