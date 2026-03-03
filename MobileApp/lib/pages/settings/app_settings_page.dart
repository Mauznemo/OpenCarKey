import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../services/settings_service.dart';
import '../../styles/app_text_styles.dart';
import '../../widgets/split_button_dialog.dart';

class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Background Service toggle
        Card(
          color: colorScheme.secondaryContainer,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: SwitchListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              title: Text('Background Service',
                  style: textTheme.cardTitle(context)),
              subtitle: Text(
                'Enable Background Service',
              ),
              value: settingsState.backgroundService,
              onChanged: (value) {
                if (value) {
                  SettingsService.instance.setBackgroundService(true);
                } else {
                  showDialog(
                      context: context,
                      builder: (context) => SplitButtonDialog(
                            title: 'Are you sure?',
                            content: Text(
                                "If you disable the background service proximity key and the widget won't work and connection speed after opening the app might be slower."),
                            secondaryButton: SplitDialogButton(
                              label: 'Disable',
                              style: SplitDialogButtonStyle.red,
                              onPressed: () {
                                Navigator.of(context).pop();
                                SettingsService.instance
                                    .setBackgroundService(false);
                              },
                            ),
                            primaryButton: SplitDialogButton(
                              label: 'Cancel',
                              style: SplitDialogButtonStyle.filled,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ));
                }
              }),
        ),

        const SizedBox(height: 12),

        // Ignore Version Mismatch toggle
        Card(
          color: colorScheme.secondaryContainer,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: SwitchListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            title: Text('Ignore Version Mismatch',
                style: textTheme.cardTitle(context)),
            subtitle: Text(
              'Ignore Protocol Version Mismatch',
            ),
            value: settingsState.ignoreProtocolMismatch,
            onChanged: (value) {
              SettingsService.instance.setIgnoreProtocolMismatch(value);
            },
          ),
        ),

        const SizedBox(height: 12),

        // Show Mac Addresses toggle
        Card(
          color: colorScheme.secondaryContainer,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: SwitchListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            title:
                Text('Show Mac Addresses', style: textTheme.cardTitle(context)),
            subtitle: Text(
              'Show Mac Addresses in vehicle list',
            ),
            value: settingsState.showMacAddress,
            onChanged: (value) {
              SettingsService.instance.setShowMacAddress(value);
            },
          ),
        ),
      ]),
    );
  }
}
