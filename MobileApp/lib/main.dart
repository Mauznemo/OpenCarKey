import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'pages/home.dart';
import 'pages/range_calibration.dart';
import 'pages/settings.dart';
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

        return MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: ThemeData(colorScheme: lightColorScheme, useMaterial3: true),
          darkTheme:
              ThemeData(colorScheme: darkColorScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          initialRoute: '/',
          routes: {
            '/': (context) => const HomePage(),
            '/settings': (context) => const SettingsPage(),
            '/range_calibration': (context) => const RangeCalibrationPage(),
          },
        );
      },
    ),
  );
}
