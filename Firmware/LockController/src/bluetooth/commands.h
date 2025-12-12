#ifndef COMMAND_CODES_H
#define COMMAND_CODES_H

#include <stdint.h>

// clang-format off
// Protocol Version: V2

/// @brief Commands sent by the client/app to the ESP32
enum class ClientCommand : uint8_t
{
    GET_VERSION        = 0x00,
    GET_DATA           = 0x01,
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

const char* toString(ClientCommand cmd)
{
    switch (cmd)
    {
        case ClientCommand::GET_VERSION:  return "GET_VERSION";
        case ClientCommand::GET_DATA:     return "GET_DATA";
        case ClientCommand::LOCK_DOORS:   return "LOCK_DOORS";
        case ClientCommand::UNLOCK_DOORS: return "UNLOCK_DOORS";
        case ClientCommand::OPEN_TRUNK:   return "OPEN_TRUNK";
        case ClientCommand::START_ENGINE: return "START_ENGINE";
        case ClientCommand::STOP_ENGINE:  return "STOP_ENGINE";
        case ClientCommand::PROXIMITY_KEY_ON:   return "PROXIMITY_KEY_ON";
        case ClientCommand::PROXIMITY_KEY_OFF:  return "PROXIMITY_KEY_OFF";
        case ClientCommand::PROXIMITY_COOLDOWN: return "PROXIMITY_COOLDOWN";
        case ClientCommand::RSSI_TRIGGER:       return "RSSI_TRIGGER";
        case ClientCommand::GET_RSSI:           return "GET_RSSI";
        default: return "UNKNOWN_COMMAND";
    }
}


/// @brief ESP32-to-Client Commands
enum class Esp32Response : uint8_t
{
    INVALID_HMAC       = 0x00,
    VERSION            = 0x01,  // includes protocol version
    LOCKED             = 0x02,
    PROXIMITY_LOCKED   = 0x03,
    UNLOCKED           = 0x04,
    PROXIMITY_UNLOCKED = 0x05,
    RSSI               = 0x06   // includes Rssi float
};

#endif