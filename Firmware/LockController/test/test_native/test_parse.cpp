// Message structure checks. Everything here is untrusted input from anyone in BLE range.

#include <unity.h>
#include <OckAuth.h>
#include "test_helpers.h"

namespace
{
    std::vector<uint8_t> messageOfLength(size_t length, uint8_t fill = 0x11)
    {
        return std::vector<uint8_t>(length, fill);
    }

    void test_rejects_too_short()
    {
        ock::ClientMessage message;
        TEST_ASSERT_FALSE(ock::parseClientMessage(nullptr, 0, message));
        for (size_t length = 0; length < ock::MIN_MESSAGE_SIZE; length++)
        {
            std::vector<uint8_t> buffer = messageOfLength(length + 1);
            TEST_ASSERT_FALSE(ock::parseClientMessage(buffer.data(), length, message));
        }
    }

    void test_accepts_message_without_data()
    {
        std::vector<uint8_t> buffer = messageOfLength(33);
        buffer[32] = 0x03;
        ock::ClientMessage message;
        TEST_ASSERT_TRUE(ock::parseClientMessage(buffer.data(), buffer.size(), message));
        TEST_ASSERT_EQUAL_HEX8(0x03, message.command);
        TEST_ASSERT_EQUAL(0, message.dataLength);
        TEST_ASSERT_NULL(message.data);
        TEST_ASSERT_EQUAL_PTR(buffer.data(), message.hmac);
    }

    void test_accepts_message_with_data()
    {
        std::vector<uint8_t> buffer = messageOfLength(33 + 1 + 8);
        buffer[33] = 8;
        ock::ClientMessage message;
        TEST_ASSERT_TRUE(ock::parseClientMessage(buffer.data(), buffer.size(), message));
        TEST_ASSERT_EQUAL(8, message.dataLength);
        TEST_ASSERT_EQUAL_PTR(buffer.data() + 34, message.data);
    }

    void test_rejects_zero_data_length()
    {
        std::vector<uint8_t> buffer = messageOfLength(34);
        buffer[33] = 0;
        ock::ClientMessage message;
        TEST_ASSERT_FALSE(ock::parseClientMessage(buffer.data(), buffer.size(), message));
    }

    void test_rejects_length_longer_than_message()
    {
        // Advertises 8 bytes but only carries 4: reading 8 would go past the buffer
        std::vector<uint8_t> buffer = messageOfLength(33 + 1 + 4);
        buffer[33] = 8;
        ock::ClientMessage message;
        TEST_ASSERT_FALSE(ock::parseClientMessage(buffer.data(), buffer.size(), message));
    }

    void test_rejects_trailing_bytes()
    {
        std::vector<uint8_t> buffer = messageOfLength(33 + 1 + 8);
        buffer[33] = 4;
        ock::ClientMessage message;
        TEST_ASSERT_FALSE(ock::parseClientMessage(buffer.data(), buffer.size(), message));
    }

    void test_rejects_too_much_data()
    {
        const size_t dataLength = ock::MAX_DATA_LENGTH + 1;
        std::vector<uint8_t> buffer = messageOfLength(33 + 1 + dataLength);
        buffer[33] = (uint8_t)dataLength;
        ock::ClientMessage message;
        TEST_ASSERT_FALSE(ock::parseClientMessage(buffer.data(), buffer.size(), message));
    }

    void test_every_length_and_length_byte()
    {
        // Only messages whose length byte exactly matches the bytes that follow are accepted,
        // and the data pointer always stays inside the buffer.
        for (size_t length = 0; length <= 64; length++)
        {
            for (int lengthByte = 0; lengthByte <= 255; lengthByte++)
            {
                std::vector<uint8_t> buffer = messageOfLength(length > 0 ? length : 1);
                if (length > 33)
                    buffer[33] = (uint8_t)lengthByte;

                ock::ClientMessage message;
                const bool accepted = ock::parseClientMessage(buffer.data(), length, message);

                bool expected = length == 33;
                if (length > 33)
                    expected = lengthByte >= 1 && (size_t)lengthByte <= ock::MAX_DATA_LENGTH &&
                               length == 34 + (size_t)lengthByte;
                TEST_ASSERT_EQUAL(expected, accepted);

                if (accepted && message.dataLength > 0)
                    TEST_ASSERT_TRUE(message.data + message.dataLength <= buffer.data() + length);
            }
        }
    }
}

void runParseTests()
{
    RUN_TEST(test_rejects_too_short);
    RUN_TEST(test_accepts_message_without_data);
    RUN_TEST(test_accepts_message_with_data);
    RUN_TEST(test_rejects_zero_data_length);
    RUN_TEST(test_rejects_length_longer_than_message);
    RUN_TEST(test_rejects_trailing_bytes);
    RUN_TEST(test_rejects_too_much_data);
    RUN_TEST(test_every_length_and_length_byte);
}
