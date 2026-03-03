import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../../services/theme_service.dart';
import '../../styles/app_text_styles.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  bool _supportsDynamicColor = false;

  Future<void> _checkSupportsDynamicColor() async {
    final corePalette = await DynamicColorPlugin.getCorePalette();
    _supportsDynamicColor = corePalette != null;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _checkSupportsDynamicColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Theme Settings',
        ),
      ),
      body: ListenableBuilder(
        listenable: ThemeService(),
        builder: (context, child) {
          final themeService = ThemeService();
          final textTheme = Theme.of(context).textTheme;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Custom theme selector
              if (themeService.themeType == AppThemeType.custom) ...[
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Text('App Themes',
                              style: textTheme.cardTitle(context)),
                        ),
                        ...CustomThemeColor.values.map((color) {
                          return RadioListTile<CustomThemeColor>(
                            title: Text(
                                '${color.name[0].toUpperCase()}${color.name.substring(1)}'),
                            value: color,
                            groupValue: themeService.customThemeColor,
                            onChanged: (value) {
                              if (value != null) {
                                themeService.setCustomThemeColor(value);
                              }
                            },
                            secondary: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: ThemeService.getThemeColor(color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Light theme toggle
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: SwitchListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  title: Text(
                    'Enable Light Theme',
                    style: textTheme.cardTitle(context),
                  ),
                  subtitle: Text(
                    'Use light theme instead of dark theme',
                  ),
                  value: themeService.brightness == ThemeBrightness.light,
                  onChanged: (value) {
                    themeService.setBrightness(
                      value ? ThemeBrightness.light : ThemeBrightness.dark,
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              if (_supportsDynamicColor) ...[
                // Dynamic theme toggle
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: SwitchListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    title: Text(
                      'User Device Theme',
                      style: textTheme.cardTitle(context),
                    ),
                    subtitle: Text(
                      'Use dynamic device theme',
                    ),
                    value: themeService.themeType == AppThemeType.dynamic,
                    onChanged: (value) {
                      themeService.setThemeType(
                        value ? AppThemeType.dynamic : AppThemeType.custom,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}
