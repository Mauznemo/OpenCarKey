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
&emsp;[isAuthenticated](#isauthenticated)<br>
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
void lock()
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
void unlock()
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
extern void (*onLocked)()
```
Called when the car gets locked

### onUnlocked
```cpp
extern void (*onUnlocked)()
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

### isAuthenticated
```cpp
extern bool isAuthenticated
```
Is the currently connected phone authenticated

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

## Ble communication protocol
Communication protocol between ESP and App.
| Message                                        | Response                           |
| ---------------------------------------------- | ---------------------------------- |
| `AUTH:{Password String}`                       | `AUTH_OK` or `AUTH_FAIL`           |
| Anything while not authenticated               | `NOT_AUTH`                         |
| `SEND_DATA`                                    | `LOCKED` or `UNLOCKED`             |
| `LOCK`                                         | `LOCKED`                           |
| `UNLOCK`                                       | `UNLOCKED`                         |
| `OPEN_TRUNK`                                   | None                               |
| `START_ENGINE`                                 | None                               |
| `PROX_KEY_ON`                                  | None                               |
| `PROX_KEY_OFF`                                 | None                               |
| `RSSI_TRIG:{Rssi float, Rssi dead zone float}` | None                               |
| `PROX_COOLD:{Proximity cooldown float in min}` | None                               |
| `RSSI`                                         | `RSSI:{Rssi float}` can take 500ms |

`RSSI_TRIG:` sets the **rssi strength** where proximity key will unlock and the **zone** (in rough meters) where nothing will happen. Eg. 5m: After the car was locked you have to get around 5m closer to it to unlock again. This is to prevent rapid locking and unlocking if you are at the exact trigger distance

| Message from ESP | Description                              |
| ---------------- | ---------------------------------------- |
| `UNLOCKED_PROX`  | Vehicle was unlocked using proximity key |
| `LOCKED_PROX`    | Vehicle was locked using proximity key   |

