# OpenCarKey

OpenCarKey is an open source project to make your own DIY remote car key or keyless entry.

## Features:
### Current
- App to lock, unlock, open the trunk or remote start the engine from your phone
- Proximity key to auto lock and unlock your car if you are near it
- Support for multiple vehicles
- ESP32 counterpart to the app

<div style="display: flex; gap: 10px;">
  <img src="Docs/Images/screenshot_home.png" width="200" height="auto">
  <img src="Docs/Images/screenshot_edit.png" width="200" height="auto">
  <img src="Docs/Images/screenshot_settings.png" width="200" height="auto">
</div>

### Planned
- Also support/fully switch to ESP32 instead of Arduino Nano
- Hardware keyfob using an ESP32 as alternative for the phone
- Get at least some support for IOS (as far as possible with is limitations)
- Ability to add multiple vehicles and switch between them
- Auto save parking location if car gets out of range

## Getting Started
### Mobile App
Clone the repo and open the `MobileApp` directory in Android Studio or your preferred code editor that supports Flutter.

### ESP32 Lock Controller
Clone the repo and open `Firmware/LockController/ESP32` with [PlatformIO](https://platformio.org/platformio-ide).
Now you can add custom code for locking, unlocking etc. more info [here](Docs/LockController.md#custom-code-for-locking-unlocking-etc).
Then you can open the `platformio.ini` file and change `LOCK_PIN` to any password you want.
Now you can connect you ESP32 and upload the code and then connect it with the app.

[Lock Controller Docs](Docs/LockController.md)