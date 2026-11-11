// The full path a message takes before its command runs (what bluetooth.cpp's onWrite calls).

#include <unity.h>
#include <cmath>
#include <limits>
#include <OckCommandProcessor.h>
#include "test_helpers.h"

namespace
{
    const Feature ALL_FEATURES = Feature::DoorsLock | Feature::TrunkOpen | Feature::Engine | Feature::Windows;

    ock::CommandDecision process(VerifierFixture &fixture, Feature features, const std::vector<uint8_t> &payload)
    {
        return ock::processClientMessage(fixture.verifier, features, payload.data(), payload.size());
    }

    ock::CommandStatus processNext(VerifierFixture &fixture, Feature features, ClientCommand command,
                                   const std::vector<uint8_t> &data = std::vector<uint8_t>())
    {
        return process(fixture, features, buildMessage(fixture.key, fixture.verifier.counter(), command, data)).status;
    }

    void test_accepts_valid_command()
    {
        VerifierFixture fixture;
        ock::CommandDecision decision =
            process(fixture, ALL_FEATURES, buildMessage(fixture.key, 0, ClientCommand::UNLOCK_DOORS));
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted, decision.status);
        TEST_ASSERT_EQUAL(ClientCommand::UNLOCK_DOORS, decision.command);
    }

    void test_malformed_doesnt_consume_counter()
    {
        VerifierFixture fixture;
        std::vector<uint8_t> shortMessage(20, 0);
        ock::CommandDecision decision = process(fixture, ALL_FEATURES, shortMessage);
        TEST_ASSERT_EQUAL(ock::CommandStatus::Malformed, decision.status);
        TEST_ASSERT_TRUE(ock::shouldReplyInvalidHmac(decision.status));
        TEST_ASSERT_EQUAL_UINT32(0, fixture.verifier.counter());
    }

    void test_invalid_hmac_doesnt_consume_counter()
    {
        VerifierFixture fixture;
        std::vector<uint8_t> payload = buildMessage(fixture.key, 0, ClientCommand::UNLOCK_DOORS);
        payload[0] ^= 1;
        ock::CommandDecision decision = process(fixture, ALL_FEATURES, payload);
        TEST_ASSERT_EQUAL(ock::CommandStatus::InvalidHmac, decision.status);
        TEST_ASSERT_TRUE(ock::shouldReplyInvalidHmac(decision.status));
        TEST_ASSERT_EQUAL_UINT32(0, fixture.verifier.counter());
    }

    void test_storage_error_is_rejected()
    {
        VerifierFixture fixture;
        fixture.store.failSave = true;
        TEST_ASSERT_EQUAL(ock::CommandStatus::StorageError,
                          processNext(fixture, ALL_FEATURES, ClientCommand::UNLOCK_DOORS));
    }

    void test_unsupported_features_never_run()
    {
        struct Case
        {
            ClientCommand command;
            Feature feature;
        };
        const Case cases[] = {
            {ClientCommand::LOCK_DOORS, Feature::DoorsLock},
            {ClientCommand::UNLOCK_DOORS, Feature::DoorsLock},
            {ClientCommand::PROXIMITY_KEY_ON, Feature::DoorsLock},
            {ClientCommand::OPEN_TRUNK, Feature::TrunkOpen},
            {ClientCommand::START_ENGINE, Feature::Engine},
            {ClientCommand::STOP_ENGINE, Feature::Engine},
            {ClientCommand::OPEN_WINDOWS, Feature::Windows},
            {ClientCommand::CLOSE_WINDOWS, Feature::Windows},
        };

        for (const Case &c : cases)
        {
            // Every feature except the one the command needs
            const Feature others = static_cast<Feature>(static_cast<uint32_t>(ALL_FEATURES) &
                                                        ~static_cast<uint32_t>(c.feature));
            VerifierFixture fixture;
            ock::CommandStatus status = processNext(fixture, others, c.command);
            TEST_ASSERT_EQUAL_MESSAGE(ock::CommandStatus::UnsupportedFeature, status, toString(c.command));
            TEST_ASSERT_FALSE(ock::shouldReplyInvalidHmac(status));

            TEST_ASSERT_EQUAL_MESSAGE(ock::CommandStatus::Accepted, processNext(fixture, c.feature, c.command),
                                      toString(c.command));
        }
    }

    void test_always_allowed_commands()
    {
        VerifierFixture fixture;
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted, processNext(fixture, Feature::None, ClientCommand::GET_VERSION));
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted, processNext(fixture, Feature::None, ClientCommand::GET_DATA));
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted, processNext(fixture, Feature::None, ClientCommand::GET_FEATURES));
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted, processNext(fixture, Feature::None, ClientCommand::GET_RSSI));
        // Turning the proximity key off must always work
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted, processNext(fixture, Feature::None, ClientCommand::PROXIMITY_KEY_OFF));
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted,
                          processNext(fixture, Feature::None, ClientCommand::PROXIMITY_COOLDOWN, floatBytes(1.0f)));
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted,
                          processNext(fixture, Feature::None, ClientCommand::RSSI_TRIGGER, floatBytes(-60.0f, 4.0f)));
    }

    void test_unknown_command_is_rejected()
    {
        VerifierFixture fixture;
        const uint8_t unknown[] = {0x0F, 0x10, 0x7F, 0x80, 0xFF};
        for (uint8_t command : unknown)
        {
            std::vector<uint8_t> payload = buildMessage(fixture.key, fixture.verifier.counter(), command);
            TEST_ASSERT_EQUAL(ock::CommandStatus::UnknownCommand, process(fixture, ALL_FEATURES, payload).status);
        }
    }

    void test_data_length_must_match_command()
    {
        VerifierFixture fixture;
        // Too short: these used to read past the end of the message
        TEST_ASSERT_EQUAL(ock::CommandStatus::InvalidData,
                          processNext(fixture, ALL_FEATURES, ClientCommand::RSSI_TRIGGER, floatBytes(-60.0f)));
        TEST_ASSERT_EQUAL(ock::CommandStatus::InvalidData,
                          processNext(fixture, ALL_FEATURES, ClientCommand::RSSI_TRIGGER, std::vector<uint8_t>(1, 0)));
        TEST_ASSERT_EQUAL(ock::CommandStatus::InvalidData,
                          processNext(fixture, ALL_FEATURES, ClientCommand::PROXIMITY_COOLDOWN, std::vector<uint8_t>(1, 0)));
        TEST_ASSERT_EQUAL(ock::CommandStatus::InvalidData,
                          processNext(fixture, ALL_FEATURES, ClientCommand::RSSI_TRIGGER));
        TEST_ASSERT_EQUAL(ock::CommandStatus::InvalidData,
                          processNext(fixture, ALL_FEATURES, ClientCommand::PROXIMITY_COOLDOWN));
        // Too long
        TEST_ASSERT_EQUAL(ock::CommandStatus::InvalidData,
                          processNext(fixture, ALL_FEATURES, ClientCommand::PROXIMITY_COOLDOWN, floatBytes(1.0f, 2.0f)));
        // Data where none belongs
        TEST_ASSERT_EQUAL(ock::CommandStatus::InvalidData,
                          processNext(fixture, ALL_FEATURES, ClientCommand::UNLOCK_DOORS, floatBytes(1.0f)));
    }

    void test_rssi_trigger_values()
    {
        const float nan = std::numeric_limits<float>::quiet_NaN();
        const float inf = std::numeric_limits<float>::infinity();
        const float invalid[][2] = {
            {nan, 4.0f}, {inf, 4.0f}, {-inf, 4.0f}, {-60.0f, nan}, {-60.0f, inf}, {-201.0f, 4.0f},
            {-1000.0f, 4.0f}, {0.5f, 4.0f}, {10.0f, 4.0f}, {-60.0f, -1.0f}, {-60.0f, 101.0f}};

        for (const auto &values : invalid)
        {
            VerifierFixture fixture;
            TEST_ASSERT_EQUAL(ock::CommandStatus::InvalidData,
                              processNext(fixture, ALL_FEATURES, ClientCommand::RSSI_TRIGGER,
                                          floatBytes(values[0], values[1])));
        }

        VerifierFixture fixture;
        ock::CommandDecision decision = process(
            fixture, ALL_FEATURES, buildMessage(fixture.key, 0, ClientCommand::RSSI_TRIGGER, floatBytes(-60.0f, 4.0f)));
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted, decision.status);
        TEST_ASSERT_EQUAL_FLOAT(-60.0f, decision.values[0]);
        TEST_ASSERT_EQUAL_FLOAT(4.0f, decision.values[1]);

        // "Not calibrated" value the app sends (unlock on connect)
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted,
                          processNext(fixture, ALL_FEATURES, ClientCommand::RSSI_TRIGGER, floatBytes(-200.0f, 15.0f)));
    }

    void test_proximity_cooldown_values()
    {
        const float invalid[] = {std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::infinity(),
                                 -std::numeric_limits<float>::infinity(), -1.0f, -0.01f, 61.0f, 1e9f};
        for (float value : invalid)
        {
            VerifierFixture fixture;
            TEST_ASSERT_EQUAL(ock::CommandStatus::InvalidData,
                              processNext(fixture, ALL_FEATURES, ClientCommand::PROXIMITY_COOLDOWN, floatBytes(value)));
        }

        VerifierFixture fixture;
        ock::CommandDecision decision = process(
            fixture, ALL_FEATURES, buildMessage(fixture.key, 0, ClientCommand::PROXIMITY_COOLDOWN, floatBytes(2.5f)));
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted, decision.status);
        TEST_ASSERT_EQUAL_FLOAT(2.5f, decision.values[0]);
        TEST_ASSERT_EQUAL(ock::CommandStatus::Accepted,
                          processNext(fixture, ALL_FEATURES, ClientCommand::PROXIMITY_COOLDOWN, floatBytes(0.0f)));
    }

    void test_reply_rules()
    {
        TEST_ASSERT_FALSE(ock::shouldReplyInvalidHmac(ock::CommandStatus::Accepted));
        TEST_ASSERT_TRUE(ock::shouldReplyInvalidHmac(ock::CommandStatus::Malformed));
        TEST_ASSERT_TRUE(ock::shouldReplyInvalidHmac(ock::CommandStatus::InvalidHmac));
        TEST_ASSERT_TRUE(ock::shouldReplyInvalidHmac(ock::CommandStatus::StorageError));
        TEST_ASSERT_TRUE(ock::shouldReplyInvalidHmac(ock::CommandStatus::CounterExhausted));
        TEST_ASSERT_FALSE(ock::shouldReplyInvalidHmac(ock::CommandStatus::UnknownCommand));
        TEST_ASSERT_FALSE(ock::shouldReplyInvalidHmac(ock::CommandStatus::UnsupportedFeature));
        TEST_ASSERT_FALSE(ock::shouldReplyInvalidHmac(ock::CommandStatus::InvalidData));
    }

    void test_random_garbage_is_never_accepted()
    {
        // Simple deterministic fuzzing: random bytes of every length must never get through
        VerifierFixture fixture;
        uint32_t seed = 12345;
        for (int round = 0; round < 3000; round++)
        {
            seed = seed * 1103515245u + 12345u;
            const size_t length = (seed >> 16) % 64;
            std::vector<uint8_t> payload(length);
            for (size_t i = 0; i < length; i++)
            {
                seed = seed * 1103515245u + 12345u;
                payload[i] = (uint8_t)(seed >> 16);
            }
            if (length > 33)
                payload[33] = (uint8_t)(length - 34); // sometimes a consistent length byte

            ock::CommandDecision decision = ock::processClientMessage(fixture.verifier, ALL_FEATURES,
                                                                      payload.data(), payload.size());
            TEST_ASSERT_NOT_EQUAL(ock::CommandStatus::Accepted, decision.status);
        }
        TEST_ASSERT_EQUAL_UINT32(0, fixture.verifier.counter());
    }
}

void runProcessorTests()
{
    RUN_TEST(test_accepts_valid_command);
    RUN_TEST(test_malformed_doesnt_consume_counter);
    RUN_TEST(test_invalid_hmac_doesnt_consume_counter);
    RUN_TEST(test_storage_error_is_rejected);
    RUN_TEST(test_unsupported_features_never_run);
    RUN_TEST(test_always_allowed_commands);
    RUN_TEST(test_unknown_command_is_rejected);
    RUN_TEST(test_data_length_must_match_command);
    RUN_TEST(test_rssi_trigger_values);
    RUN_TEST(test_proximity_cooldown_values);
    RUN_TEST(test_reply_rules);
    RUN_TEST(test_random_garbage_is_never_accepted);
}
