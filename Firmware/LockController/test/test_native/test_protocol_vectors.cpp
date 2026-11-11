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

    // Password "test-password-123"
    const Vector VECTORS[] = {
        // GET_VERSION
        {0, "205a108405bfe7bd98f1aec14272cf3892fcbe0060f7d2fafd56bbd7c7619d7f00"},
        // UNLOCK_DOORS
        {1, "46ae279cdfc80620fb4001cb1da81ef45adbea942c514d981e6e538e28c6ab3d03"},
        // LOCK_DOORS, counter shows the byte order (little endian)
        {0x12345678, "4915fbca3febba7b5e65e2bcd880f6a21f95900fde455445ca615d42ceda29db02"},
        // PROXIMITY_COOLDOWN 1.5 min
        {42, "e48ded4cf122555db0324b0fd1470fcb8dd66d35f8fba5971f090a7b8db80dc809040000c03f"},
        // RSSI_TRIGGER -60 dBm, dead zone 4
        {43, "950f4cef1f7c2af081fb0ab609c7e890897228988e0ba9e3a1bfe7c556b02a8c0a08000070c200008040"},
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
        const uint8_t data[] = {0xAA, 0xBB, 0xCC, 0xDD};
        ock::ClientMessage message = {nullptr, 0x09, data, sizeof(data)};
        uint8_t input[ock::MAX_HMAC_INPUT_SIZE];
        size_t length = ock::buildHmacInput(0x12345678, message, input);

        const uint8_t expected[] = {0x78, 0x56, 0x34, 0x12, 0x09, 0x04, 0xAA, 0xBB, 0xCC, 0xDD};
        TEST_ASSERT_EQUAL(sizeof(expected), length);
        TEST_ASSERT_EQUAL_HEX8_ARRAY(expected, input, sizeof(expected));

        ock::ClientMessage noData = {nullptr, 0x03, nullptr, 0};
        length = ock::buildHmacInput(1, noData, input);
        const uint8_t expectedNoData[] = {0x01, 0x00, 0x00, 0x00, 0x03};
        TEST_ASSERT_EQUAL(sizeof(expectedNoData), length);
        TEST_ASSERT_EQUAL_HEX8_ARRAY(expectedNoData, input, sizeof(expectedNoData));
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
    RUN_TEST(test_old_v4_hmac_without_data_is_rejected);
}
