#ifndef COMMAND_CODES_H
#define COMMAND_CODES_H

#include <stdint.h>

// clang-format off
// Protocol Version: V2

/// @brief Commands sent by the client/app to the ESP32
enum class ClientCommand : uint8_t
{
    GET_VERSION        = 0x00,
    GET_DATA          = 0x01,
    LOCK_DOORS         = 0x02,
    UNLOCK_DOORS       = 0x03,
    OPEN_TRUNK         = 0x04,
    START_ENGINE       = 0x05,
    STOP_ENGINE        = 0x06,
    PROXIMITY_KEY_ON   = 0x07,
    PROXIMITY_KEY_OFF  = 0x08,
    PROXIMITY_COOLDOWN = 0x09,   // includes proximity cooldown float in min
    RSSI_TRIGGER       = 0x0A,   // includes Rssi float, Rssi dead zone float
    GET_RSSI           = 0x0B
};

/// @brief ESP32-to-Client Commands
enum class Esp32Response : uint8_t
{
    INVALID_HMAC       = 0x00,
    VERSION            = 0x01,
    LOCKED             = 0x02,
    PROXIMITY_LOCKED   = 0x03,
    UNLOCKED           = 0x04,
    PROXIMITY_UNLOCKED = 0x05,
    RSSI               = 0x06   // includes Rssi float
};

#endif