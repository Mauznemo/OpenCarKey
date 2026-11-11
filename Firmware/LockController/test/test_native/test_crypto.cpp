// Checks the reference SHA-256 / HMAC used by the tests against official test vectors.

#include <unity.h>
#include "test_helpers.h"

namespace
{
    void assertHex(const char *expectedHex, const uint8_t *actual)
    {
        std::vector<uint8_t> expected = fromHex(expectedHex);
        TEST_ASSERT_EQUAL_HEX8_ARRAY(expected.data(), actual, expected.size());
    }

    void test_sha256_nist_vectors()
    {
        uint8_t out[32];
        refSha256((const uint8_t *)"", 0, out);
        assertHex("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", out);

        refSha256((const uint8_t *)"abc", 3, out);
        assertHex("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", out);

        const char *twoBlocks = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
        refSha256((const uint8_t *)twoBlocks, strlen(twoBlocks), out);
        assertHex("248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", out);
    }

    void test_hmac_rfc4231_vectors()
    {
        uint8_t out[32];

        // Test case 1
        std::vector<uint8_t> key1(20, 0x0b);
        refHmacSha256(key1.data(), key1.size(), (const uint8_t *)"Hi There", 8, out);
        assertHex("b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7", out);

        // Test case 2
        const char *data2 = "what do ya want for nothing?";
        refHmacSha256((const uint8_t *)"Jefe", 4, (const uint8_t *)data2, strlen(data2), out);
        assertHex("5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843", out);

        // Test case 6 (key longer than a block)
        std::vector<uint8_t> key6(131, 0xaa);
        const char *data6 = "Test Using Larger Than Block-Size Key - Hash Key First";
        refHmacSha256(key6.data(), key6.size(), (const uint8_t *)data6, strlen(data6), out);
        assertHex("60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54", out);
    }

    void test_key_is_sha256_of_password()
    {
        // Same value as the app test (MobileApp/test/rolling_code_test.dart)
        std::vector<uint8_t> key = keyFromPassword("test-password-123");
        assertHex("7c13ab2e1d157284ccb11e9737f90cbb611b0acdb8f8dcd4e303a680e58a8b1b", key.data());
    }
}

void runCryptoTests()
{
    RUN_TEST(test_sha256_nist_vectors);
    RUN_TEST(test_hmac_rfc4231_vectors);
    RUN_TEST(test_key_is_sha256_of_password);
}
