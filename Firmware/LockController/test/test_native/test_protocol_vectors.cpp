// Messages the app produces, byte for byte. The same vectors are in the app tests
// (MobileApp/test/rolling_code_test.dart), so if either side changes the format, both fail.

#include <unity.h>
#include <OckAuth.h>
#include "test_helpers.h"

namespace
{
    struct Vector
    {
        uint32_t counter;
        const char *payloadHex; // HMAC + command (+ data length + data), as written by the app
    };

    // Password "test-password-123", session nonce 00 01 02 .. 0f (testNonce)
    const Vector VECTORS[] = {
        // GET_VERSION
        {0, "3c37ac333b824b7df95862ec548ccbec7b60d224df59bc5de79ff280badc28c000"},
        // UNLOCK_DOORS
        {1, "34782e85685117cc37538f8e5e5e5c3669576afbe74e609c220549e045202be803"},
        // LOCK_DOORS, counter shows the byte order (little endian)
        {0x12345678, "4566e919f06eaa93d387971695d99a34cfca7e41e4d524c178afcfaec0c62efe02"},
        // PROXIMITY_COOLDOWN 1.5 min
        {42, "fba234c51edee1082dfd048152354afb8b5242a6424e0b70320246b2b6f5073409040000c03f"},
        // RSSI_TRIGGER -60 dBm, dead zone 4
        {43, "444f924f61e2a704fd1a8a42d122447d136f7eae6b51fbddc87f50013e66e8bf0a08000070c200008040"},
    };

    void test_builder_matches_app_vectors()
    {
        std::vector<uint8_t> key = keyFromPassword("test-password-123");
        for (const Vector &vector : VECTORS)
        {
            std::vector<uint8_t> expected = fromHex(vector.payloadHex);
            ock::ClientMessage message;
            TEST_ASSERT_TRUE(ock::parseClientMessage(expected.data(), expected.size(), message));

            std::vector<uint8_t> data(message.data, message.data + message.dataLength);
            std::vector<uint8_t> built = buildMessage(key, vector.counter, message.command, data);
            TEST_ASSERT_EQUAL(expected.size(), built.size());
            TEST_ASSERT_EQUAL_HEX8_ARRAY(expected.data(), built.data(), expected.size());
        }
    }

    void test_verifier_accepts_app_vectors()
    {
        for (const Vector &vector : VECTORS)
        {
            VerifierFixture fixture(vector.counter);
            std::vector<uint8_t> payload = fromHex(vector.payloadHex);
            ock::ClientMessage message;
            TEST_ASSERT_TRUE(ock::parseClientMessage(payload.data(), payload.size(), message));
            TEST_ASSERT_EQUAL(ock::AuthResult::Ok, fixture.verifier.authenticate(message));
            TEST_ASSERT_EQUAL_UINT32(vector.counter + 1, fixture.verifier.counter());
        }
    }

    void test_hmac_input_layout()
    {
        const std::vector<uint8_t> nonce = testNonce();
        const uint8_t data[] = {0xAA, 0xBB, 0xCC, 0xDD};
        ock::ClientMessage message = {nullptr, 0x09, data, sizeof(data)};
        uint8_t input[ock::MAX_HMAC_INPUT_SIZE];
        size_t length = ock::buildHmacInput(nonce.data(), 0x12345678, message, input);

        std::vector<uint8_t> expected = fromHex("000102030405060708090a0b0c0d0e0f"
                                                "78563412"
                                                "09"
                                                "04"
                                                "aabbccdd");
        TEST_ASSERT_EQUAL(expected.size(), length);
        TEST_ASSERT_EQUAL_HEX8_ARRAY(expected.data(), input, expected.size());

        ock::ClientMessage noData = {nullptr, 0x03, nullptr, 0};
        length = ock::buildHmacInput(nonce.data(), 1, noData, input);
        std::vector<uint8_t> expectedNoData = fromHex("000102030405060708090a0b0c0d0e0f"
                                                      "01000000"
                                                      "03");
        TEST_ASSERT_EQUAL(expectedNoData.size(), length);
        TEST_ASSERT_EQUAL_HEX8_ARRAY(expectedNoData.data(), input, expectedNoData.size());

        // The longest message has to fit
        uint8_t maxData[ock::MAX_DATA_LENGTH] = {0};
        ock::ClientMessage longest = {nullptr, 0x0A, maxData, ock::MAX_DATA_LENGTH};
        TEST_ASSERT_EQUAL(ock::MAX_HMAC_INPUT_SIZE, ock::buildHmacInput(nonce.data(), 1, longest, input));
    }

    void test_session_info_layout()
    {
        // What the app reads from ffe2: nonce (16) + counter (uint32 little endian)
        const std::vector<uint8_t> nonce = testNonce();
        uint8_t info[ock::SESSION_INFO_SIZE];
        TEST_ASSERT_EQUAL(20, ock::SESSION_INFO_SIZE);
        TEST_ASSERT_EQUAL(ock::SESSION_INFO_SIZE, ock::writeSessionInfo(nonce.data(), 0x12345678, info));

        std::vector<uint8_t> expected = fromHex("000102030405060708090a0b0c0d0e0f78563412");
        TEST_ASSERT_EQUAL_HEX8_ARRAY(expected.data(), info, expected.size());
    }

    void test_message_without_nonce_is_rejected()
    {
        // The V5 layout before session nonces: counter + command only. A message like that
        // works on any connection, so it must not be accepted.
        VerifierFixture fixture;
        uint8_t input[] = {0x00, 0x00, 0x00, 0x00, static_cast<uint8_t>(ClientCommand::UNLOCK_DOORS)};
        std::vector<uint8_t> payload(32);
        refHmacSha256(fixture.key.data(), fixture.key.size(), input, sizeof(input), payload.data());
        payload.push_back(static_cast<uint8_t>(ClientCommand::UNLOCK_DOORS));

        ock::ClientMessage message;
        TEST_ASSERT_TRUE(ock::parseClientMessage(payload.data(), payload.size(), message));
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, fixture.verifier.authenticate(message));
        TEST_ASSERT_EQUAL_UINT32(0, fixture.verifier.counter());
    }

    void test_old_v4_hmac_without_data_is_rejected()
    {
        // V4 didn't cover the additional data with the HMAC, so anyone holding a valid
        // message could swap in their own values. Such messages must not be accepted anymore.
        VerifierFixture fixture(42);
        std::vector<uint8_t> payload = fromHex("05c84a3ed96536fd54e7ac5c4bd7ed6a4900f0497732a0e4c0829ced5fc77b25");
        payload.push_back(0x09);
        payload.push_back(0x04);
        std::vector<uint8_t> cooldown = floatBytes(1.5f);
        payload.insert(payload.end(), cooldown.begin(), cooldown.end());

        ock::ClientMessage message;
        TEST_ASSERT_TRUE(ock::parseClientMessage(payload.data(), payload.size(), message));
        TEST_ASSERT_EQUAL(ock::AuthResult::InvalidHmac, fixture.verifier.authenticate(message));
    }
}

void runProtocolVectorTests()
{
    RUN_TEST(test_builder_matches_app_vectors);
    RUN_TEST(test_verifier_accepts_app_vectors);
    RUN_TEST(test_hmac_input_layout);
    RUN_TEST(test_session_info_layout);
    RUN_TEST(test_old_v4_hmac_without_data_is_rejected);
    RUN_TEST(test_message_without_nonce_is_rejected);
}
