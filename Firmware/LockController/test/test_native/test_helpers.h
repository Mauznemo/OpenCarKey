#pragma once

#include <stdint.h>
#include <string.h>
#include <string>
#include <vector>

#include <OckAuth.h>
#include "ref_sha256.h"

/// Counter store in RAM that can be told to fail, to test what happens when flash breaks
class MemoryCounterStore : public ock::CounterStore
{
public:
    uint32_t value = 0;
    bool failLoad = false;
    bool failSave = false;
    int saves = 0;

    bool load(uint32_t &counter) override
    {
        if (failLoad)
            return false;
        counter = value;
        return true;
    }

    bool save(uint32_t counter) override
    {
        if (failSave)
            return false;
        value = counter;
        saves++;
        return true;
    }
};

inline std::vector<uint8_t> fromHex(const std::string &hex)
{
    std::vector<uint8_t> bytes;
    for (size_t i = 0; i + 1 < hex.size(); i += 2)
        bytes.push_back((uint8_t)strtoul(hex.substr(i, 2).c_str(), nullptr, 16));
    return bytes;
}

/// Key the firmware derives from a PASSWORD: SHA-256 of the password
inline std::vector<uint8_t> keyFromPassword(const char *password)
{
    std::vector<uint8_t> key(32);
    refSha256((const uint8_t *)password, strlen(password), key.data());
    return key;
}

/// Builds a message exactly like the app does (MobileApp/lib/utils/rolling_code.dart)
inline std::vector<uint8_t> buildMessage(const std::vector<uint8_t> &key, uint32_t counter, uint8_t command,
                                         const std::vector<uint8_t> &data = std::vector<uint8_t>())
{
    std::vector<uint8_t> input;
    for (int i = 0; i < 4; i++)
        input.push_back((uint8_t)(counter >> (8 * i)));
    input.push_back(command);
    if (!data.empty())
    {
        input.push_back((uint8_t)data.size());
        input.insert(input.end(), data.begin(), data.end());
    }

    std::vector<uint8_t> message(32);
    refHmacSha256(key.data(), key.size(), input.data(), input.size(), message.data());
    message.push_back(command);
    if (!data.empty())
    {
        message.push_back((uint8_t)data.size());
        message.insert(message.end(), data.begin(), data.end());
    }
    return message;
}

inline std::vector<uint8_t> buildMessage(const std::vector<uint8_t> &key, uint32_t counter, ClientCommand command,
                                         const std::vector<uint8_t> &data = std::vector<uint8_t>())
{
    return buildMessage(key, counter, static_cast<uint8_t>(command), data);
}

inline std::vector<uint8_t> floatBytes(float a)
{
    std::vector<uint8_t> bytes(4);
    memcpy(bytes.data(), &a, 4);
    return bytes;
}

inline std::vector<uint8_t> floatBytes(float a, float b)
{
    std::vector<uint8_t> bytes = floatBytes(a);
    std::vector<uint8_t> second = floatBytes(b);
    bytes.insert(bytes.end(), second.begin(), second.end());
    return bytes;
}

/// A verifier that is ready to use, with the key from `password` and the counter at `counter`
struct VerifierFixture
{
    MemoryCounterStore store;
    ock::RollingCodeVerifier verifier;
    std::vector<uint8_t> key;

    explicit VerifierFixture(uint32_t counter = 0, const char *password = "test-password-123")
        : verifier(refHmacSha256, store), key(keyFromPassword(password))
    {
        store.value = counter;
        verifier.setKey(key.data());
        verifier.begin();
    }
};
