#pragma once

// Plain SHA-256 / HMAC-SHA256 used only by the native tests, because mbedtls (what the
// firmware uses) only exists on the ESP32. It is checked against the official NIST and
// RFC 4231 test vectors in test_crypto.cpp before anything else relies on it.

#include <stddef.h>
#include <stdint.h>

void refSha256(const uint8_t *data, size_t length, uint8_t out[32]);

bool refHmacSha256(const uint8_t *key, size_t keyLength, const uint8_t *message, size_t messageLength,
                   uint8_t *out);
