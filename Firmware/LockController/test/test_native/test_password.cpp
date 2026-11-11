// The firmware refuses to build with a short PASSWORD (static_assert in bluetooth.cpp).

#include <unity.h>
#include <OckPasswordPolicy.h>

// Checked at compile time, exactly like the firmware does
static_assert(!ock::isPasswordLongEnough("abc123"), "the old default password must not build");
static_assert(!ock::isPasswordLongEnough(""), "an empty password must not build");
static_assert(ock::isPasswordLongEnough("a-long-unique-password"), "long passwords must build");

namespace
{
    void test_minimum_length()
    {
        TEST_ASSERT_EQUAL(12, ock::MIN_PASSWORD_LENGTH);
        TEST_ASSERT_FALSE(ock::isPasswordLongEnough("abc123"));
        TEST_ASSERT_FALSE(ock::isPasswordLongEnough("12345678901"));
        TEST_ASSERT_TRUE(ock::isPasswordLongEnough("123456789012"));
    }

    void test_const_strlen()
    {
        TEST_ASSERT_EQUAL(0, ock::constStrLen(""));
        TEST_ASSERT_EQUAL(6, ock::constStrLen("abc123"));
    }
}

void runPasswordTests()
{
    RUN_TEST(test_minimum_length);
    RUN_TEST(test_const_strlen);
}
