import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'notification_manager.dart';
import 'country_data.dart';

class AppGradients {
  static const List<LinearGradient> presets = [
    LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], begin: Alignment.topLeft, end: Alignment.bottomRight), // Purple
    LinearGradient(colors: [Color(0xFFF953C6), Color(0xFFB91D73)], begin: Alignment.topLeft, end: Alignment.bottomRight), // Pink
    LinearGradient(colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)], begin: Alignment.topLeft, end: Alignment.bottomRight), // Cyan-Green
    LinearGradient(colors: [Color(0xFFF5AF19), Color(0xFFF12711)], begin: Alignment.topLeft, end: Alignment.bottomRight), // Orange-Red
    LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)], begin: Alignment.topLeft, end: Alignment.bottomRight), // Emerald
  ];
}

enum CountryDisplayMode {
  flag,
  code,
  both
}

class PhoneNumberItem {
  final String id;
  final String label;
  final String number;
  final Country country;
  final DateTime expireDate;
  final int cycleDays;
  final List<int> remindBeforeDays;
  final int remindTimeHour;
  final int remindTimeMinute;
  final String remark;

  PhoneNumberItem({
    required this.id,
    required this.label,
    required this.number,
    required this.country,
    required this.expireDate,
    required this.cycleDays,
    required this.remindBeforeDays,
    this.remindTimeHour = 9,
    this.remindTimeMinute = 0,
    this.remark = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'number': number,
    'countryCode': country.code,
    'expireDate': expireDate.toIso8601String(),
    'cycleDays': cycleDays,
    'remindBeforeDays': remindBeforeDays,
    'remindTimeHour': remindTimeHour,
    'remindTimeMinute': remindTimeMinute,
    'remark': remark,
  };

  factory PhoneNumberItem.fromJson(Map<String, dynamic> json) {
    Country c = countriesAndRegions.firstWhere(
      (c) => c.code == json['countryCode'], 
      orElse: () => countriesAndRegions.first
    );
    return PhoneNumberItem(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      number: json['number'] ?? '',
      country: c,
      expireDate: DateTime.tryParse(json['expireDate'] ?? '') ?? DateTime.now(),
      cycleDays: json['cycleDays'] ?? 180,
      remindBeforeDays: List<int>.from(json['remindBeforeDays'] ?? [7]),
      remindTimeHour: json['remindTimeHour'] ?? 9,
      remindTimeMinute: json['remindTimeMinute'] ?? 0,
      remark: json['remark'] ?? '',
    );
  }

  PhoneNumberItem copyWith({
    String? id,
    String? label,
    String? number,
    Country? country,
    DateTime? expireDate,
    int? cycleDays,
    List<int>? remindBeforeDays,
    int? remindTimeHour,
    int? remindTimeMinute,
    String? remark,
  }) {
    return PhoneNumberItem(
      id: id ?? this.id,
      label: label ?? this.label,
      number: number ?? this.number,
      country: country ?? this.country,
      expireDate: expireDate ?? this.expireDate,
      cycleDays: cycleDays ?? this.cycleDays,
      remindBeforeDays: remindBeforeDays ?? this.remindBeforeDays,
      remindTimeHour: remindTimeHour ?? this.remindTimeHour,
      remindTimeMinute: remindTimeMinute ?? this.remindTimeMinute,
      remark: remark ?? this.remark,
    );
  }
}

class PhoneNumberManager extends ChangeNotifier {
  List<PhoneNumberItem> _items = [];
  List<PhoneNumberItem> _deletedItems = [];
  bool _initialized = false;

  List<PhoneNumberItem> get items => _items;
  List<PhoneNumberItem> get deletedItems => _deletedItems;

  PhoneNumberManager() {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final data = prefs.getString('phone_data');
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _items = decoded.map((e) => PhoneNumberItem.fromJson(e)).toList();
      } else {
        _items = [];
      }
    } catch (e) {
      _items = [];
    }

    try {
      final deletedData = prefs.getString('deleted_phone_data');
      if (deletedData != null) {
        final List<dynamic> decoded = jsonDecode(deletedData);
        _deletedItems = decoded.map((e) => PhoneNumberItem.fromJson(e)).toList();
      } else {
        _deletedItems = [];
      }
    } catch (e) {
      _deletedItems = [];
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _save() async {
    if (!_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString('phone_data', data);
    NotificationManager().scheduleExpirationNotifications(_items, SettingsManager());

    final deletedData = jsonEncode(_deletedItems.map((e) => e.toJson()).toList());
    await prefs.setString('deleted_phone_data', deletedData);

    final sm = SettingsManager();
    await sm.loadSettings();
    if (sm.webDavAutoSync) {
      sm.performAutoSync(); // run in background without awaiting
    }
  }

  void addItem(PhoneNumberItem item) {
    _items.add(item);
    _save();
    notifyListeners();
  }

  void removeItem(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _deletedItems.add(_items[index]);
      _items.removeAt(index);
      _save();
      notifyListeners();
    }
  }

  void restoreItem(String id) {
    final index = _deletedItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items.add(_deletedItems[index]);
      _deletedItems.removeAt(index);
      _save();
      notifyListeners();
    }
  }

  void permanentlyDeleteItem(String id) {
    _deletedItems.removeWhere((item) => item.id == id);
    _save();
    notifyListeners();
  }

  void updateItem(PhoneNumberItem updatedItem) {
    final index = _items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _items[index] = updatedItem;
      _save();
      notifyListeners();
    }
  }

  void resetCycle(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _items[index];
      final newExpireDate = DateTime.now().add(Duration(days: item.cycleDays));
      _items[index] = item.copyWith(expireDate: newExpireDate);
      _save();
      notifyListeners();
    }
  }
}

class SettingsManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  String _localeStr = 'zh';
  String get localeStr => _localeStr;

  Color _themeColor = Colors.blueAccent;
  Color get themeColor => _themeColor;

  int _gradientIndex = -1;
  int get gradientIndex => _gradientIndex;

  CountryDisplayMode _countryDisplayMode = CountryDisplayMode.both;
  CountryDisplayMode get countryDisplayMode => _countryDisplayMode;

  bool _copyIncludeDialCode = false;
  bool get copyIncludeDialCode => _copyIncludeDialCode;

  bool _privacyMask = false;
  bool get privacyMask => _privacyMask;

  bool _appLockEnabled = false;
  bool get appLockEnabled => _appLockEnabled;

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  String _appLockPin = '';
  String get appLockPin => _appLockPin;

  String webDavUrl = '';
  String webDavUser = '';
  String webDavPass = '';

  bool _webDavAutoSync = false;
  bool get webDavAutoSync => _webDavAutoSync;

  bool _isFirstLaunch = false;
  bool get isFirstLaunch => _isFirstLaunch;

  SettingsManager() {
    // Initialization is now manual via loadSettings()
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    if (_isFirstLaunch) {
      await prefs.setBool('isFirstLaunch', false);
    }

    final themeIdx = prefs.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeIdx];
    
    _localeStr = prefs.getString('locale') ?? 'zh';
    
    final colorVal = prefs.getInt('themeColor');
    if (colorVal != null) _themeColor = Color(colorVal);

    _gradientIndex = prefs.getInt('gradientIndex') ?? -1;

    final displayIdx = prefs.getInt('countryDisplayMode') ?? 2; // Default both
    if (displayIdx >= 0 && displayIdx < CountryDisplayMode.values.length) {
      _countryDisplayMode = CountryDisplayMode.values[displayIdx];
    } else {
      _countryDisplayMode = CountryDisplayMode.both;
    }

    _copyIncludeDialCode = prefs.getBool('copyIncludeDialCode') ?? false;
    _privacyMask = prefs.getBool('privacyMask') ?? false;
    _appLockEnabled = prefs.getBool('appLockEnabled') ?? false;
    _biometricEnabled = prefs.getBool('biometricEnabled') ?? false;
    _appLockPin = prefs.getString('appLockPin') ?? '';

    webDavUrl = prefs.getString('webDavUrl') ?? '';
    webDavUser = prefs.getString('webdav_user') ?? '';
    webDavPass = prefs.getString('webdav_pass') ?? '';
    _webDavAutoSync = prefs.getBool('webdav_autosync') ?? false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setCountryDisplayMode(CountryDisplayMode mode) async {
    _countryDisplayMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('countryDisplayMode', mode.index);
    notifyListeners();
  }

  Future<void> setLocale(String val) async {
    _localeStr = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', val);
    notifyListeners();
  }

  Future<void> setCopyIncludeDialCode(bool val) async {
    _copyIncludeDialCode = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('copyIncludeDialCode', val);
    notifyListeners();
  }

  Future<void> setPrivacyMask(bool val) async {
    _privacyMask = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacyMask', val);
    notifyListeners();
  }

  Future<void> setAppLock(bool enabled, String pin) async {
    _appLockEnabled = enabled;
    _appLockPin = pin;
    if (!enabled) {
      _biometricEnabled = false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appLockEnabled', enabled);
    await prefs.setString('appLockPin', pin);
    if (!enabled) {
      await prefs.setBool('biometricEnabled', false);
    }
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricEnabled', enabled);
    notifyListeners();
  }

  Future<void> setThemeGradient(int index, Color fallbackColor) async {
    _gradientIndex = index;
    _themeColor = fallbackColor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gradientIndex', index);
    await prefs.setInt('themeColor', fallbackColor.value);
    notifyListeners();
  }

  Future<void> setThemeColor(Color color) async {
    _gradientIndex = -1;
    _themeColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gradientIndex', -1);
    await prefs.setInt('themeColor', color.value);
    notifyListeners();
  }

  Future<void> saveWebDav(String url, String user, String pass) async {
    webDavUrl = url;
    webDavUser = user;
    webDavPass = pass;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', url);
    await prefs.setString('webdav_user', user);
    await prefs.setString('webdav_pass', pass);
  }

  Future<void> setWebDavAutoSync(bool val) async {
    _webDavAutoSync = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('webdav_autosync', val);
    notifyListeners();
  }

  Future<void> performAutoSync() async {
    if (!_webDavAutoSync || webDavUrl.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('phone_data') ?? '[]';
      
      final url = webDavUrl.endsWith('/') 
          ? '${webDavUrl}simvault_data.json' 
          : '$webDavUrl/simvault_data.json';
          
      final basicAuth = 'Basic ${base64Encode(utf8.encode('$webDavUser:$webDavPass'))}';
      
      await http.put(
        Uri.parse(url),
        headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
        body: data,
      );
    } catch (e) {
      debugPrint('Auto sync failed: $e');
    }
  }
}
