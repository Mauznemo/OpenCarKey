import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../services/settings_service.dart';
import '../../styles/app_text_styles.dart';
import '../range_calibration.dart';

class ProximityKeySettingsPage extends ConsumerStatefulWidget {
  const ProximityKeySettingsPage({super.key});

  @override
  ConsumerState<ProximityKeySettingsPage> createState() =>
      _ProximityKeySettingsPageState();
}

class _ProximityKeySettingsPageState
    extends ConsumerState<ProximityKeySettingsPage> {
  String convertToMinSecString(double value) {
    int totalSeconds = (value * 60).toInt();
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    if (minutes == 0) {
      return '$seconds sec';
    } else if (seconds == 0) {
      return '$minutes min';
    } else {
      return '$minutes min $seconds sec';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proximity Key Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Proximity Key toggle
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
              title: Text('Proximity Key', style: textTheme.cardTitle(context)),
              subtitle: Text(
                'Enable proximity key',
              ),
              value: settingsState.proximityKey,
              onChanged: (value) {
                SettingsService.instance.setProximityKey(value);
              },
            ),
          ),

          const SizedBox(height: 12),

          // Vibrate toggle
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
              title: Text('Vibrate', style: textTheme.cardTitle(context)),
              subtitle: Text(
                'Vibrate on Proximity Key',
              ),
              value: settingsState.vibrate,
              onChanged: (value) {
                SettingsService.instance.setVibrate(value);
              },
            ),
          ),

          const SizedBox(height: 12),

          // Trigger Range
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    child: Text(
                      'Trigger Range',
                      style: textTheme.cardTitle(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        settingsState.triggerStrength == -200
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          settingsState.triggerStrength == -200
                              ? 'Range is not set yet (using connect and disconnect)'
                              : 'Range is set to ${settingsState.triggerStrength.toStringAsFixed(2)} dBm',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message:
                              'Set a signal strength to lock and unlock at',
                          showDuration: const Duration(seconds: 5),
                          child: FilledButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RangeCalibrationPage(),
                                ),
                              );
                            },
                            child: const Text('Set Range'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Tooltip(
                          message:
                              'Use connect and disconnect instead of signal strength',
                          showDuration: const Duration(seconds: 5),
                          child: FilledButton(
                            onPressed: () {
                              SettingsService.instance.setTriggerStrength(-200);
                            },
                            child: const Text('Reset Range'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Deadzone Slider
          Card(
            color: colorScheme.secondaryContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text('Dead Zone', style: textTheme.cardTitle(context)),
                        Tooltip(
                          message:
                              'Range in which nothing will happen. Eg. 5m: After the car was locked you have to get around 5m closer to it to unlock again.'
                              ' This is to prevent rapid locking and unlocking if you are at the exact trigger distance',
                          triggerMode: TooltipTriggerMode.tap,
                          showDuration: const Duration(minutes: 1),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                        year2023: false,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        inactiveTrackColor:
                            colorScheme.primary.withValues(alpha: 0.2)),
                    child: Slider(
                        value: settingsState.deadZone,
                        min: 1,
                        max: 15,
                        divisions: 14,
                        label:
                            '~${settingsState.deadZone.toInt().toString()} m',
                        onChanged: (value) {
                          ref
                              .read(settingsProvider.notifier)
                              .setDeadZone(value);
                        },
                        onChangeEnd: (value) {
                          SettingsService.instance.setDeadZone(value);
                        }),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Proximity Cooldown Slider
          Card(
            color: colorScheme.secondaryContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text('Proximity Cooldown',
                            style: textTheme.cardTitle(context)),
                        Tooltip(
                          message:
                              'Time to not unlock/lock again after locking/unlocking. To prevent rapid locking and unlocking while getting close or going away.',
                          triggerMode: TooltipTriggerMode.tap,
                          showDuration: const Duration(minutes: 1),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                        year2023: false,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        inactiveTrackColor:
                            colorScheme.primary.withValues(alpha: 0.2)),
                    child: Slider(
                      value: settingsState.proximityCooldown,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      label: convertToMinSecString(
                          settingsState.proximityCooldown),
                      onChanged: (value) {
                        ref
                            .read(settingsProvider.notifier)
                            .setProximityCooldown(value);
                      },
                      onChangeEnd: (value) {
                        SettingsService.instance.setProximityCooldown(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
