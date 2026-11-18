#include "OckCommandProcessor.h"

#include <string.h>
#include "OckProximity.h"

namespace ock
{
    namespace
    {
        CommandDecision makeDecision(CommandStatus status, ClientCommand command)
        {
            CommandDecision decision;
            decision.status = status;
            decision.command = command;
            decision.values[0] = 0.0f;
            decision.values[1] = 0.0f;
            return decision;
        }

        float readFloat(const uint8_t *data)
        {
            float value;
            memcpy(&value, data, sizeof(float));
            return value;
        }
    }

    CommandDecision processClientMessage(RollingCodeVerifier &verifier, Feature supportedFeatures,
                                         const uint8_t *buffer, size_t length)
    {
        ClientMessage message;
        if (!parseClientMessage(buffer, length, message))
            return makeDecision(CommandStatus::Malformed, ClientCommand::GET_VERSION);

        const ClientCommand command = static_cast<ClientCommand>(message.command);

        switch (verifier.authenticate(message))
        {
        case AuthResult::Ok:
            break;
        case AuthResult::InvalidHmac:
            return makeDecision(CommandStatus::InvalidHmac, command);
        case AuthResult::CounterExhausted:
            return makeDecision(CommandStatus::CounterExhausted, command);
        case AuthResult::NoSession:
            return makeDecision(CommandStatus::NoSession, command);
        case AuthResult::NotReady:
        case AuthResult::StorageError:
        default:
            return makeDecision(CommandStatus::StorageError, command);
        }

        if (!isKnownCommand(message.command))
            return makeDecision(CommandStatus::UnknownCommand, command);

        if (!hasFeature(supportedFeatures, requiredFeature(command)))
            return makeDecision(CommandStatus::UnsupportedFeature, command);

        if (message.dataLength != expectedDataLength(command))
            return makeDecision(CommandStatus::InvalidData, command);

        CommandDecision decision = makeDecision(CommandStatus::Accepted, command);

        if (command == ClientCommand::RSSI_TRIGGER)
        {
            decision.values[0] = readFloat(message.data);
            decision.values[1] = readFloat(message.data + sizeof(float));
            if (!isValidRssiTrigger(decision.values[0], decision.values[1]))
                return makeDecision(CommandStatus::InvalidData, command);
        }
        else if (command == ClientCommand::PROXIMITY_COOLDOWN)
        {
            decision.values[0] = readFloat(message.data);
            if (!isValidProximityCooldown(decision.values[0]))
                return makeDecision(CommandStatus::InvalidData, command);
        }

        return decision;
    }

    const char *toString(CommandStatus status)
    {
        switch (status)
        {
        case CommandStatus::Accepted:           return "Accepted";
        case CommandStatus::Malformed:          return "Malformed";
        case CommandStatus::InvalidHmac:        return "InvalidHmac";
        case CommandStatus::StorageError:       return "StorageError";
        case CommandStatus::CounterExhausted:   return "CounterExhausted";
        case CommandStatus::NoSession:          return "NoSession";
        case CommandStatus::UnknownCommand:     return "UnknownCommand";
        case CommandStatus::UnsupportedFeature: return "UnsupportedFeature";
        case CommandStatus::InvalidData:        return "InvalidData";
        default:                                return "Unknown";
        }
    }

    bool shouldReplyInvalidHmac(CommandStatus status)
    {
        switch (status)
        {
        case CommandStatus::Malformed:
        case CommandStatus::InvalidHmac:
        case CommandStatus::StorageError:
        case CommandStatus::CounterExhausted:
        case CommandStatus::NoSession:
            return true;
        default:
            return false;
        }
    }
}
