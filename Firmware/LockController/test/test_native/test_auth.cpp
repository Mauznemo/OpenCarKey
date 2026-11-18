// HMAC and rolling code checks: replays, tampering, counter window, storage failures.

#include <unity.h>
#include <OckAuth.h>
#include "test_helpers.h"

namespace
{
    ock::AuthResult authenticate(VerifierFixture &fixture, const std::vector<uint8_t> &payload)
    {
        ock::ClientMessage message;
        TEST_ASSERT_TRUE(ock::parseClientMessage(payload.data(), payload.size(), message));
        return fixture.verifier.authenticate(message);
    }

    void test_accepts_current_counter_and_saves_next()
    {
        VerifierFixture fixture(5);
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildMessage(fixture.key, 5, ClientCommand::UNLOCK_DOORS)));
        TEST_ASSERT_EQUAL_UINT32(6, fixture.verifier.counter());
        TEST_ASSERT_EQUAL_UINT32(6, fixture.store.value);
    }

    void test_replay_is_rejected()
    {
        VerifierFixture fixture;
        std::vector<uint8_t> unlock = buildMessage(fixture.key, 0, ClientCommand::UNLOCK_DOORS);
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok, authenticate(fixture, unlock));
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, unlock));
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, unlock));
        TEST_ASSERT_EQUAL_UINT32(1, fixture.verifier.counter());
    }

    void test_replay_is_rejected_after_reboot()
    {
        VerifierFixture fixture;
        std::vector<uint8_t> unlock = buildMessage(fixture.key, 0, ClientCommand::UNLOCK_DOORS);
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok, authenticate(fixture, unlock));

        // Same flash, fresh RAM. Even with the same nonce the stored counter has to reject it.
        ock::RollingCodeVerifier rebooted(refHmacSha256, fixture.store);
        rebooted.setKey(fixture.key.data());
        TEST_ASSERT_TRUE(rebooted.begin());
        rebooted.beginSession(testNonce().data());
        ock::ClientMessage message;
        TEST_ASSERT_TRUE(ock::parseClientMessage(unlock.data(), unlock.size(), message));
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, rebooted.authenticate(message));
    }

    void test_older_counters_are_rejected()
    {
        VerifierFixture fixture(100);
        for (uint32_t counter = 0; counter < 100; counter++)
            TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac,
                              authenticate(fixture, buildMessage(fixture.key, counter, ClientCommand::UNLOCK_DOORS)));
        TEST_ASSERT_EQUAL_UINT32(100, fixture.verifier.counter());
        TEST_ASSERT_EQUAL(0, fixture.store.saves);
    }

    void test_window_edges()
    {
        const uint32_t window = ock::RollingCodeVerifier::WINDOW;

        VerifierFixture inside(10);
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(inside, buildMessage(inside.key, 10 + window - 1, ClientCommand::LOCK_DOORS)));
        TEST_ASSERT_EQUAL_UINT32(10 + window, inside.verifier.counter());

        VerifierFixture outside(10);
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac,
                          authenticate(outside, buildMessage(outside.key, 10 + window, ClientCommand::LOCK_DOORS)));
        TEST_ASSERT_EQUAL_UINT32(10, outside.verifier.counter());
    }

    void test_skipped_counters_cant_be_used_later()
    {
        // The app skips counters when a write fails. A message that was skipped (and maybe
        // captured by someone) must be dead once a newer counter went through.
        VerifierFixture fixture;
        std::vector<uint8_t> captured = buildMessage(fixture.key, 3, ClientCommand::UNLOCK_DOORS);
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildMessage(fixture.key, 4, ClientCommand::LOCK_DOORS)));
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, captured));
    }

    void test_wrong_password_is_rejected()
    {
        VerifierFixture fixture;
        std::vector<uint8_t> otherKey = keyFromPassword("another-password-456");
        for (uint32_t counter = 0; counter < 3; counter++)
            TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac,
                              authenticate(fixture, buildMessage(otherKey, counter, ClientCommand::UNLOCK_DOORS)));
    }

    void test_changed_command_byte_is_rejected()
    {
        VerifierFixture fixture;
        std::vector<uint8_t> payload = buildMessage(fixture.key, 0, ClientCommand::LOCK_DOORS);
        payload[32] = static_cast<uint8_t>(ClientCommand::UNLOCK_DOORS);
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, payload));
    }

    void test_changed_data_is_rejected()
    {
        // Someone intercepting a valid RSSI_TRIGGER must not be able to set their own range
        VerifierFixture fixture;
        std::vector<uint8_t> payload =
            buildMessage(fixture.key, 0, ClientCommand::RSSI_TRIGGER, floatBytes(-60.0f, 4.0f));
        std::vector<uint8_t> evil = floatBytes(-200.0f, 4.0f);
        std::copy(evil.begin(), evil.end(), payload.begin() + 34);
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, payload));
    }

    void test_added_or_removed_data_is_rejected()
    {
        VerifierFixture fixture;

        std::vector<uint8_t> added = buildMessage(fixture.key, 0, ClientCommand::PROXIMITY_COOLDOWN);
        added.push_back(4);
        std::vector<uint8_t> value = floatBytes(-5.0f);
        added.insert(added.end(), value.begin(), value.end());
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, added));

        std::vector<uint8_t> removed = buildMessage(fixture.key, 0, ClientCommand::PROXIMITY_COOLDOWN, floatBytes(1.0f));
        removed.resize(33);
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, removed));

        TEST_ASSERT_EQUAL_UINT32(0, fixture.verifier.counter());
    }

    void test_every_bit_flip_in_hmac_is_rejected()
    {
        VerifierFixture fixture;
        const std::vector<uint8_t> valid = buildMessage(fixture.key, 0, ClientCommand::UNLOCK_DOORS);
        for (size_t bit = 0; bit < 32 * 8; bit++)
        {
            std::vector<uint8_t> flipped = valid;
            flipped[bit / 8] ^= (uint8_t)(1 << (bit % 8));
            TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, flipped));
        }
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok, authenticate(fixture, valid));
    }

    void test_all_zero_hmac_is_rejected()
    {
        VerifierFixture fixture;
        std::vector<uint8_t> zeros(33, 0);
        zeros[32] = static_cast<uint8_t>(ClientCommand::UNLOCK_DOORS);
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, zeros));
    }

    bool failingHmac(const uint8_t *, size_t, const uint8_t *, size_t, uint8_t *out)
    {
        memset(out, 0, 32);
        return false;
    }

    void test_failing_hmac_function_never_matches()
    {
        // If the crypto library fails, its (zeroed) output must not count as a match
        MemoryCounterStore store;
        ock::RollingCodeVerifier verifier(failingHmac, store);
        verifier.begin();
        verifier.beginSession(testNonce().data());
        std::vector<uint8_t> zeros(33, 0);
        ock::ClientMessage message;
        TEST_ASSERT_TRUE(ock::parseClientMessage(zeros.data(), zeros.size(), message));
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, verifier.authenticate(message));
    }

    void test_refuses_everything_if_counter_cant_be_loaded()
    {
        // A counter that silently starts at 0 would make every recorded message valid again
        MemoryCounterStore store;
        store.failLoad = true;
        ock::RollingCodeVerifier verifier(refHmacSha256, store);
        std::vector<uint8_t> key = keyFromPassword("test-password-123");
        verifier.setKey(key.data());
        TEST_ASSERT_FALSE(verifier.begin());
        TEST_ASSERT_FALSE(verifier.ready());

        std::vector<uint8_t> payload = buildMessage(key, 0, ClientCommand::UNLOCK_DOORS);
        ock::ClientMessage message;
        TEST_ASSERT_TRUE(ock::parseClientMessage(payload.data(), payload.size(), message));
        TEST_ASSERT_EQUAL(ock::AuthResult::NotReady, verifier.authenticate(message));
    }

    void test_not_ready_before_begin()
    {
        MemoryCounterStore store;
        ock::RollingCodeVerifier verifier(refHmacSha256, store);
        std::vector<uint8_t> key = keyFromPassword("test-password-123");
        verifier.setKey(key.data());

        std::vector<uint8_t> payload = buildMessage(key, 0, ClientCommand::UNLOCK_DOORS);
        ock::ClientMessage message;
        TEST_ASSERT_TRUE(ock::parseClientMessage(payload.data(), payload.size(), message));
        TEST_ASSERT_EQUAL(ock::AuthResult::NotReady, verifier.authenticate(message));
    }

    void test_save_failure_blocks_command_and_message_reuse()
    {
        VerifierFixture fixture;
        fixture.store.failSave = true;
        std::vector<uint8_t> unlock = buildMessage(fixture.key, 0, ClientCommand::UNLOCK_DOORS);
        TEST_ASSERT_EQUAL(ock::AuthResult::StorageError, authenticate(fixture, unlock));

        // Even once saving works again, the same message stays used up
        fixture.store.failSave = false;
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, unlock));
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildMessage(fixture.key, 1, ClientCommand::UNLOCK_DOORS)));
    }

    void test_counter_never_wraps_to_zero()
    {
        VerifierFixture fixture(UINT32_MAX - 1);
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildMessage(fixture.key, UINT32_MAX - 1, ClientCommand::LOCK_DOORS)));
        TEST_ASSERT_EQUAL_UINT32(UINT32_MAX, fixture.verifier.counter());

        TEST_ASSERT_EQUAL(ock::AuthResult::CounterExhausted,
                          authenticate(fixture, buildMessage(fixture.key, UINT32_MAX, ClientCommand::LOCK_DOORS)));
        TEST_ASSERT_EQUAL(ock::AuthResult::CounterExhausted,
                          authenticate(fixture, buildMessage(fixture.key, 0, ClientCommand::UNLOCK_DOORS)));
        TEST_ASSERT_EQUAL_UINT32(UINT32_MAX, fixture.verifier.counter());
    }

    void test_window_stops_before_counter_overflow()
    {
        // Close to the end only the counters that still have a successor are tried
        VerifierFixture fixture(UINT32_MAX - 3);
        TEST_ASSERT_EQUAL(ock::AuthResult::CounterExhausted,
                          authenticate(fixture, buildMessage(fixture.key, 2, ClientCommand::UNLOCK_DOORS)));
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildMessage(fixture.key, UINT32_MAX - 2, ClientCommand::LOCK_DOORS)));
    }

    void test_begin_loads_stored_counter()
    {
        VerifierFixture fixture(500);
        TEST_ASSERT_TRUE(fixture.verifier.ready());
        TEST_ASSERT_EQUAL_UINT32(500, fixture.verifier.counter());
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac,
                          authenticate(fixture, buildMessage(fixture.key, 499, ClientCommand::UNLOCK_DOORS)));
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildMessage(fixture.key, 500, ClientCommand::UNLOCK_DOORS)));
    }

    void test_reset_counter()
    {
        VerifierFixture fixture(500);
        TEST_ASSERT_TRUE(fixture.verifier.resetCounter());
        TEST_ASSERT_EQUAL_UINT32(0, fixture.verifier.counter());
        TEST_ASSERT_EQUAL_UINT32(0, fixture.store.value);
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildMessage(fixture.key, 0, ClientCommand::UNLOCK_DOORS)));
    }

    void test_failed_reset_refuses_everything()
    {
        // RAM and flash would disagree otherwise, and a reboot would bring old counters back
        VerifierFixture fixture(500);
        fixture.store.failSave = true;
        TEST_ASSERT_FALSE(fixture.verifier.resetCounter());
        TEST_ASSERT_FALSE(fixture.verifier.ready());
        TEST_ASSERT_EQUAL(ock::AuthResult::NotReady,
                          authenticate(fixture, buildMessage(fixture.key, 0, ClientCommand::UNLOCK_DOORS)));
    }

    void test_message_for_another_session_is_rejected()
    {
        // What a fake vehicle collects from the app is made for its own nonce
        VerifierFixture fixture(5);
        for (uint32_t counter = 5; counter < 5 + ock::RollingCodeVerifier::WINDOW; counter++)
            TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac,
                              authenticate(fixture, buildSessionMessage(otherNonce(), fixture.key, counter,
                                                                        ClientCommand::UNLOCK_DOORS)));
        TEST_ASSERT_EQUAL_UINT32(5, fixture.verifier.counter());
        TEST_ASSERT_EQUAL(0, fixture.store.saves);

        // The right session still works with the counter that was not used up
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildMessage(fixture.key, 5, ClientCommand::UNLOCK_DOORS)));
    }

    void test_nothing_accepted_without_session()
    {
        MemoryCounterStore store;
        ock::RollingCodeVerifier verifier(refHmacSha256, store);
        std::vector<uint8_t> key = keyFromPassword("test-password-123");
        verifier.setKey(key.data());
        TEST_ASSERT_TRUE(verifier.begin());
        TEST_ASSERT_FALSE(verifier.hasSession());

        // Before beginSession, not even a message for the all zero nonce the verifier starts with
        const std::vector<uint8_t> zeroNonce(ock::SESSION_NONCE_SIZE, 0);
        const std::vector<uint8_t> candidates[] = {
            buildMessage(key, 0, ClientCommand::UNLOCK_DOORS),
            buildSessionMessage(zeroNonce, key, 0, ClientCommand::UNLOCK_DOORS),
        };
        for (const std::vector<uint8_t> &payload : candidates)
        {
            ock::ClientMessage message;
            TEST_ASSERT_TRUE(ock::parseClientMessage(payload.data(), payload.size(), message));
            TEST_ASSERT_EQUAL(ock::AuthResult::NoSession, verifier.authenticate(message));
        }

        verifier.beginSession(testNonce().data());
        TEST_ASSERT_TRUE(verifier.hasSession());
        std::vector<uint8_t> first = buildMessage(key, 0, ClientCommand::UNLOCK_DOORS);
        ock::ClientMessage message;
        TEST_ASSERT_TRUE(ock::parseClientMessage(first.data(), first.size(), message));
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok, verifier.authenticate(message));

        // After endSession (disconnect) a message for the session that just ended is refused too
        verifier.endSession();
        TEST_ASSERT_FALSE(verifier.hasSession());
        std::vector<uint8_t> next = buildMessage(key, 1, ClientCommand::UNLOCK_DOORS);
        TEST_ASSERT_TRUE(ock::parseClientMessage(next.data(), next.size(), message));
        TEST_ASSERT_EQUAL(ock::AuthResult::NoSession, verifier.authenticate(message));
        TEST_ASSERT_EQUAL_UINT32(1, verifier.counter());
    }

    void test_previous_session_rejected_after_counter_reset()
    {
        // Recorded on an earlier connection, then the counter was reset with the BOOT button.
        // The counter alone would accept these again, the nonce must not.
        VerifierFixture fixture;
        std::vector<uint8_t> recorded[3];
        for (uint32_t counter = 0; counter < 3; counter++)
        {
            recorded[counter] = buildMessage(fixture.key, counter, ClientCommand::UNLOCK_DOORS);
            TEST_ASSERT_EQUAL(ock::AuthResult::Ok, authenticate(fixture, recorded[counter]));
        }
        fixture.verifier.endSession();

        TEST_ASSERT_TRUE(fixture.verifier.resetCounter());
        fixture.verifier.beginSession(otherNonce().data());
        for (const std::vector<uint8_t> &payload : recorded)
            TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, authenticate(fixture, payload));
        TEST_ASSERT_EQUAL_UINT32(0, fixture.verifier.counter());

        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildSessionMessage(otherNonce(), fixture.key, 0,
                                                                    ClientCommand::UNLOCK_DOORS)));
    }

    void test_new_session_replaces_nonce()
    {
        VerifierFixture fixture;
        fixture.verifier.beginSession(otherNonce().data());
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac,
                          authenticate(fixture, buildMessage(fixture.key, 0, ClientCommand::UNLOCK_DOORS)));
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildSessionMessage(otherNonce(), fixture.key, 0,
                                                                    ClientCommand::UNLOCK_DOORS)));
    }

    void test_session_info()
    {
        VerifierFixture fixture(0x12345678);
        uint8_t info[ock::SESSION_INFO_SIZE];
        TEST_ASSERT_EQUAL(ock::SESSION_INFO_SIZE, fixture.verifier.sessionInfo(info));
        TEST_ASSERT_EQUAL_HEX8_ARRAY(testNonce().data(), info, ock::SESSION_NONCE_SIZE);
        const uint8_t counter[] = {0x78, 0x56, 0x34, 0x12};
        TEST_ASSERT_EQUAL_HEX8_ARRAY(counter, info + ock::SESSION_NONCE_SIZE, 4);

        // Follows the counter once a message went through
        TEST_ASSERT_EQUAL(ock::AuthResult::Ok,
                          authenticate(fixture, buildMessage(fixture.key, 0x12345678, ClientCommand::LOCK_DOORS)));
        fixture.verifier.sessionInfo(info);
        const uint8_t next[] = {0x79, 0x56, 0x34, 0x12};
        TEST_ASSERT_EQUAL_HEX8_ARRAY(next, info + ock::SESSION_NONCE_SIZE, 4);

        // Nothing to tell without a session, never a stale nonce
        fixture.verifier.endSession();
        TEST_ASSERT_EQUAL(0, fixture.verifier.sessionInfo(info));
    }

    void test_constant_time_equals()
    {
        const uint8_t a[] = {1, 2, 3, 4};
        const uint8_t b[] = {1, 2, 3, 4};
        const uint8_t c[] = {1, 2, 3, 5};
        const uint8_t d[] = {0, 2, 3, 4};
        TEST_ASSERT_TRUE(ock::constantTimeEquals(a, b, 4));
        TEST_ASSERT_FALSE(ock::constantTimeEquals(a, c, 4));
        TEST_ASSERT_FALSE(ock::constantTimeEquals(a, d, 4));
        TEST_ASSERT_TRUE(ock::constantTimeEquals(a, c, 0));
    }
}

void runAuthTests()
{
    RUN_TEST(test_accepts_current_counter_and_saves_next);
    RUN_TEST(test_replay_is_rejected);
    RUN_TEST(test_replay_is_rejected_after_reboot);
    RUN_TEST(test_older_counters_are_rejected);
    RUN_TEST(test_window_edges);
    RUN_TEST(test_skipped_counters_cant_be_used_later);
    RUN_TEST(test_wrong_password_is_rejected);
    RUN_TEST(test_changed_command_byte_is_rejected);
    RUN_TEST(test_changed_data_is_rejected);
    RUN_TEST(test_added_or_removed_data_is_rejected);
    RUN_TEST(test_every_bit_flip_in_hmac_is_rejected);
    RUN_TEST(test_all_zero_hmac_is_rejected);
    RUN_TEST(test_failing_hmac_function_never_matches);
    RUN_TEST(test_refuses_everything_if_counter_cant_be_loaded);
    RUN_TEST(test_not_ready_before_begin);
    RUN_TEST(test_save_failure_blocks_command_and_message_reuse);
    RUN_TEST(test_counter_never_wraps_to_zero);
    RUN_TEST(test_window_stops_before_counter_overflow);
    RUN_TEST(test_begin_loads_stored_counter);
    RUN_TEST(test_reset_counter);
    RUN_TEST(test_failed_reset_refuses_everything);
    RUN_TEST(test_message_for_another_session_is_rejected);
    RUN_TEST(test_nothing_accepted_without_session);
    RUN_TEST(test_previous_session_rejected_after_counter_reset);
    RUN_TEST(test_new_session_replaces_nonce);
    RUN_TEST(test_session_info);
    RUN_TEST(test_constant_time_equals);
}
