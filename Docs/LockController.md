# Lock Controller
### Sections
**[Config](#config)**<br>
**[Custom code for locking, unlocking etc.](#custom-code-for-locking-unlocking-etc)**<br>
&emsp;[Locking](#locking)<br>
&emsp;[Unlocking](#unlocking)<br>
&emsp;[Opening Trunk](#opening-trunk)<br>
&emsp;[Staring Engine](#starting-engine)<br>
**[Other Events](#other-events)**<br>
&emsp;[OnConnected & OnDisconnected](#onconnected--ondisconnected)<br>
**[bluetooth.h](#bluetoothh)**<br>
&emsp;[onConnected](#onconnected)<br>
&emsp;[onDisconnected](#ondisconnected)<br>
&emsp;[onLocked](#onlocked)<br>
&emsp;[onUnlocked](#onunlocked)<br>
&emsp;[onTrunkOpened](#ontrunkopened)<br>
&emsp;[onEngineStarted](#onenginestarted)<br>
&emsp;[deviceConnected](#deviceconnected)<br>
&emsp;[autoLocking](#autolocking)<br>
&emsp;[isLocked](#islocked)<br>
&emsp;[setupBluetooth](#setupbluetooth)<br>
&emsp;[bluetoothLoop](#bluetoothloop)<br>
**[Ble communication protocol](#ble-communication-protocol)**<br>

## Config
Open `platformio.ini`. There you can set your password (`LOCK_PIN`) and BLE device name (`DEVICE_NAME`).

## Custom code for locking, unlocking etc.
### Locking
To handle locking you need to assign a function to `onLocked` in `setup()` like (in `src/main.cpp`):
```cpp
void lock(bool proximity)
{
  //Your code for locking

  Serial.println("Locked");
}

void setup()
{
  // Other code..

  onLocked = lock;

  // Other code..
}
```

### Unlocking
To handle unlocking you need to assign a function to `onUnlocked` in `setup()` like (in `src/main.cpp`):
```cpp
void unlock(bool proximity)
{
  //Your code for unlocking

  Serial.println("Unlocked");
}

void setup()
{
  // Other code..

  onUnlocked = unlock;

  // Other code..
}
```

### Opening Trunk
To handle trunk opening you need to assign a function to `onTrunkOpened` in `setup()` like (in `src/main.cpp`):
```cpp
void openTrunk()
{
  //Your code for opening trunk

  Serial.println("Trunk Opened");
}

void setup()
{
  // Other code..

  onTrunkOpened = openTrunk;

  // Other code..
}
```

### Starting Engine
To handle starting of the engine you need to assign a function to `onEngineStarted` in `setup()` like (in `src/main.cpp`):
```cpp
void startEngine()
{
  //Your code for staring engine

  Serial.println("Engine Started");
}

void setup()
{
  // Other code..

  onEngineStarted = startEngine;

  // Other code..
}
```

## Other events
### OnConnected & OnDisconnected
If you want to call custom code when the app connects ot disconnects you can do the same as before for `onConnected` and `onDisconnected`
```cpp
void connected()
{
  Serial.println("App connected");
}

void disconnected()
{

}

void setup()
{
  // Other code..

  onConnected = connected;
  onDisconnected = disconnected;

  // Other code..
}
```

## bluetooth.h
Everything you can access from `main.cpp` (`#include "bluetooth.h"`)

### onConnected
```cpp
extern void (*onConnected)()
```
Called when the device is connected (for additional custom actions)

### onDisconnected
```cpp
extern void (*onDisconnected)()
```
Called when the device is disconnected (for additional custom actions)

### onLocked
```cpp
extern void (*onLocked)(bool proximity)
```
Called when the car gets locked

### onUnlocked
```cpp
extern void (*onUnlocked)(bool proximity)
```
Called when the car gets unlocked

### onTrunkOpened
```cpp
extern void (*onTrunkOpened)()
```
Called when the trunk gets opened

### onEngineStarted
```cpp
extern void (*onEngineStarted)()
```
Called when the engine gets started from the app

### deviceConnected
```cpp
extern bool deviceConnected
```
Is the ESP is connected to the phone

### autoLocking
```cpp
extern bool autoLocking
```
Is proximity key enabled

### isLocked
```cpp
extern bool isLocked
```
Is the car locked

### setupBluetooth
```cpp
void setupBluetooth()
```
Sets up bluetooth

### bluetoothLoop
```cpp
void bluetoothLoop()
```
Loop need for bluetooth to work

## Ble communication protocol (V3)
Communication protocol between ESP and App.
### Message structure (from client/app):
32 byte HMAC + 1 byte command (+ optional additional data length + bytes)

### Response structure (From ESP32)
1 byte command (+ optional additional data length + bytes)

| Message                                                         | Response                                         |
| ----------------------------------------------------------------| ------------------------------------------------ |
| `0x00` (GET_VERSION)                                            | `VERSION + {Current protocol version}` (VERSION) |
| Anything with no/invalid rolling code (HMAC)                    | `0x00` (INVALID_HMAC)                            |
| `0x01` (GET_DATA)                                               | `0x02` (LOCKED) or `0x04` (UNLOCKED)             |
| `0x02` (LOCK_DOORS)                                             | `0x02` (LOCKED)                                  |
| `0x03` (UNLOCK_DOORS)                                           | `0x04` (UNLOCKED)                                |
| `0x04` (OPEN_TRUNK)                                             | None                                             |
| `0x05` (START_ENGINE)                                           | None                                             |
| `0x06` (STOP_ENGINE)                                            | None                                             |
| `0x07` (PROXIMITY_KEY_ON)                                       | None                                             |
| `0x08` (PROXIMITY_KEY_OFF)                                      | None                                             |
| `0x09 + {Proximity cooldown float in min}` (PROXIMITY_COOLDOWN) | None                                             |
| `0x0A + {Rssi float, Rssi dead zone float}` (RSSI_TRIGGER)      | None                                             |
| `0x0B` (GET_RSSI)                                               | `0x06 + {Rssi float}` (RSSI) can take 500ms      |
| `0x0C` (GET_FEATURES)                                           | `0x07 + {int bitmask}` (FEATURES)                |

`RSSI_TRIGGER` (0x0A) sets the **rssi strength** where proximity key will unlock and the **zone** (in rough meters) where nothing will happen. Eg. 5m: After the car was locked you have to get around 5m closer to it to unlock again. This is to prevent rapid locking and unlocking if you are at the exact trigger distance

| Message from ESP             | Description                              |
| ---------------------------- | ---------------------------------------- |
| `0x03` (PROXIMITY_LOCKED)    | Vehicle was locked using proximity key   |
| `0x05` (PROXIMITY_UNLOCKED)  | Vehicle was unlocked using proximity key |

