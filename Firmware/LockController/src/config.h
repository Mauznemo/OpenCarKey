#pragma once
#include "types/features.h"

// Features supported by the vehicle
// Add `| Feature::Engine` and/or `| Feature::Windows` once you wired up the
// matching relays and callbacks (onEngineStarted, onEngineStopped,
// onWindowsOpened, onWindowsClosed) in main.cpp
static const Feature SUPPORTED_FEATURES =
    Feature::DoorsLock | Feature::TrunkOpen;

// Bluetooth display name of the device
#define DEVICE_NAME "ESP32_Lock"
// Please change to something unique (can also be longer)
#define PASSWORD "abc123"
// Enable to get debug messages via serial
#define DEBUG_MODE true