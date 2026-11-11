#include "OckProximity.h"

#include <cmath>

namespace ock
{
    bool isValidRssiTrigger(float triggerRssi, float deadZone)
    {
        return std::isfinite(triggerRssi) && std::isfinite(deadZone) &&
               triggerRssi >= MIN_TRIGGER_RSSI && triggerRssi <= MAX_TRIGGER_RSSI &&
               deadZone >= 0.0f && deadZone <= MAX_DEAD_ZONE;
    }

    bool isValidProximityCooldown(float minutes)
    {
        return std::isfinite(minutes) && minutes >= 0.0f && minutes <= MAX_PROXIMITY_COOLDOWN_MIN;
    }

    float calculateReleaseRssi(float triggerRssi)
    {
        const float pathLossExponent = 3.0f;
        const float reduction = 5.0f;
        const float deltaRssi = -10.0f * pathLossExponent * std::log10(reduction + 1.0f);
        return triggerRssi + deltaRssi;
    }

    bool proximityCooldownActive(unsigned long nowMillis, unsigned long lastActionMillis, float cooldownMinutes)
    {
        if (lastActionMillis == 0 || !(cooldownMinutes > 0.0f))
            return false;

        // Unsigned subtraction keeps working when millis() wraps around
        const unsigned long elapsed = nowMillis - lastActionMillis;
        return static_cast<double>(elapsed) < static_cast<double>(cooldownMinutes) * 60000.0;
    }

    void RssiFilter::reset()
    {
        for (size_t i = 0; i < SAMPLES; i++)
            samples_[i] = 0;
        index_ = 0;
        count_ = 0;
    }

    void RssiFilter::add(int rssi)
    {
        samples_[index_] = rssi;
        index_ = (index_ + 1) % SAMPLES;
        if (count_ < SAMPLES)
            count_++;
    }

    float RssiFilter::average() const
    {
        if (count_ == 0)
            return 0.0f;

        long sum = 0;
        for (size_t i = 0; i < count_; i++)
            sum += samples_[i];
        return static_cast<float>(sum) / static_cast<float>(count_);
    }

    ProximityAction evaluateProximity(bool proximityKeyEnabled, float triggerRssi, float releaseRssi,
                                      const RssiFilter &filter, bool isLocked)
    {
        if (!proximityKeyEnabled || triggerRssi == 0.0f || !filter.full())
            return ProximityAction::None;

        const float average = filter.average();

        if (average < releaseRssi)
            return isLocked ? ProximityAction::None : ProximityAction::Lock;
        if (average > triggerRssi)
            return isLocked ? ProximityAction::Unlock : ProximityAction::None;
        return ProximityAction::None;
    }
}
