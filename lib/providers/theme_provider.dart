import 'package:gps_tracker/config/imports.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isDarkMode = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode;

  static const String _themeKey = 'theme_mode';

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey) ?? 'system';

      switch (savedTheme) {
        case 'dark':
          _themeMode = ThemeMode.dark;
          _isDarkMode = true;
          break;
        case 'light':
          _themeMode = ThemeMode.light;
          _isDarkMode = false;
          break;
        default:
          _themeMode = ThemeMode.system;
          _isDarkMode = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading theme: $e");
    }
  }

  Future<void> setDarkMode() async {
    _themeMode = ThemeMode.dark;
    _isDarkMode = true;
    notifyListeners();
    await _saveTheme('dark');
  }

  Future<void> setLightMode() async {
    _themeMode = ThemeMode.light;
    _isDarkMode = false;
    notifyListeners();
    await _saveTheme('light');
  }

  Future<void> setSystemMode() async {
    _themeMode = ThemeMode.system;
    _isDarkMode = false;
    notifyListeners();
    await _saveTheme('system');
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setLightMode();
    } else {
      await setDarkMode();
    }
  }

  Future<void> _saveTheme(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode);
    } catch (e) {
      debugPrint("Error saving theme: $e");
    }
  }

  IconData get themeIcon {
    switch (_themeMode) {
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
      default:
        return Icons.settings_brightness;
    }
  }

  String get themeName {
    switch (_themeMode) {
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.light:
        return 'Light Mode';
      default:
        return 'System Default';
    }
  }
}
