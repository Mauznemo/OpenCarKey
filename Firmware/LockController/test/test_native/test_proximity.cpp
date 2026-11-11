// Proximity key decisions: when the car may lock or unlock on its own.

#include <unity.h>
#include <cmath>
#include <climits>
#include <limits>
#include <OckProximity.h>

namespace
{
    ock::RssiFilter filled(int rssi)
    {
        ock::RssiFilter filter;
        for (size_t i = 0; i < ock::RssiFilter::SAMPLES; i++)
            filter.add(rssi);
        return filter;
    }

    void test_filter_needs_all_samples()
    {
        ock::RssiFilter filter;
        TEST_ASSERT_FALSE(filter.full());
        TEST_ASSERT_EQUAL_FLOAT(0.0f, filter.average());
        for (size_t i = 0; i < ock::RssiFilter::SAMPLES - 1; i++)
        {
            filter.add(-50);
            TEST_ASSERT_FALSE(filter.full());
        }
        filter.add(-50);
        TEST_ASSERT_TRUE(filter.full());
        TEST_ASSERT_EQUAL_FLOAT(-50.0f, filter.average());
    }

    void test_filter_averages_last_samples()
    {
        ock::RssiFilter filter;
        filter.add(-40);
        filter.add(-60);
        TEST_ASSERT_EQUAL_FLOAT(-50.0f, filter.average());

        // Older readings drop out once more than SAMPLES were added
        filter = filled(-40);
        for (size_t i = 0; i < ock::RssiFilter::SAMPLES; i++)
            filter.add(-90);
        TEST_ASSERT_EQUAL_FLOAT(-90.0f, filter.average());
    }

    void test_filter_reset_forgets_everything()
    {
        ock::RssiFilter filter = filled(-40);
        filter.reset();
        TEST_ASSERT_FALSE(filter.full());
        TEST_ASSERT_EQUAL(0, filter.count());
        filter.add(-90);
        TEST_ASSERT_EQUAL_FLOAT(-90.0f, filter.average());
    }

    void test_stale_close_readings_dont_unlock_after_reconnect()
    {
        // Phone was right next to the car, then the connection dropped. Later it reconnects
        // from far away. The old "close" readings must not be mixed into the new ones.
        const float trigger = -60.0f;
        const float release = ock::calculateReleaseRssi(trigger);

        ock::RssiFilter filter = filled(-40);
        filter.reset(); // what onConnect / onDisconnect / PROXIMITY_KEY_ON do

        for (size_t i = 0; i < ock::RssiFilter::SAMPLES; i++)
        {
            filter.add(-95);
            TEST_ASSERT_NOT_EQUAL(ock::ProximityAction::Unlock,
                                  ock::evaluateProximity(true, trigger, release, filter, true));
        }
    }

    void test_no_action_until_filter_full()
    {
        ock::RssiFilter filter;
        filter.add(-30);
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(true, -60.0f, -83.0f, filter, true));
        filter.add(-100);
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(true, -60.0f, -83.0f, filter, false));
    }

    void test_no_action_when_disabled()
    {
        ock::RssiFilter close = filled(-30);
        ock::RssiFilter far = filled(-100);
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(false, -60.0f, -83.0f, close, true));
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(false, -60.0f, -83.0f, far, false));
        // A trigger of 0 means no range was ever sent
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(true, 0.0f, 0.0f, close, true));
    }

    void test_unlock_and_lock_thresholds()
    {
        const float trigger = -60.0f;
        const float release = ock::calculateReleaseRssi(trigger);

        TEST_ASSERT_EQUAL(ock::ProximityAction::Unlock, ock::evaluateProximity(true, trigger, release, filled(-50), true));
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(true, trigger, release, filled(-50), false));

        TEST_ASSERT_EQUAL(ock::ProximityAction::Lock, ock::evaluateProximity(true, trigger, release, filled(-95), false));
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(true, trigger, release, filled(-95), true));

        // Between release and trigger (dead zone) nothing happens
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(true, trigger, release, filled(-70), true));
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(true, trigger, release, filled(-70), false));

        // Exactly at the trigger is not closer than the trigger
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(true, trigger, release, filled(-60), true));
    }

    void test_release_is_always_weaker_than_trigger()
    {
        for (float trigger = -200.0f; trigger <= 0.0f; trigger += 1.0f)
            TEST_ASSERT_TRUE(ock::calculateReleaseRssi(trigger) < trigger - 20.0f);
    }

    void test_connect_range_mode()
    {
        // No calibrated range: unlock as soon as connected (readings are full), lock on disconnect
        const float trigger = ock::CONNECT_RANGE_TRIGGER_RSSI;
        const float release = ock::calculateReleaseRssi(trigger);
        TEST_ASSERT_EQUAL(ock::ProximityAction::Unlock, ock::evaluateProximity(true, trigger, release, filled(-100), true));
        TEST_ASSERT_EQUAL(ock::ProximityAction::None, ock::evaluateProximity(true, trigger, release, filled(-127), false));
    }

    void test_cooldown()
    {
        // Nothing happened yet
        TEST_ASSERT_FALSE(ock::proximityCooldownActive(1000, 0, 1.0f));
        // 1 min cooldown
        TEST_ASSERT_TRUE(ock::proximityCooldownActive(1000 + 59999, 1000, 1.0f));
        TEST_ASSERT_FALSE(ock::proximityCooldownActive(1000 + 60000, 1000, 1.0f));
        // Turned off
        TEST_ASSERT_FALSE(ock::proximityCooldownActive(1001, 1000, 0.0f));
        // Garbage never blocks forever
        TEST_ASSERT_FALSE(ock::proximityCooldownActive(1001, 1000, -1.0f));
        TEST_ASSERT_FALSE(ock::proximityCooldownActive(1001, 1000, std::numeric_limits<float>::quiet_NaN()));
    }

    void test_cooldown_survives_millis_wrap()
    {
        const unsigned long last = ULONG_MAX - 1000;
        TEST_ASSERT_TRUE(ock::proximityCooldownActive(1000, last, 1.0f));
        TEST_ASSERT_FALSE(ock::proximityCooldownActive(70000, last, 1.0f));
    }

    void test_validation_ranges()
    {
        const float nan = std::numeric_limits<float>::quiet_NaN();
        const float inf = std::numeric_limits<float>::infinity();

        TEST_ASSERT_TRUE(ock::isValidRssiTrigger(-60.0f, 4.0f));
        TEST_ASSERT_TRUE(ock::isValidRssiTrigger(-200.0f, 0.0f));
        TEST_ASSERT_TRUE(ock::isValidRssiTrigger(0.0f, 100.0f));
        TEST_ASSERT_FALSE(ock::isValidRssiTrigger(-200.5f, 4.0f));
        TEST_ASSERT_FALSE(ock::isValidRssiTrigger(0.1f, 4.0f));
        TEST_ASSERT_FALSE(ock::isValidRssiTrigger(nan, 4.0f));
        TEST_ASSERT_FALSE(ock::isValidRssiTrigger(-60.0f, nan));
        TEST_ASSERT_FALSE(ock::isValidRssiTrigger(-inf, 4.0f));
        TEST_ASSERT_FALSE(ock::isValidRssiTrigger(-60.0f, -0.5f));
        TEST_ASSERT_FALSE(ock::isValidRssiTrigger(-60.0f, 100.5f));

        TEST_ASSERT_TRUE(ock::isValidProximityCooldown(0.0f));
        TEST_ASSERT_TRUE(ock::isValidProximityCooldown(5.0f));
        TEST_ASSERT_TRUE(ock::isValidProximityCooldown(60.0f));
        TEST_ASSERT_FALSE(ock::isValidProximityCooldown(-0.5f));
        TEST_ASSERT_FALSE(ock::isValidProximityCooldown(60.5f));
        TEST_ASSERT_FALSE(ock::isValidProximityCooldown(nan));
        TEST_ASSERT_FALSE(ock::isValidProximityCooldown(inf));
    }
}

void runProximityTests()
{
    RUN_TEST(test_filter_needs_all_samples);
    RUN_TEST(test_filter_averages_last_samples);
    RUN_TEST(test_filter_reset_forgets_everything);
    RUN_TEST(test_stale_close_readings_dont_unlock_after_reconnect);
    RUN_TEST(test_no_action_until_filter_full);
    RUN_TEST(test_no_action_when_disabled);
    RUN_TEST(test_unlock_and_lock_thresholds);
    RUN_TEST(test_release_is_always_weaker_than_trigger);
    RUN_TEST(test_connect_range_mode);
    RUN_TEST(test_cooldown);
    RUN_TEST(test_cooldown_survives_millis_wrap);
    RUN_TEST(test_validation_ranges);
}
