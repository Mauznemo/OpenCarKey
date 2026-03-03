import 'package:flutter/material.dart';

import '../services/ble_background_service.dart';
import '../services/settings_service.dart';
import '../widgets/stacked_button_dialog.dart';

class ProtocolVersionMismatchDialog {
  static void show(
      BuildContext context, String vehicleName, String? deviceProtocolVersion) {
    showDialog(
        context: context,
        builder: (context) => StackedButtonDialog(
              title: 'Protocol Version Mismatch',
              content: Text(
                  '$vehicleName is on protocol version $deviceProtocolVersion and the app is on ${BleBackgroundService.PROTOCOL_VERSION}.'
                  ' Everything you need might still work, but if not please update your ESP32/app to the newest version.'),
              buttons: [
                StackedDialogButton(
                    onPressed: Navigator.of(context).pop,
                    label: 'Okay',
                    style: StackedDialogButtonStyle.filled),
                StackedDialogButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      SettingsService.instance.setIgnoreProtocolMismatch(true);
                    },
                    label: "Don't show this again",
                    style: StackedDialogButtonStyle.outlined),
              ],
            ));
  }
}
