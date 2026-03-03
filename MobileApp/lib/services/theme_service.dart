import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { custom, dynamic }

enum CustomThemeColor { purple, blue, green, orange }

enum ThemeBrightness { light, dark }

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  AppThemeType _themeType = AppThemeType.custom;
  CustomThemeColor _customThemeColor = CustomThemeColor.purple;
  ThemeBrightness _brightness = ThemeBrightness.dark;

  AppThemeType get themeType => _themeType;
  CustomThemeColor get customThemeColor => _customThemeColor;
  ThemeBrightness get brightness => _brightness;

  static const Map<CustomThemeColor, Color> _themeColors = {
    CustomThemeColor.purple: Color.fromARGB(255, 155, 60, 218),
    CustomThemeColor.blue: Color.fromARGB(255, 19, 116, 252),
    CustomThemeColor.green: Color(0xFF4CAF50),
    CustomThemeColor.orange: Color(0xFFFF9800),
  };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _themeType = AppThemeType.values[prefs.getInt('themeType') ?? 0];
    _customThemeColor =
        CustomThemeColor.values[prefs.getInt('customThemeColor') ?? 0];
    _brightness = ThemeBrightness.values[prefs.getInt('themeBrightness') ?? 1];
    notifyListeners();
  }

  Future<void> setThemeType(AppThemeType type) async {
    _themeType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeType', type.index);
    notifyListeners();
  }

  Future<void> setCustomThemeColor(CustomThemeColor color) async {
    _customThemeColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('customThemeColor', color.index);
    notifyListeners();
  }

  Future<void> setBrightness(ThemeBrightness brightness) async {
    _brightness = brightness;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeBrightness', brightness.index);
    notifyListeners();
  }

  ColorScheme getCustomColorScheme(CustomThemeColor color) {
    return ColorScheme.fromSeed(
      seedColor: _themeColors[color]!,
      brightness: _brightness == ThemeBrightness.dark
          ? Brightness.dark
          : Brightness.light,
    );
  }

  ColorScheme getCurrentColorScheme({
    ColorScheme? dynamicLight,
    ColorScheme? dynamicDark,
  }) {
    if (_themeType == AppThemeType.dynamic) {
      if (_brightness == ThemeBrightness.dark && dynamicDark != null) {
        return dynamicDark;
      } else if (_brightness == ThemeBrightness.light && dynamicLight != null) {
        return dynamicLight;
      }
    }
    return getCustomColorScheme(_customThemeColor);
  }

  static Color getThemeColor(CustomThemeColor color) {
    return _themeColors[color]!;
  }
}
