import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeOption {
  final String id;
  final String name;
  final String subtitle;
  final String icon;
  final Color primary;
  final Color secondary;
  final Color lightBg;
  final Color badgeBg;
  final Color badgeText;

  const AppThemeOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.lightBg,
    required this.badgeBg,
    required this.badgeText,
  });
}

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const List<AppThemeOption> themes = [
    AppThemeOption(
      id: 'orange',
      name: 'Sunset Orange',
      subtitle: 'Where Is My Train & Kolkata transit vibe',
      icon: '🌅',
      primary: Color(0xFFE65100),
      secondary: Color(0xFFEF6C00),
      lightBg: Color(0xFFFFF3E0),
      badgeBg: Color(0xFFFFE0B2),
      badgeText: Color(0xFFBF360C),
    ),
    AppThemeOption(
      id: 'teal',
      name: 'Kolkata Teal',
      subtitle: 'Calm classic municipal green',
      icon: '🌲',
      primary: Color(0xFF00695C),
      secondary: Color(0xFF00897B),
      lightBg: Color(0xFFE0F2F1),
      badgeBg: Color(0xFFB2DFDB),
      badgeText: Color(0xFF004D40),
    ),
    AppThemeOption(
      id: 'blue',
      name: 'Metro Blue',
      subtitle: 'Line 1 & AC Electric bus fleet',
      icon: '🚇',
      primary: Color(0xFF1565C0),
      secondary: Color(0xFF1E88E5),
      lightBg: Color(0xFFE3F2FD),
      badgeBg: Color(0xFFBBDEFB),
      badgeText: Color(0xFF0D47A1),
    ),
    AppThemeOption(
      id: 'dark',
      name: 'Midnight Dark',
      subtitle: 'High contrast transit theme',
      icon: '🌑',
      primary: Color(0xFF263238),
      secondary: Color(0xFF37474F),
      lightBg: Color(0xFFECEFF1),
      badgeBg: Color(0xFFCFD8DC),
      badgeText: Color(0xFF212121),
    ),
  ];

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  String _currentThemeId = 'orange'; // Default: Orange
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  String _lastFromStop = 'Howrah Station';
  String _lastToStop = 'Sector V';
  String _lastBusNo = '215A';

  String get currentThemeId => _currentThemeId;
  AppThemeOption get currentTheme =>
      themes.firstWhere((t) => t.id == _currentThemeId, orElse: () => themes.first);
  bool get notificationsEnabled => _notificationsEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  String get lastFromStop => _lastFromStop;
  String get lastToStop => _lastToStop;
  String get lastBusNo => _lastBusNo;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    _currentThemeId = _prefs.getString('app_theme_id') ?? 'orange';
    _notificationsEnabled = _prefs.getBool('pref_notifications_enabled') ?? true;
    _vibrationEnabled = _prefs.getBool('pref_vibration_enabled') ?? true;
    _lastFromStop = _prefs.getString('last_from_stop') ?? 'Howrah Station';
    _lastToStop = _prefs.getString('last_to_stop') ?? 'Sector V';
    _lastBusNo = _prefs.getString('last_bus_no') ?? '215A';

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setTheme(String themeId) async {
    _currentThemeId = themeId;
    await _prefs.setString('app_theme_id', themeId);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _prefs.setBool('pref_notifications_enabled', value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _prefs.setBool('pref_vibration_enabled', value);
    notifyListeners();
  }

  Future<void> saveLastSearch(String from, String to) async {
    if (from.trim().isNotEmpty) {
      _lastFromStop = from.trim();
      await _prefs.setString('last_from_stop', _lastFromStop);
    }
    if (to.trim().isNotEmpty) {
      _lastToStop = to.trim();
      await _prefs.setString('last_to_stop', _lastToStop);
    }
    notifyListeners();
  }

  Future<void> saveLastBusNo(String busNo) async {
    if (busNo.trim().isNotEmpty) {
      _lastBusNo = busNo.trim();
      await _prefs.setString('last_bus_no', _lastBusNo);
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    await _prefs.remove('last_from_stop');
    await _prefs.remove('last_to_stop');
    await _prefs.remove('last_bus_no');
    _lastFromStop = 'Howrah Station';
    _lastToStop = 'Sector V';
    _lastBusNo = '215A';
    notifyListeners();
  }
}

