import 'package:flutter_test/flutter_test.dart';
import 'package:open_car_key_app/services/ble_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The firmware treats a reused counter as a replay, and a counter more than
/// 64 ahead as invalid. These tests make sure the app never hands out the same
/// counter twice, no matter what the stored value does.
void main() {
  const mac = 'AA:BB:CC:DD:EE:FF';
  const key = 'counter_$mac';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BleService.clearCounterCacheForTesting();
  });

  test('starts at 0 and counts up', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(await BleService.nextCounter(prefs, mac), 0);
    expect(await BleService.nextCounter(prefs, mac), 1);
    expect(await BleService.nextCounter(prefs, mac), 2);
    expect(prefs.getInt(key), 2);
  });

  test('continues from the stored counter after a restart', () async {
    SharedPreferences.setMockInitialValues({key: 41});
    final prefs = await SharedPreferences.getInstance();
    expect(await BleService.nextCounter(prefs, mac), 42);
  });

  test('never goes back when the stored value is older', () async {
    // A prefs reload in another isolate can bring back an older snapshot
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 10; i++) {
      await BleService.nextCounter(prefs, mac);
    }
    await prefs.setInt(key, 3);
    expect(await BleService.nextCounter(prefs, mac), 10);
    expect(prefs.getInt(key), 10);
  });

  test('a newer stored value wins over the cached one', () async {
    final prefs = await SharedPreferences.getInstance();
    await BleService.nextCounter(prefs, mac);
    await prefs.setInt(key, 20);
    expect(await BleService.nextCounter(prefs, mac), 21);
  });

  test('counters are separate per vehicle', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(await BleService.nextCounter(prefs, mac), 0);
    expect(await BleService.nextCounter(prefs, mac), 1);
    expect(await BleService.nextCounter(prefs, '11:22:33:44:55:66'), 0);
  });

  test('concurrent calls never return the same counter', () async {
    final prefs = await SharedPreferences.getInstance();
    final counters = await Future.wait(
        List.generate(50, (_) => BleService.nextCounter(prefs, mac)));
    expect(counters.toSet(), hasLength(50));
  });
}
