#include "OckProtocol.h"

namespace ock
{
    bool isKnownCommand(uint8_t command)
    {
        return command <= static_cast<uint8_t>(ClientCommand::CLOSE_WINDOWS);
    }

    Feature requiredFeature(ClientCommand command)
    {
        switch (command)
        {
        case ClientCommand::LOCK_DOORS:
        case ClientCommand::UNLOCK_DOORS:
        // The proximity key locks and unlocks the doors
        case ClientCommand::PROXIMITY_KEY_ON:
            return Feature::DoorsLock;
        case ClientCommand::OPEN_TRUNK:
            return Feature::TrunkOpen;
        case ClientCommand::START_ENGINE:
        case ClientCommand::STOP_ENGINE:
            return Feature::Engine;
        case ClientCommand::OPEN_WINDOWS:
        case ClientCommand::CLOSE_WINDOWS:
            return Feature::Windows;
        default:
            return Feature::None;
        }
    }

    size_t expectedDataLength(ClientCommand command)
    {
        switch (command)
        {
        case ClientCommand::PROXIMITY_COOLDOWN:
            return sizeof(float);
        case ClientCommand::RSSI_TRIGGER:
            return 2 * sizeof(float);
        default:
            return 0;
        }
    }
}
