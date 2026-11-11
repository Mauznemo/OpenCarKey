#pragma once

#include <stddef.h>
#include <stdint.h>
#include "OckProtocol.h"

namespace ock
{
    /// @brief Computes HMAC-SHA256 of `message` with `key` into `out` (32 bytes)
    /// @return false if the HMAC could not be calculated
    typedef bool (*HmacSha256Fn)(const uint8_t *key, size_t keyLength,
                                 const uint8_t *message, size_t messageLength,
                                 uint8_t *out);

    /// @brief A client message split into its parts. Pointers point into the raw buffer.
    struct ClientMessage
    {
        const uint8_t *hmac;
        uint8_t command;
        const uint8_t *data;
        uint8_t dataLength;
    };

    /// @brief Splits a raw client message: 32 byte HMAC + 1 byte command (+ 1 byte data length + data).
    /// @return false if the message is malformed (wrong size, length byte not matching, too much data)
    bool parseClientMessage(const uint8_t *buffer, size_t length, ClientMessage &out);

    /// @brief Writes the bytes the HMAC is calculated over:
    /// counter (uint32 little endian) + command, plus data length + data if the message has data.
    /// So the additional data can't be swapped out without breaking the HMAC.
    /// @param out Needs room for MAX_HMAC_INPUT_SIZE bytes
    /// @return Number of bytes written
    size_t buildHmacInput(uint32_t counter, const ClientMessage &message, uint8_t *out);

    /// @brief Compares two buffers in constant time (doesn't stop at the first mismatch)
    bool constantTimeEquals(const uint8_t *a, const uint8_t *b, size_t length);

    /// @brief Persistent storage for the rolling code counter
    class CounterStore
    {
    public:
        virtual ~CounterStore() {}
        /// @brief Loads the counter. A counter that was never saved loads as 0.
        /// @return false if the storage could not be read
        virtual bool load(uint32_t &counter) = 0;
        /// @return false if the counter could not be saved
        virtual bool save(uint32_t counter) = 0;
    };

    enum class AuthResult
    {
        Ok,
        /// @brief The counter could not be loaded, every message is refused
        NotReady,
        InvalidHmac,
        /// @brief The HMAC was valid but the new counter could not be saved, so the command must not run
        StorageError,
        /// @brief The counter reached its maximum value, change the password
        CounterExhausted,
    };

    /// @brief Checks the HMAC and rolling code counter of client messages.
    ///
    /// A message is accepted if its HMAC matches any counter from the current one up to
    /// WINDOW - 1 ahead. The counter then moves past the matched one, so every counter
    /// (and therefore every message) can only be used once and older ones stay rejected.
    class RollingCodeVerifier
    {
    public:
        /// @brief How many counters ahead of the stored one are still accepted.
        /// The app skips counters when a write fails locally, this absorbs that.
        static const uint32_t WINDOW = 64;

        RollingCodeVerifier(HmacSha256Fn hmac, CounterStore &store);

        /// @brief Sets the 32 byte shared secret
        void setKey(const uint8_t *key);

        /// @brief Loads the counter from the store. Until this succeeded every message is refused.
        bool begin();

        /// @brief Verifies the message and, if valid, moves the counter past it and saves it.
        /// Only run the command if this returns AuthResult::Ok.
        AuthResult authenticate(const ClientMessage &message);

        /// @brief Sets the counter back to 0 (for when the app and controller got out of sync).
        /// Messages recorded before the reset become valid again, so only do this when needed.
        /// @return false if it could not be saved, every message is refused then
        bool resetCounter();

        uint32_t counter() const { return counter_; }
        bool ready() const { return ready_; }

    private:
        HmacSha256Fn hmac_;
        CounterStore &store_;
        uint8_t key_[HMAC_SIZE];
        uint32_t counter_;
        bool ready_;
    };
}
