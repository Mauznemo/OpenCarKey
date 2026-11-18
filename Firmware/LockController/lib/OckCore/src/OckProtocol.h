#pragma once

#include <stddef.h>
#include <stdint.h>
#include "OckFeatures.h"

// clang-format off
// Protocol Version: V5

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
    GET_RSSI           = 0x0B,
    GET_FEATURES       = 0x0C,
    OPEN_WINDOWS       = 0x0D,
    CLOSE_WINDOWS      = 0x0E
};

inline const char* toString(ClientCommand cmd)
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
        case ClientCommand::GET_FEATURES:       return "GET_FEATURES";
        case ClientCommand::OPEN_WINDOWS:       return "OPEN_WINDOWS";
        case ClientCommand::CLOSE_WINDOWS:      return "CLOSE_WINDOWS";
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
    RSSI               = 0x06,   // includes Rssi float
    FEATURES           = 0x07,   // includes supported features
    ENGINE_STARTED     = 0x08,
    ENGINE_STOPPED     = 0x09,
    WINDOWS_OPENED     = 0x0A,
    WINDOWS_CLOSED     = 0x0B,
};
// clang-format on

namespace ock
{
    /// @brief Version of the bluetooth protocol, bump it whenever the message format changes
    constexpr const char *PROTOCOL_VERSION = "V5";

    constexpr size_t HMAC_SIZE = 32;
    /// @brief HMAC + command byte, the smallest valid message
    constexpr size_t MIN_MESSAGE_SIZE = HMAC_SIZE + 1;
    /// @brief Most additional data bytes a client message may carry
    constexpr size_t MAX_DATA_LENGTH = 12;
    /// @brief Random value the controller picks for every connection, part of the HMAC input
    constexpr size_t SESSION_NONCE_SIZE = 16;
    /// @brief Value of the session info characteristic (ffe2): nonce (16) + counter (uint32 little endian)
    constexpr size_t SESSION_INFO_SIZE = SESSION_NONCE_SIZE + 4;
    /// @brief nonce (16) + counter (4) + command (1) + data length (1) + data
    constexpr size_t MAX_HMAC_INPUT_SIZE = SESSION_NONCE_SIZE + 4 + 1 + 1 + MAX_DATA_LENGTH;

    /// @brief True if `command` is one of the ClientCommand values
    bool isKnownCommand(uint8_t command);

    /// @brief The vehicle feature a command needs, Feature::None if it is always allowed
    Feature requiredFeature(ClientCommand command);

    /// @brief How many additional data bytes the command has to carry
    size_t expectedDataLength(ClientCommand command);
}
