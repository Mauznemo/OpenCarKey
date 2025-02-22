import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'pages/home.dart';
import 'utils/utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeApp();

  runApp(
    DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Fallback to default color schemes if dynamic colors are not available
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
          // Automatically switch based on system settings
          initialRoute: "/",
          routes: {
            "/": (context) => const HomePage(),
          },
        );
      },
    ),
  );
}
