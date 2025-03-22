import 'package:flutter/material.dart';

import '../services/ble_background_service.dart';

class DisableForTimerWidget {
  static int days = 0;
  static int hours = 5;
  static int minutes = 0;

  static Future<bool> showTimeInputDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Proximity Key for'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Days',
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: '0'),
                    onChanged: (value) {
                      days = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Hours',
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: '5'),
                    onChanged: (value) {
                      hours = int.tryParse(value) ?? 5;
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: 'Minutes',
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: '0'),
                    onChanged: (value) {
                      minutes = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              DateTime endTime = DateTime.now()
                  .add(Duration(minutes: minutes, hours: hours, days: days));
              BleBackgroundService.enableProximityKeyAt(endTime);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
