import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home.dart';
import 'pages/range_calibration.dart';
import 'pages/settings.dart';
import 'services/ble_background_service.dart';
import 'services/theme_service.dart';
import 'utils/utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeService().init();
  await initializeApp();

  runApp(
    ProviderScope(child: MainApp()),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
  });

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
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      return ListenableBuilder(
          listenable: ThemeService(),
          builder: (context, child) {
            final themeService = ThemeService();
            final colorScheme = themeService.getCurrentColorScheme(
              dynamicLight: lightDynamic,
              dynamicDark: darkDynamic,
            );
            return MaterialApp(
              scaffoldMessengerKey: scaffoldMessengerKey,
              theme: ThemeData(colorScheme: colorScheme, useMaterial3: true),
              darkTheme:
                  ThemeData(colorScheme: colorScheme, useMaterial3: true),
              themeMode: ThemeMode.system,
              home: const HomePage(),
            );
          });
    });
  }
}
