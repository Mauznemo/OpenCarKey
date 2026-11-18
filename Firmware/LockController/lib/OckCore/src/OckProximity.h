#pragma once

#include <stddef.h>
#include <stdint.h>

namespace ock
{
    /// @brief Trigger RSSI the app sends when no range is calibrated: unlock on connect, lock on disconnect
    constexpr float CONNECT_RANGE_TRIGGER_RSSI = -200.0f;
    constexpr float MIN_TRIGGER_RSSI = CONNECT_RANGE_TRIGGER_RSSI;
    /// @brief 0 turns RSSI based locking and unlocking off
    constexpr float MAX_TRIGGER_RSSI = 0.0f;
    constexpr float MAX_DEAD_ZONE = 100.0f;
    constexpr float MAX_PROXIMITY_COOLDOWN_MIN = 60.0f;
    /// @brief Range a BLE RSSI reading can actually have, in dBm (HCI uses 127 for "not available")
    constexpr int MIN_RSSI_READING = -127;
    constexpr int MAX_RSSI_READING = 20;

    /// @brief True if `rssi` is a real reading and not "not available" or garbage from a failed read
    bool isValidRssiReading(int rssi);

    /// @brief True if the RSSI_TRIGGER values are finite and in a sane range
    bool isValidRssiTrigger(float triggerRssi, float deadZone);

    /// @brief True if the PROXIMITY_COOLDOWN value is finite and in a sane range
    bool isValidProximityCooldown(float minutes);

    /// @brief RSSI below which the proximity key locks again, always weaker than the trigger
    float calculateReleaseRssi(float triggerRssi);

    /// @brief True if the last proximity lock/unlock was less than `cooldownMinutes` ago
    /// @param lastActionMillis millis() of the last proximity action, 0 if there was none yet
    bool proximityCooldownActive(unsigned long nowMillis, unsigned long lastActionMillis, float cooldownMinutes);

    /// @brief Moving average over the last SAMPLES RSSI readings of the current connection
    class RssiFilter
    {
    public:
        static const size_t SAMPLES = 5;

        RssiFilter() { reset(); }

        /// @brief Forgets all readings, call it whenever the readings could be stale (new connection etc.)
        void reset();
        /// @brief Adds a reading. Readings outside the possible range (see isValidRssiReading) are
        /// ignored, they would pull the average up and could unlock the car.
        /// @return false if the reading was ignored
        bool add(int rssi);
        /// @brief True once SAMPLES readings were added since the last reset
        bool full() const { return count_ >= SAMPLES; }
        size_t count() const { return count_; }
        /// @brief Average of the readings so far (0 if there are none)
        float average() const;

    private:
        int samples_[SAMPLES];
        size_t index_;
        size_t count_;
    };

    enum class ProximityAction
    {
        None,
        Lock,
        Unlock,
    };

    /// @brief Decides if the proximity key should lock or unlock.
    /// Nothing happens until the filter is full, so a decision is never based on stale or too few readings.
    ProximityAction evaluateProximity(bool proximityKeyEnabled, float triggerRssi, float releaseRssi,
                                      const RssiFilter &filter, bool isLocked);
}
