#pragma once

#include <stddef.h>

namespace ock
{
    /// @brief Shortest PASSWORD the firmware builds with. Anyone in BLE range can record a
    /// message and try to guess the password offline, so short ones can be cracked.
    /// Keep in sync with minPasswordLength in the app (MobileApp/lib/utils/rolling_code.dart).
    constexpr size_t MIN_PASSWORD_LENGTH = 12;

    constexpr size_t constStrLen(const char *s)
    {
        return *s == '\0' ? 0 : 1 + constStrLen(s + 1);
    }

    constexpr bool isPasswordLongEnough(const char *password)
    {
        return constStrLen(password) >= MIN_PASSWORD_LENGTH;
    }
}
