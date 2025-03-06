import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsPage> {
  bool proximityKey = false;
  double triggerRange = 100;

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
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                inactiveTrackColor: Colors.white54,
              ),
              child: Slider(
                  value: triggerRange,
                  label: '${triggerRange.round().toString()}m',
                  divisions: 10,
                  min: 0,
                  max: 100,
                  onChanged: (value) {
                    setState(() {
                      triggerRange = value;
                    });
                  }),
            )
          ]),
        ));
  }
}
