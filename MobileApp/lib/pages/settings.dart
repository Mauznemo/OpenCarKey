import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  double triggerStrength = -200;
  double deadZone = 4;
  double proximityCooldown = 1; //in min
  bool backgroundService = true;
  bool ignoreProtocolMismatch = false;
  bool showMacAddress = true;

  void loadPrefs() async {
    prefs = await SharedPreferences.getInstance();

    proximityKey = prefs.getBool('proximityKey') ?? false;
    triggerStrength = prefs.getDouble('triggerStrength') ?? -200;
    vibrate = prefs.getBool('vibrate') ?? true;
    deadZone = prefs.getDouble('deadZone') ?? 4;
    proximityCooldown = prefs.getDouble('proximityCooldown') ?? 1;
    backgroundService = prefs.getBool('backgroundService') ?? true;
    ignoreProtocolMismatch = prefs.getBool('ignoreProtocolMismatch') ?? false;
    showMacAddress = prefs.getBool('showMacAddress') ?? true;

    setState(() {});
  }

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
                    triggerStrength == -200
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
                                  'Range is set to ${triggerStrength.toStringAsFixed(2)} dBm'),
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
                          triggerStrength =
                              prefs.getDouble('triggerStrength') ?? -200;
                          setState(() {});
                        },
                        child: const Text('Set Range')),
                  ),
                  Tooltip(
                    message:
                        'Use connect and disconnect instead of signal strength',
                    showDuration: const Duration(seconds: 5),
                    child: FilledButton(
                        onPressed: () {
                          prefs.setDouble('triggerStrength', -200);
                          BleBackgroundService.setProximityStrength(-200);
                          triggerStrength = -200;

                          setState(() {});
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
                      value: deadZone,
                      min: 1,
                      max: 15,
                      divisions: 14,
                      label: '~${deadZone.toInt().toString()} m',
                      onChanged: (value) {
                        prefs.setDouble('deadZone', value);
                        BleBackgroundService.setDeadZone(value);

                        setState(() {
                          deadZone = value;
                        });
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
                      value: proximityCooldown,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      label: convertToMinSecString(proximityCooldown),
                      onChanged: (value) {
                        prefs.setDouble('proximityCooldown', value);
                        BleBackgroundService.setProximityCooldown(value);

                        setState(() {
                          proximityCooldown = value;
                        });
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
                    value: backgroundService,
                    onChanged: (value) {
                      backgroundService = value;
                      if (value) {
                        BleBackgroundService.enableBackgroundService();
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
                                          BleBackgroundService
                                              .disableBackgroundService();
                                        },
                                        child: const Text('Disable')),
                                    TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          backgroundService = true;
                                          setState(() {});
                                        },
                                        child: const Text('Cancel'))
                                  ],
                                ));
                        setState(() {});
                      }
                      prefs.setBool('backgroundService', backgroundService);
                      setState(() {});
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
                    value: ignoreProtocolMismatch,
                    onChanged: (value) {
                      ignoreProtocolMismatch = value;
                      prefs.setBool('ignoreProtocolMismatch', value);
                      setState(() {});
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
                    value: showMacAddress,
                    onChanged: (value) {
                      showMacAddress = value;
                      prefs.setBool('showMacAddress', value);
                      setState(() {});
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
