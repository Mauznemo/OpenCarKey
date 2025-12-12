#pragma once
#include <stdint.h>

/// @brief Features supported by the vehicle
enum Feature : uint32_t
{
    None = 0,
    DoorsLock = 1 << 0,
    TrunkOpen = 1 << 1,
    Engine = 1 << 2,
    Windows = 1 << 3,
};

// Allow bitwise operators for the enum
inline Feature operator|(Feature a, Feature b)
{
    return static_cast<Feature>(static_cast<uint32_t>(a) | static_cast<uint32_t>(b));
}

inline Feature operator&(Feature a, Feature b)
{
    return static_cast<Feature>(static_cast<uint32_t>(a) & static_cast<uint32_t>(b));
}
