# Project Overview

OpenCarKey is an open-source project to make your own DIY remote car key or keyless entry over BLE. It contains multiple applications that work together:

- `MobileApp/` — Flutter mobile app for locking, unlocking etc. the car.
- `Firmware/LockController/` — ESP32 firmware built with PlatformIO, the counterpart that sits in the car.
- `Firmware/Keyfob/` — ESP32 firmware built with PlatformIO for a keyfob that can be used instead of the app (Not implemented yet)

The end user only has to update the config.h and main.cpp to define what functions their car has and to implement what happens on lock, unlock etc.

## Main Current Features
- App to lock, unlock, open the trunk, remote start the engine and more from your phone
- Proximity key (with customizable trigger range) to auto lock and unlock your car if you are near it. The app has a background service that auto connects BLE as soon as the car is in range
- Support for multiple vehicles
- Home screen widget. Only works when the background service is active
- ESP32 counterpart to the app
- Authenticated commands with an HMAC that includes a per-device increasing counter (rolling codes) to prevent replay attacks.
- 
## Development Guidelines
- If changing the message protocol, update both firmware and Flutter, if needed also update the version and docs (Docs/LockController.md).

### MobileApp
- Keep designs and styling the same as existing widgets or pages
- There are a few custom widgets (in MobileApp/lib/widgets/) for dialogs please use these
- When defining widgets or classes put all the vars on top of the constructor and not the other way around
- Everything else is pretty standard, utils in MobileApp/lib/utils, types in MobileApp/lib/types, freezed models in MobileApp/lib/models, services in MobileApp/lib/services, riverpod providers in MobileApp/lib/providers, helpers in MobileApp/lib/helpers, styles used across the app in MobileApp/lib/styles and all modals or sheets in MobileApp/lib/modals (Some parts might not follow the convetion correctly, these will be cleaned up later)
- Don't try to run the flutter app yourself, if you need to check something tell me and I will check it on my phone

### LockController
- Nothing special here, just a normal PlatformIO ESP32 project