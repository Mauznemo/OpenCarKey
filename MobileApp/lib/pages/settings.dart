import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';
import '../services/settings_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsPage> {
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
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Proximity Key',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        )),
              ),
              const Divider(height: 10, color: Colors.grey),
              Row(
                children: [
                  Switch(
                    value: settingsState.proximityKey,
                    onChanged: (value) {
                      SettingsService.instance.setProximityKey(value);
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
              Row(
                children: [
                  Switch(
                    value: settingsState.vibrate,
                    onChanged: (value) {
                      SettingsService.instance.setVibrate(value);
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    settingsState.triggerStrength == -200
                        ? Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded),
                              const SizedBox(width: 10),
                              Text(
                                  'Range is not set yet (using connect and disconnect)'),
                            ],
                          )
                        : Row(
                            children: [
                              const Icon(Icons.check_circle_outline),
                              const SizedBox(width: 10),
                              Text(
                                  'Range is set to ${settingsState.triggerStrength.toStringAsFixed(2)} dBm'),
                            ],
                          ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Tooltip(
                    message: 'Set a signal strength to lock and unlock at',
                    showDuration: const Duration(seconds: 5),
                    child: FilledButton(
                        onPressed: () async {
                          await Navigator.pushNamed(
                              context, '/range_calibration');
                        },
                        child: const Text('Set Range')),
                  ),
                  Tooltip(
                    message:
                        'Use connect and disconnect instead of signal strength',
                    showDuration: const Duration(seconds: 5),
                    child: FilledButton(
                        onPressed: () {
                          SettingsService.instance.setTriggerStrength(-200);
                        },
                        child: const Text('Reset Range')),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Dead Zone',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                Tooltip(
                    message:
                        'Range in which nothing will happen. Eg. 5m: After the car was locked you have to get around 5m closer to it to unlock again. This is to prevent rapid locking and unlocking if you are at the exact trigger distance',
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(minutes: 2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.info_outline),
                    )),
              ]),
              SliderTheme(
                  data: SliderTheme.of(context)
                      .copyWith(year2023: false, padding: EdgeInsets.all(8)),
                  child: Slider(
                      value: settingsState.deadZone,
                      min: 1,
                      max: 15,
                      divisions: 14,
                      label: '~${settingsState.deadZone.toInt().toString()} m',
                      onChanged: (value) {
                        SettingsService.instance.setDeadZone(value);
                      })),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Proximity Cooldown',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                Tooltip(
                    message:
                        'Time to not unlock/lock again after locking/unlocking. To prevent rapid locking and unlocking while getting close or going away.',
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(minutes: 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.info_outline),
                    )),
              ]),
              SliderTheme(
                  data: SliderTheme.of(context)
                      .copyWith(year2023: false, padding: EdgeInsets.all(8)),
                  child: Slider(
                      value: settingsState.proximityCooldown,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      label: convertToMinSecString(
                          settingsState.proximityCooldown),
                      onChanged: (value) {
                        SettingsService.instance.setProximityCooldown(value);
                      })),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('App',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        )),
              ),
              const Divider(height: 10, color: Colors.grey),
              Row(
                children: [
                  Switch(
                    value: settingsState.backgroundService,
                    onChanged: (value) {
                      if (value) {
                        SettingsService.instance.setBackgroundService(true);
                      } else {
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: const Text('Warning'),
                                  content: Text(
                                      "If you disable the background service proximity key and the widget won't work and connection speed after opening the app might be slower."),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          SettingsService.instance
                                              .setBackgroundService(false);
                                        },
                                        child: const Text('Disable')),
                                    TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          SettingsService.instance
                                              .setBackgroundService(true);
                                        },
                                        child: const Text('Cancel'))
                                  ],
                                ));
                      }
                    },
                  ),
                  SizedBox(width: 10),
                  const Text(
                    'Background Service Enabled',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Switch(
                    value: settingsState.ignoreProtocolMismatch,
                    onChanged: (value) {
                      SettingsService.instance.setIgnoreProtocolMismatch(value);
                    },
                  ),
                  SizedBox(width: 10),
                  const Text(
                    'Ignore Protocol Version Mismatch',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Switch(
                    value: settingsState.showMacAddress,
                    onChanged: (value) {
                      SettingsService.instance.setShowMacAddress(value);
                    },
                  ),
                  SizedBox(width: 10),
                  const Text(
                    'Show Mac Addresses',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 20),
              FilledButton.icon(
                icon: Icon(Icons.favorite),
                label: Text('Support Project'),
                onPressed: () async {
                  await launchUrl(Uri.parse(
                      'https://smartify-os.com?support&code-url=https://github.com/Mauznemo/OpenCarKey'));
                },
              ),
            ]),
          ),
        ));
  }
}
