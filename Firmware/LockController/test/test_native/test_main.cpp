#include <unity.h>

// Security tests for lib/OckCore. Run with: pio test -e native
// Each file groups the tests of one area and registers them here.

void runCryptoTests();
void runProtocolVectorTests();
void runParseTests();
void runAuthTests();
void runProcessorTests();
void runProximityTests();
void runPasswordTests();

void setUp() {}
void tearDown() {}

int main()
{
    UNITY_BEGIN();
    // The reference HMAC has to be right before anything else can rely on it
    runCryptoTests();
    runProtocolVectorTests();
    runParseTests();
    runAuthTests();
    runProcessorTests();
    runProximityTests();
    runPasswordTests();
    return UNITY_END();
}
