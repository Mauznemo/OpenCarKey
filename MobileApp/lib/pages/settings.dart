import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ble_background_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsPage> {
  late SharedPreferences prefs;
  bool proximityKey = false;
  bool vibrate = true;
  double triggerRange = 50;

  void loadPrefs() async {
    prefs = await SharedPreferences.getInstance();

    proximityKey = prefs.getBool('proximityKey') ?? false;
    triggerRange = prefs.getDouble('triggerRange') ?? 50;
    vibrate = prefs.getBool('vibrate') ?? true;

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Proximity Key',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(height: 10, color: Colors.grey),
            Row(
              children: [
                Switch(
                  value: proximityKey,
                  onChanged: (value) {
                    prefs.setBool('proximityKey', value);
                    BleBackgroundService.setProximityKey(value);

                    setState(() {
                      proximityKey = value;
                    });
                  },
                ),
                SizedBox(width: 10),
                const Text(
                  'Proximity Key Enabled',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text(
                  'Trigger Range',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context)
                  .copyWith(year2023: false, padding: EdgeInsets.all(8)),
              child: Slider(
                  value: triggerRange,
                  label: '${triggerRange.round().toString()}m',
                  divisions: 10,
                  min: 0,
                  max: 100,
                  onChanged: (value) {
                    prefs.setDouble('triggerRange', value);
                    BleBackgroundService.setProximityRange(value);

                    setState(() {
                      triggerRange = value;
                    });
                  }),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 10),
                      Text('Range is not calibrated yet'),
                    ],
                  ),
                  FilledButton(
                      onPressed: () {}, child: const Text('Calibrate Range')),
                ],
              ),
            ),
            Row(
              children: [
                Switch(
                  value: vibrate,
                  onChanged: (value) {
                    prefs.setBool('vibrate', value);
                    BleBackgroundService.setVibrate(value);

                    setState(() {
                      vibrate = value;
                    });
                  },
                ),
                SizedBox(width: 10),
                const Text(
                  'Vibrate on Proximity Key',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ]),
        ));
  }
}
