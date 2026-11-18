#pragma once

#include <stddef.h>
#include <stdint.h>
#include "OckAuth.h"
#include "OckFeatures.h"
#include "OckProtocol.h"

namespace ock
{
    enum class CommandStatus
    {
        /// @brief Authentic, supported and valid, run it
        Accepted,
        Malformed,
        InvalidHmac,
        /// @brief The counter could not be loaded or saved
        StorageError,
        CounterExhausted,
        /// @brief No connection session is active, nothing can be authentic
        NoSession,
        /// @brief Authentic but the command byte is unknown
        UnknownCommand,
        /// @brief Authentic but the vehicle doesn't have the feature (see SUPPORTED_FEATURES)
        UnsupportedFeature,
        /// @brief Authentic but the additional data has the wrong size or values out of range
        InvalidData,
    };

    struct CommandDecision
    {
        CommandStatus status;
        ClientCommand command;
        /// @brief Parsed and validated values: RSSI_TRIGGER (trigger, dead zone), PROXIMITY_COOLDOWN (minutes)
        float values[2];
    };

    /// @brief Runs every check an incoming message has to pass before its command may run:
    /// structure, HMAC + rolling code, known command, supported feature and data validation.
    CommandDecision processClientMessage(RollingCodeVerifier &verifier, Feature supportedFeatures,
                                         const uint8_t *buffer, size_t length);

    const char *toString(CommandStatus status);

    /// @brief True if the client should be told with INVALID_HMAC (the message was not authentic)
    bool shouldReplyInvalidHmac(CommandStatus status);
}
