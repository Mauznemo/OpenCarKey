import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/color_helper.dart';
import 'settings/app_settings_page.dart';
import 'settings/proximity_key_settings_page.dart';
import 'settings/theme_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Proximity Key Tile
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(100),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.key,
                        color: ColorHelper.mixedPrimary(
                          context,
                          Colors.green,
                          0.5,
                        ),
                        size: 28,
                      ),
                    ),
                    title: Text(
                      'Proximity Key',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Manage proximity key settings',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ProximityKeySettingsPage(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // App Design Tile
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withAlpha(100),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.color_lens,
                        color: ColorHelper.mixedPrimary(
                          context,
                          Colors.purple,
                          0.5,
                        ),
                        size: 28,
                      ),
                    ),
                    title: Text(
                      'App Design',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Change appearance of the app',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ThemeSettingsPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // App Tile
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.lime.withAlpha(100),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.miscellaneous_services,
                        color: ColorHelper.mixedPrimary(
                          context,
                          Colors.lime,
                          0.5,
                        ),
                        size: 28,
                      ),
                    ),
                    title: Text(
                      'App',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Manage app related settings',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppSettingsPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Suppoert Tile
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(100),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: ColorHelper.mixedPrimary(
                          context,
                          Colors.red,
                          0.5,
                        ),
                        size: 28,
                      ),
                    ),
                    title: Text(
                      'Support',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Support development',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () async {
                      await launchUrl(Uri.parse(
                          'https://smartify-os.com?support&code-url=https://github.com/Mauznemo/OpenCarKey'));
                    },
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Text(
              'v$_version',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withAlpha(120),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
