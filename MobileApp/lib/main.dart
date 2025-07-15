import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'pages/home.dart';
import 'pages/range_calibration.dart';
import 'pages/settings.dart';
import 'services/ble_background_service.dart';
import 'utils/utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeApp();

  runApp(
    DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme =
            lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.blue);
        ColorScheme darkColorScheme = darkDynamic ??
            ColorScheme.fromSeed(
                seedColor: Colors.blue, brightness: Brightness.dark);

        return MainApp(
          lightColorScheme: lightColorScheme,
          darkColorScheme: darkColorScheme,
        );
      },
    ),
  );
}

class MainApp extends StatefulWidget {
  final ColorScheme lightColorScheme;
  final ColorScheme darkColorScheme;

  const MainApp({
    Key? key,
    required this.lightColorScheme,
    required this.darkColorScheme,
  }) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      BleBackgroundService.handleAppDetached();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme:
          ThemeData(colorScheme: widget.lightColorScheme, useMaterial3: true),
      darkTheme:
          ThemeData(colorScheme: widget.darkColorScheme, useMaterial3: true),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
        '/range_calibration': (context) => const RangeCalibrationPage(),
      },
    );
  }
}
