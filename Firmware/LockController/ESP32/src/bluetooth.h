#ifndef BLUETOOTH_H
#define BLUETOOTH_H

/// @brief Called when the device is connected (for additional custom actions)
extern void (*onConnected)();
/// @brief Called when the device is disconnected (for additional custom actions)
extern void (*onDisconnected)();

/// @brief Called when the car gets locked
extern void (*onLocked)();
/// @brief Called when the car gets unlocked
extern void (*onUnlocked)();
/// @brief Called when the trunk gets opend
extern void (*onTrunkOpend)();
/// @brief Called when the engine gets started from the app
extern void (*onEngineStarted)();

/// @brief Is the ESP is connected to the phone
extern bool deviceConnected;
/// @brief Is the currently connected phone authenticated
extern bool isAuthenticated;
/// @brief Is proximity key enabled
extern bool autoLocking;
/// @brief Is the car locked
extern bool isLocked;

/// @brief Sets up bluetooth
void setupBluetooth();
/// @brief Loop need for bluetooth to work
void bluetoothLoop();

#endif