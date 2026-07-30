# Battery Optimization Refactor Plan (Mobile App BLE / Background Service)

Findings from an audit of the BLE background service on 2026-07-14, ranked by
expected impact. None of these change the proximity key behavior or the
widget's fast connect path (autoConnect stays exactly as it is). No total
rewrite of the BLE system is needed — the architecture (single BLE owner in the
background isolate, OS-managed autoConnect) is sound. The drain comes from two
specific problems plus some smaller inefficiencies.

---

## TL;DR

| #   | Problem                                                                                                                                                                     | Where                                                 | Expected impact                                                                                               |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1   | `flutter_background_service` holds a **partial wakelock 24/7 and never releases it** — the CPU can never deep-sleep while the service runs, even when idle and out of range | `flutter_background_service_android` plugin (native)  | **High — likely the main drain when *not* near the car**                                                      |
| 2   | Connection interval is left at Android's aggressive default (~30–50 ms); firmware even *advertises* a preference of 7.5–20 ms                                               | `Firmware/LockController/src/bluetooth/bluetooth.cpp` | **High while connected** (e.g. phone parked next to the car at home for hours) — ~5–10× less radio duty cycle |
| 3   | Every single command re-runs `requestMtu(64)` + `discoverServices()`                                                                                                        | `MobileApp/lib/services/ble_service.dart`             | Medium — extra GATT round-trips per command, also adds latency to widget buttons                              |
| 4   | Unconditional `print`/`debugPrint` in release + notification re-posts                                                                                                       | `ble_service.dart`, `ble_background_service.dart`     | Low (but this also leaks the shared secret to logcat — fix regardless)                                        |

Long-term option: CompanionDeviceManager-based architecture (zero idle cost) —
see [Appendix A](#appendix-a-companiondevicemanager-architecture-optional-long-term).
iOS notes in [Appendix B](#appendix-b-ios).

---

## 1. The permanent partial wakelock (biggest win)

### Evidence

`flutter_background_service_android` (v6.3.x) does this in
`BackgroundService.runService()`:

```java
@SuppressLint("WakelockTimeout")
private void runService() {
    ...
    getLock(getApplicationContext()).acquire();   // PARTIAL_WAKE_LOCK, no timeout
```

There is **no `release()` call anywhere in the plugin**. `BootReceiver` even
acquires it a *second* time on boot (the lock is reference-counted). So for as
long as the background service exists — i.e. always — the phone holds
`id.flutter.flutter_background_service.BackgroundService.Lock` and the CPU is
kept out of suspend, 24 hours a day. This is exactly the "app kept device
awake" pattern Android vitals flags, and it costs battery even when the car is
nowhere in range and the isolate is completely idle.

The wakelock is **not needed for this app**. Incoming BLE events (autoConnect
reconnects, GATT notifications) are delivered by the Bluetooth stack, which
wakes the CPU itself; a foreground service with `connectedDevice` type is
enough to keep the process alive. Millions of BLE companion apps run without a
permanent wakelock.

You can confirm this is the drain on your own phone before changing anything:

```bash
adb shell dumpsys batterystats --charged com.smartify_os.open_car_key_app | grep -A5 -i wake
# or full picture:
adb bugreport bugreport.zip   # → upload to Battery Historian, look for the partial wakelock row
```

There are two ways to fix this. They are **alternatives, not a sequence**: the
chosen path is Option B (migrate to `flutter_foreground_task`), which requires
no package modification at all. Option A is only worth doing if you want to
cheaply *prove* the wakelock is the drain before investing in the migration.

### Fix — Option A (optional, verification only): patch the plugin

Vendor a one-line-patched copy of the Android plugin:

1. Copy `~/.pub-cache/hosted/pub.dev/flutter_background_service_android-6.3.1/`
   to `MobileApp/packages/flutter_background_service_android/`.
2. In `android/src/main/java/id/flutter/flutter_background_service/BackgroundService.java`,
   delete the line in `runService()`:
   ```java
   getLock(getApplicationContext()).acquire();
   ```
3. In `BootReceiver.java`, delete the block:
   ```java
   if (BackgroundService.lockStatic == null) {
       BackgroundService.getLock(context).acquire();
   }
   ```
4. In `MobileApp/pubspec.yaml`:
   ```yaml
   dependency_overrides:
     flutter_background_service_android:
       path: packages/flutter_background_service_android
   ```
5. `flutter clean && flutter pub get`, rebuild, and compare a day of battery
   stats. Nothing else changes — same package, same APIs, same behavior; BLE
   events still arrive fine (verify: lock the phone, walk out of range and back,
   proximity unlock should still fire).

### Fix — Option B (chosen path): migrate to `flutter_foreground_task`

`flutter_foreground_task` (pub.dev, actively maintained) is built for exactly
this use case and lets you opt out of the wakelock. **Note that
`allowWakeLock` defaults to `true` — it must be set to `false` explicitly,
otherwise the migration keeps the exact same permanent wakelock:**

```dart
FlutterForegroundTask.init(
  androidNotificationOptions: AndroidNotificationOptions(
    channelId: 'background_service',
    channelName: 'Background Service',
    channelImportance: NotificationChannelImportance.LOW,
    ...
  ),
  iosNotificationOptions: const IOSNotificationOptions(),
  foregroundTaskOptions: ForegroundTaskOptions(
    eventAction: ForegroundTaskEventAction.nothing(), // no periodic tick — purely event-driven
    autoRunOnBoot: true,
    allowWakeLock: false,   // ← the whole point
    allowWifiLock: false,
  ),
);
```

Migration map (mechanical, all in `ble_background_service.dart` + callers):

| Current (`flutter_background_service`)                                   | New (`flutter_foreground_task`)                                                                                       |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `onStart(ServiceInstance service)` entrypoint                            | `TaskHandler.onStart(DateTime, TaskStarter)` in a class passed to `FlutterForegroundTask.startService(callback: ...)` |
| `service.on('method').listen(handler)` (bg side)                         | `TaskHandler.onReceiveData(Object data)` — dispatch on a `data['method']` field yourself                              |
| `service.invoke('event', map)` (bg → UI)                                 | `FlutterForegroundTask.sendDataToMain(map)`                                                                           |
| `FlutterBackgroundService().invoke('method', map)` (UI → bg)             | `FlutterForegroundTask.sendDataToTask(map)`                                                                           |
| `FlutterBackgroundService().on('event')` (UI side)                       | `FlutterForegroundTask.addTaskDataCallback((data) { ... })`                                                           |
| `service.stopSelf()`                                                     | `FlutterForegroundTask.stopService()`                                                                                 |
| `AndroidConfiguration(isForegroundMode: true, foregroundServiceType...)` | manifest: keep `android:foregroundServiceType="connectedDevice"` on the plugin's service entry                        |

Gotchas to test during migration:

- Payloads must be JSON-ish primitives. The `send_command` handler currently
  receives a `Uint8List? additionalData` — encode as `List<int>` (or base64)
  and decode on the other side.
- The home-screen widget path: `WidgetService.backgroundCallback` runs in
  home_widget's own isolate and today reaches the service via
  `FlutterBackgroundService().invoke(...)`. After migration it must use
  `FlutterForegroundTask.sendDataToTask(...)` — verify this works from that
  secondary isolate (it goes over a method channel, so call
  `DartPluginRegistrant.ensureInitialized()` first, which home_widget already
  does). **Test widget lock/unlock with the app killed.**
- Replace the request/response correlation helpers (`connect_result`,
  `send_command_result`) 1:1 — the pattern works the same, only transport
  changes.
- Keep the existing local-notifications code for updating notification 888;
  or use `FlutterForegroundTask.updateService(notificationTitle: ..., notificationText: ...)`
  and drop the manual notification handling entirely.

One behavioral difference to be aware of: `flutter_background_service` had an
AlarmManager-based `WatchdogReceiver` that respawned the service if it died.
`flutter_foreground_task` instead relies on the service being `START_STICKY`
plus `autoRunOnBoot`, which is normally sufficient for a foreground service —
but re-test that the service comes back after a low-memory kill and after a
reboot.

---

## 2. Connection parameters while connected (biggest win near the car)

### Evidence

The firmware advertises a *preferred* connection interval of **7.5–20 ms**
([bluetooth.cpp:587](../Firmware/LockController/src/bluetooth/bluetooth.cpp)):

```cpp
pAdvertising->setMinPreferred(0x06); // 7.5ms
pAdvertising->setMaxPreferred(0x10); // 20ms
```

Android mostly ignores that advertising hint and uses its default (BALANCED ≈
30–50 ms), and neither the firmware nor the app ever requests anything slower.
Result: while the phone is connected — which for a car parked at home is *all
evening and night* — the radio wakes ~20–30 times per second on both the phone
and the ESP32, for a link that transfers a handful of bytes per minute.

The proximity key does not need this: the ESP32 samples RSSI every 500 ms and
averages 5 samples (a 2.5 s window), so a 200 ms connection interval loses
nothing.

### Fix (firmware — authoritative, works with any app version)

In `MyServerCallbacks::onConnect` (bluetooth.cpp:194), request slower
parameters from the central. Do it *delayed* (~5 s after connect) so it doesn't
race Android's service discovery / MTU exchange and doesn't slow down the
initial GET_VERSION/GET_FEATURES/GET_DATA burst:

```cpp
// globals
unsigned long connParamUpdateAt = 0;
bool connParamsPending = false;

// in onConnect, after memcpy(peerAddress, ...):
connParamUpdateAt = millis() + 5000;
connParamsPending = true;

// in bluetoothLoop():
if (deviceConnected && connParamsPending && millis() >= connParamUpdateAt)
{
    connParamsPending = false;
    // 0xA0*1.25ms=200ms .. 0xC8*1.25ms=250ms, latency 1, timeout 600*10ms=6s
    pServer->updateConnParams(peerAddress, 0xA0, 0xC8, 1, 600);
    if (DEBUG_MODE)
        Serial.println("Requested low-power connection parameters");
}
```

Also fix the misleading advertising hints while you're there (they claim
7.5–20 ms; make them consistent — value is in 1.25 ms units):

```cpp
pAdvertising->setMinPreferred(0xA0); // 200ms
pAdvertising->setMaxPreferred(0xC8); // 250ms
```

Parameter reasoning:

- **Interval 200–250 ms**: ~6–10× fewer radio events than today. A queued
  lock/unlock command waits at most one interval, so widget/app commands gain
  ≤ 250 ms latency — imperceptible next to the existing HMAC/write round trip.
- **Slave latency 1**: lets the ESP32 skip every other event when it has
  nothing to say (halves ESP32 radio-on again). Keep it ≤ 1 so its RSSI
  samples (taken every 500 ms from received packets) stay fresh for the
  proximity logic. Do **not** use latency 3–4 here.
- **Supervision timeout 6 s**: disconnect-on-walk-away detection stays prompt
  (the "disconnected → proxy locked" path). Today's default is typically 5 s,
  so behavior is effectively unchanged.
- This changes **nothing** about connection *setup* speed: reconnect scanning
  (autoConnect) and the connection handshake are unaffected, so proximity
  unlock reaction time and the widget's "already connected" fast path stay the
  same.

Tune afterwards: if you ever feel proximity lock/unlock got sluggish, drop to
`0x50/0x78` (100–150 ms), latency 0 — still ~4× better than today.

### Optional app-side complement

After the setup burst in `_handleConnected` (right before the
`_ensureNotificationsWorking` call), you can additionally request low power
from the Android side — harmless if the firmware already did it:

```dart
await event.device.requestConnectionPriority(
    connectionPriorityRequest: ConnectionPriority.lowPower);
```

(`flutter_blue_plus` ≥ 1.35 has this; it maps to
`BluetoothGatt.requestConnectionPriority(CONNECTION_PRIORITY_LOW_POWER)`.)
If you implement the firmware side, treat this as optional polish. Don't rely
on it alone — the firmware request is the one that also saves the ESP32/car
battery, and it works even mid-connection.

---

## 3. Stop re-negotiating MTU + rediscovering services on every command

### Evidence

[ble_service.dart:134-141](../MobileApp/lib/services/ble_service.dart) — every
`sendCommand` does:

```dart
await device.requestMtu(64);
final services = await device.discoverServices();
```

`_handleConnected` already did both right after connecting
([ble_background_service.dart:406-414](../MobileApp/lib/services/ble_background_service.dart)).
So each lock/unlock/RSSI-poll pays two extra GATT transactions (radio-active
time) and the range-calibration page repeats them **every second**. With fix #2
(200 ms interval) each redundant round trip also costs real latency, so this
fix matters more after #2 lands.

### Fix

Cache the write characteristic per connection on `BackgroundVehicle`:

1. Add a field to `MobileApp/lib/types/background_vehicle.dart`:

   ```dart
   class BackgroundVehicle {
     BluetoothDevice device;
     VehicleData data;
     BluetoothCharacteristic? characteristic; // cached ffe1 handle, valid for current connection
     ...
   }
   ```

2. In `_handleConnected` (ble_background_service.dart), after finding
   `characteristic`, store it: `vehicle.characteristic = characteristic;`.

3. In `_handleDisconnected`, clear it: `vehicle.characteristic = null;`.
   (Also clear in the storage-reconcile path if you want belt-and-braces.)

4. In `BleService.sendCommand`, replace the `requestMtu` + `discoverServices` +
   `firstWhere` block with a lookup-and-fallback:

   ```dart
   final vehicle = BleBackgroundService.vehicles.firstWhere(
       (v) => v.device.remoteId.str == device.remoteId.str);

   var characteristic = vehicle.characteristic;
   if (characteristic == null || characteristic.device.isDisconnected) {
     // Fallback: connection exists but cache is cold (e.g. service restarted).
     final services = await device.discoverServices();
     final service = services.firstWhere(
         (s) => s.uuid == Guid('0000ffe0-0000-1000-8000-00805f9b34fb'));
     characteristic = service.characteristics.firstWhere(
         (c) => c.uuid == Guid('0000ffe1-0000-1000-8000-00805f9b34fb'));
     vehicle.characteristic = characteristic;
   }
   ```

   Delete the `requestMtu(64)` call here entirely — MTU is a per-connection
   property already negotiated in `_handleConnected`, re-requesting it per
   command is pure waste.

Side benefit: widget button presses get noticeably snappier (one write instead
of MTU + full discovery + write).

Note: `_ensureNotificationsWorking` re-running `discoverServices()` during its
retry loop is fine — that's a rare recovery path, leave it.

---

## 4. Small hygiene items

- **Stop logging secrets, and gate logs in release.**
  [ble_service.dart:117,180](../MobileApp/lib/services/ble_service.dart) prints
  the derived shared secret (and every HMAC payload) with `print()`, which is
  **not** stripped in release builds and lands in logcat where any local app
  with shell access can read it. Replace all `print` in `ble_service.dart` /
  `ble_background_service.dart` with `debugPrint`, and wrap the hot-path ones
  in `if (kDebugMode)`. Battery effect is minor; the security fix is the real
  reason.
- **Don't re-post identical notifications.** `_updateNotification` posts
  unconditionally; keep the last `(title, message)` in a static and early-return
  if unchanged. Each post wakes system_server/SystemUI briefly.
- **`_handleConnected` setup burst**: the five fixed `Future.delayed(200ms)`
  gaps between GET_VERSION/GET_FEATURES/GET_DATA/RSSI_TRIGGER/... are fine
  battery-wise, but once #3 lands you can shrink them (writes are acked;
  the delays exist only to let the ESP respond in between).
- **Unused permissions**: the manifest declares the CompanionDeviceManager
  permissions (`REQUEST_OBSERVE_COMPANION_DEVICE_PRESENCE`, etc.) but nothing
  uses them. Either remove them or actually adopt CDM (Appendix A).

---

## What NOT to change

- **Keep `connect(autoConnect: true)`.** It delegates reconnect scanning to the
  Bluetooth controller (hardware-filtered, duty-cycled). Any Dart-side
  scan/retry loop you could write would be strictly worse for battery. It is
  also what makes the widget "instantly connected" when you walk up to the car.
- **Keep the single-BLE-owner design** (all GATT traffic in the background
  isolate, UI talks to it via messages). Two isolates touching the same GATT
  connection would cause the exact duplicate-event bugs the code comments show
  were already fought and won.
- **Keep the foreground service itself** (for now). Android will kill a
  background-only process holding a GATT connection. The service isn't the
  problem — its wakelock is.

## Suggested order & verification

1. **#1** (migrate to `flutter_foreground_task`, `allowWakeLock: false`) —
   then measure 24 h with Battery Historian: no wakelock row from the service
   should remain and "CPU running" should become sparse while idle.
   Regression test: proximity unlock with screen off after 30+ min idle
   (Doze); widget lock/unlock with app killed; service restarts after a
   low-memory kill and after reboot.
2. **#2 firmware conn params** — flash, verify in `adb logcat | grep -i
   "connection.*interval\|onConnectionUpdated"` that the interval lands at
   ~160–200 (units of 1.25 ms). Regression test: walk-away lock timing and
   walk-up unlock timing feel unchanged; widget commands < 0.5 s.
3. **#3 characteristic cache** — regression test: rapid widget lock/unlock,
   range calibration page updates every second, reconnect after airplane-mode
   toggle still works (fallback path).
4. **#4 hygiene** whenever convenient (the secret-logging fix ideally with #1).

---

## Appendix A: CompanionDeviceManager architecture (optional, long-term)

The "zero idle cost" end-state on Android, if you ever want the service gone
entirely while the car is out of range:

1. On vehicle pairing, call `CompanionDeviceManager.associate()` with a
   `BluetoothLeDeviceFilter` for the vehicle's MAC (needs a small native
   Kotlin MethodChannel; the manifest permissions are already declared).
2. Implement a `CompanionDeviceService` (API 33+) and call
   `startObservingDevicePresence(mac)`. The OS then scans for the device at the
   system level — **no app process, no foreground service, no notification** —
   and wakes your service via `onDeviceAppeared`/`onDeviceDisappeared`.
3. In `onDeviceAppeared`: start the foreground service, connect
   *without* autoConnect (the device is in range right now), run the existing
   proximity logic unchanged.
4. On disconnect/disappear: stop the foreground service again.

Trade-offs, honestly:

- Presence detection latency is OS-controlled and can be slower (tens of
  seconds) than a controller-armed autoConnect, so proximity unlock might
  trigger later than today. Mitigation: on `onDeviceAppeared`, connect
  directly — you're already in range, so the remaining latency is one
  connection handshake.
- Companion association is per-device user consent (a system dialog at pairing
  time), and behavior varies more across OEMs than plain autoConnect.
- Meaningful native code (Kotlin service + channel into a headless Flutter
  engine). Do it only if items #1–#3 aren't enough — after the wakelock fix,
  an idle foreground service with an armed autoConnect costs very little.

## Appendix B: iOS

Current `IosConfiguration` (background fetch) will never provide a reliable
proximity key. The iOS-native path, for whenever you care:

- CoreBluetooth **state restoration** (`CBCentralManagerOptionRestoreIdentifierKey`)
  + `connectPeripheral` (pending connects are iOS's autoConnect equivalent and
  survive app termination; the OS relaunches the app on connection events).
- `flutter_blue_plus` does not support state restoration; this needs a small
  native Swift layer (or the `flutter_blue_plus` fork with restoration support)
  and an iOS-specific entry point instead of `flutter_background_service`.
- Everything in fixes #2 (firmware) and #3 benefits iOS automatically.
