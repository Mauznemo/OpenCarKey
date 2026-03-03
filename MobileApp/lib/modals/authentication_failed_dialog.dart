import 'package:flutter/material.dart';

import '../services/ble_service.dart';
import '../widgets/stacked_button_dialog.dart';

class AuthenticationFailedDialog {
  static void show(BuildContext context, Esp32ResponseDate data) {
    showDialog(
        context: context,
        builder: (context) => StackedButtonDialog(
              title: 'Authentication Failed',
              content: Text(
                  'Invalid HMAC/rolling code for device ${data.macAddress}.'
                  ' Please remove the vehicle then hold down the button labeled BOOT on yor ESP32 for 5 sec and re-add it to the app.'),
              buttons: [
                StackedDialogButton(
                    onPressed: Navigator.of(context).pop,
                    label: 'Okay',
                    style: StackedDialogButtonStyle.filled),
              ],
            ));
  }
}
