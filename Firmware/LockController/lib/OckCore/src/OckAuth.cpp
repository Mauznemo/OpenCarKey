#include "OckAuth.h"

#include <string.h>

namespace ock
{
    bool parseClientMessage(const uint8_t *buffer, size_t length, ClientMessage &out)
    {
        if (buffer == nullptr || length < MIN_MESSAGE_SIZE)
            return false;

        out.hmac = buffer;
        out.command = buffer[HMAC_SIZE];
        out.data = nullptr;
        out.dataLength = 0;

        if (length == MIN_MESSAGE_SIZE)
            return true;

        // A message with data has to be exactly HMAC + command + length byte + data.
        // A length byte of 0 is not allowed, a message without data simply has no length byte.
        const uint8_t dataLength = buffer[MIN_MESSAGE_SIZE];
        if (dataLength == 0 || dataLength > MAX_DATA_LENGTH)
            return false;
        if (length != MIN_MESSAGE_SIZE + 1 + dataLength)
            return false;

        out.data = buffer + MIN_MESSAGE_SIZE + 1;
        out.dataLength = dataLength;
        return true;
    }

    size_t buildHmacInput(uint32_t counter, const ClientMessage &message, uint8_t *out)
    {
        size_t length = 0;
        out[length++] = static_cast<uint8_t>(counter);
        out[length++] = static_cast<uint8_t>(counter >> 8);
        out[length++] = static_cast<uint8_t>(counter >> 16);
        out[length++] = static_cast<uint8_t>(counter >> 24);
        out[length++] = message.command;

        if (message.dataLength > 0)
        {
            out[length++] = message.dataLength;
            memcpy(out + length, message.data, message.dataLength);
            length += message.dataLength;
        }

        return length;
    }

    bool constantTimeEquals(const uint8_t *a, const uint8_t *b, size_t length)
    {
        uint8_t diff = 0;
        for (size_t i = 0; i < length; i++)
            diff |= a[i] ^ b[i];
        return diff == 0;
    }

    RollingCodeVerifier::RollingCodeVerifier(HmacSha256Fn hmac, CounterStore &store)
        : hmac_(hmac), store_(store), counter_(0), ready_(false)
    {
        memset(key_, 0, sizeof(key_));
    }

    void RollingCodeVerifier::setKey(const uint8_t *key)
    {
        memcpy(key_, key, sizeof(key_));
    }

    bool RollingCodeVerifier::begin()
    {
        uint32_t loaded = 0;
        ready_ = store_.load(loaded);
        counter_ = ready_ ? loaded : 0;
        return ready_;
    }

    AuthResult RollingCodeVerifier::authenticate(const ClientMessage &message)
    {
        if (!ready_)
            return AuthResult::NotReady;

        if (message.dataLength > MAX_DATA_LENGTH || (message.dataLength > 0 && message.data == nullptr))
            return AuthResult::InvalidHmac;

        uint8_t input[MAX_HMAC_INPUT_SIZE];
        uint8_t expected[HMAC_SIZE];

        for (uint32_t i = 0; i < WINDOW; i++)
        {
            // The counter after this one has to fit too, it must never wrap back to 0
            if (counter_ > UINT32_MAX - 1 - i)
                return AuthResult::CounterExhausted;

            const uint32_t candidate = counter_ + i;
            const size_t inputLength = buildHmacInput(candidate, message, input);
            if (!hmac_(key_, sizeof(key_), input, inputLength, expected))
                return AuthResult::InvalidHmac;

            if (!constantTimeEquals(expected, message.hmac, HMAC_SIZE))
                continue;

            // Move past the counter in RAM first, so the same message can't be used again
            // even if saving fails. If saving fails the command is not run.
            counter_ = candidate + 1;
            if (!store_.save(counter_))
                return AuthResult::StorageError;
            return AuthResult::Ok;
        }

        return AuthResult::InvalidHmac;
    }

    bool RollingCodeVerifier::resetCounter()
    {
        counter_ = 0;
        ready_ = store_.save(counter_);
        return ready_;
    }
}
