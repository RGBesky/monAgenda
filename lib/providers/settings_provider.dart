import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';

class AppSettings {
  final String? infomaniakUsername;
  final String? infomaniakAppPassword;
  final String? infomaniakCalendarUrl;
  final String? notionApiKey;
  final String theme;
  final String defaultView;
  final String firstDayOfWeek;
  final int defaultReminderMinutes;
  final int morningSummaryHour;
  final int morningSummaryMinute;
  final bool morningSummaryEnabled;
  final bool reminderEnabled;
  final String? pythonScriptPath;
  final String? pptTemplatePath;
  final String? kDriveId;
  final bool isOffline;
  // Météo
  final String weatherCity;
  final double weatherLatitude;
  final double weatherLongitude;

  const AppSettings({
    this.infomaniakUsername,
    this.infomaniakAppPassword,
    this.infomaniakCalendarUrl,
    this.notionApiKey,
    this.theme = AppConstants.themeAuto,
    this.defaultView = AppConstants.viewWeek,
    this.firstDayOfWeek = AppConstants.firstDayMonday,
    this.defaultReminderMinutes = AppConstants.defaultReminderMinutes,
    this.morningSummaryHour = AppConstants.defaultMorningSummaryHour,
    this.morningSummaryMinute = AppConstants.defaultMorningSummaryMinute,
    this.morningSummaryEnabled = true,
    this.reminderEnabled = true,
    this.pythonScriptPath,
    this.pptTemplatePath,
    this.kDriveId,
    this.isOffline = false,
    this.weatherCity = 'Genève',
    this.weatherLatitude = 46.2044,
    this.weatherLongitude = 6.1432,
  });

  AppSettings copyWith({
    String? infomaniakUsername,
    String? infomaniakAppPassword,
    String? infomaniakCalendarUrl,
    String? notionApiKey,
    String? theme,
    String? defaultView,
    String? firstDayOfWeek,
    int? defaultReminderMinutes,
    int? morningSummaryHour,
    int? morningSummaryMinute,
    bool? morningSummaryEnabled,
    bool? reminderEnabled,
    String? pythonScriptPath,
    String? pptTemplatePath,
    String? kDriveId,
    bool? isOffline,
    String? weatherCity,
    double? weatherLatitude,
    double? weatherLongitude,
  }) {
    return AppSettings(
      infomaniakUsername: infomaniakUsername ?? this.infomaniakUsername,
      infomaniakAppPassword:
          infomaniakAppPassword ?? this.infomaniakAppPassword,
      infomaniakCalendarUrl:
          infomaniakCalendarUrl ?? this.infomaniakCalendarUrl,
      notionApiKey: notionApiKey ?? this.notionApiKey,
      theme: theme ?? this.theme,
      defaultView: defaultView ?? this.defaultView,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      defaultReminderMinutes:
          defaultReminderMinutes ?? this.defaultReminderMinutes,
      morningSummaryHour: morningSummaryHour ?? this.morningSummaryHour,
      morningSummaryMinute: morningSummaryMinute ?? this.morningSummaryMinute,
      morningSummaryEnabled:
          morningSummaryEnabled ?? this.morningSummaryEnabled,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      pythonScriptPath: pythonScriptPath ?? this.pythonScriptPath,
      pptTemplatePath: pptTemplatePath ?? this.pptTemplatePath,
      kDriveId: kDriveId ?? this.kDriveId,
      isOffline: isOffline ?? this.isOffline,
      weatherCity: weatherCity ?? this.weatherCity,
      weatherLatitude: weatherLatitude ?? this.weatherLatitude,
      weatherLongitude: weatherLongitude ?? this.weatherLongitude,
    );
  }

  bool get isInfomaniakConfigured =>
      infomaniakUsername != null &&
      infomaniakUsername!.isNotEmpty &&
      infomaniakAppPassword != null &&
      infomaniakAppPassword!.isNotEmpty;
  bool get isNotionConfigured =>
      notionApiKey != null && notionApiKey!.isNotEmpty;

  ThemeMode get themeMode {
    switch (theme) {
      case AppConstants.themeLight:
        return ThemeMode.light;
      case AppConstants.themeDark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Sérialise les paramètres en JSON pour export (QR code / fichier).
  /// Inclut les identifiants sensibles.
  Map<String, dynamic> toExportJson() {
    final map = <String, dynamic>{
      'v': 1,
      'theme': theme,
      'view': defaultView,
      'first_day': firstDayOfWeek,
      'reminder_min': defaultReminderMinutes,
      'morning_h': morningSummaryHour,
      'morning_m': morningSummaryMinute,
      'morning_on': morningSummaryEnabled,
      'reminder_on': reminderEnabled,
      'weather_city': weatherCity,
      'weather_lat': weatherLatitude,
      'weather_lon': weatherLongitude,
    };
    // Ajouter seulement les valeurs non-null
    if (infomaniakUsername != null) map['ik_user'] = infomaniakUsername;
    if (infomaniakAppPassword != null) map['ik_pass'] = infomaniakAppPassword;
    if (infomaniakCalendarUrl != null) map['ik_cal'] = infomaniakCalendarUrl;
    if (notionApiKey != null) map['notion'] = notionApiKey;
    if (kDriveId != null) map['kdrive'] = kDriveId;
    return map;
  }

  /// Encode les paramètres en string compacte pour QR code (gzip + base64).
  String toExportString() {
    final jsonStr = jsonEncode(toExportJson());
    final compressed = gzip.encode(utf8.encode(jsonStr));
    return base64Encode(compressed);
  }

  /// Décode un export string en AppSettings.
  static AppSettings fromExportString(String encoded) {
    final compressed = base64Decode(encoded);
    final jsonStr = utf8.decode(gzip.decode(compressed));
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return fromExportJson(json);
  }

  /// Reconstruit depuis un JSON exporté.
  static AppSettings fromExportJson(Map<String, dynamic> json) {
    return AppSettings(
      infomaniakUsername: json['ik_user'] as String?,
      infomaniakAppPassword: json['ik_pass'] as String?,
      infomaniakCalendarUrl: json['ik_cal'] as String?,
      notionApiKey: json['notion'] as String?,
      theme: json['theme'] as String? ?? AppConstants.themeAuto,
      defaultView: json['view'] as String? ?? AppConstants.viewWeek,
      firstDayOfWeek:
          json['first_day'] as String? ?? AppConstants.firstDayMonday,
      defaultReminderMinutes:
          json['reminder_min'] as int? ?? AppConstants.defaultReminderMinutes,
      morningSummaryHour:
          json['morning_h'] as int? ?? AppConstants.defaultMorningSummaryHour,
      morningSummaryMinute:
          json['morning_m'] as int? ?? AppConstants.defaultMorningSummaryMinute,
      morningSummaryEnabled: json['morning_on'] as bool? ?? true,
      reminderEnabled: json['reminder_on'] as bool? ?? true,
      weatherCity: json['weather_city'] as String? ?? 'Genève',
      weatherLatitude: (json['weather_lat'] as num?)?.toDouble() ?? 46.2044,
      weatherLongitude: (json['weather_lon'] as num?)?.toDouble() ?? 6.1432,
      kDriveId: json['kdrive'] as String?,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyInfomaniakUsername = 'infomaniak_username';
  static const _keyInfomaniakAppPassword = 'infomaniak_app_password';
  static const _keyInfomaniakCalendarUrl = 'infomaniak_calendar_url';
  static const _keyNotionApiKey = 'notion_api_key';

  @override
  Future<AppSettings> build() async {
    return _loadSettings();
  }

  Future<AppSettings> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Identifiants depuis le stockage sécurisé
    final infomaniakUsername = await _storage.read(key: _keyInfomaniakUsername);
    final infomaniakAppPassword =
        await _storage.read(key: _keyInfomaniakAppPassword);
    final infomaniakCalendarUrl =
        await _storage.read(key: _keyInfomaniakCalendarUrl);
    final notionApiKey = await _storage.read(key: _keyNotionApiKey);

    return AppSettings(
      infomaniakUsername: infomaniakUsername,
      infomaniakAppPassword: infomaniakAppPassword,
      infomaniakCalendarUrl: infomaniakCalendarUrl,
      notionApiKey: notionApiKey,
      theme: prefs.getString('theme') ?? AppConstants.themeAuto,
      defaultView: prefs.getString('default_view') ?? AppConstants.viewWeek,
      firstDayOfWeek:
          prefs.getString('first_day') ?? AppConstants.firstDayMonday,
      defaultReminderMinutes: prefs.getInt('reminder_minutes') ??
          AppConstants.defaultReminderMinutes,
      morningSummaryHour: prefs.getInt('morning_hour') ??
          AppConstants.defaultMorningSummaryHour,
      morningSummaryMinute: prefs.getInt('morning_minute') ??
          AppConstants.defaultMorningSummaryMinute,
      morningSummaryEnabled: prefs.getBool('morning_summary') ?? true,
      reminderEnabled: prefs.getBool('reminder_enabled') ?? true,
      pythonScriptPath: prefs.getString('python_script_path'),
      pptTemplatePath: prefs.getString('ppt_template_path'),
      kDriveId: prefs.getString('kdrive_id'),
      weatherCity: prefs.getString('weather_city') ?? 'Genève',
      weatherLatitude: prefs.getDouble('weather_latitude') ?? 46.2044,
      weatherLongitude: prefs.getDouble('weather_longitude') ?? 6.1432,
    );
  }

  Future<void> updateInfomaniakCredentials({
    required String username,
    required String appPassword,
    String? calendarUrl,
  }) async {
    final current = state.valueOrNull ?? const AppSettings();
    final oldUrl = current.infomaniakCalendarUrl;

    await _storage.write(key: _keyInfomaniakUsername, value: username);
    await _storage.write(key: _keyInfomaniakAppPassword, value: appPassword);
    if (calendarUrl != null) {
      await _storage.write(key: _keyInfomaniakCalendarUrl, value: calendarUrl);
    }
    state = AsyncData(current.copyWith(
      infomaniakUsername: username,
      infomaniakAppPassword: appPassword,
      infomaniakCalendarUrl: calendarUrl,
    ));

    // Si l'URL du calendrier a changé, purger les anciens événements
    if (calendarUrl != null && oldUrl != null && oldUrl != calendarUrl) {
      final db = DatabaseHelper.instance;
      await db.deleteEventsBySource(AppConstants.sourceInfomaniak);
      await db.deleteSyncState(AppConstants.sourceInfomaniak);
    }
  }

  Future<void> updateInfomaniakCalendarUrl(String url) async {
    final current = state.valueOrNull ?? const AppSettings();
    final oldUrl = current.infomaniakCalendarUrl;

    await _storage.write(key: _keyInfomaniakCalendarUrl, value: url);
    state = AsyncData(current.copyWith(infomaniakCalendarUrl: url));

    // Si l'URL a changé, purger les anciens événements et le sync_state
    if (oldUrl != null && oldUrl != url) {
      final db = DatabaseHelper.instance;
      await db.deleteEventsBySource(AppConstants.sourceInfomaniak);
      await db.deleteSyncState(AppConstants.sourceInfomaniak);
    }
  }

  Future<void> updateNotionApiKey(String key) async {
    await _storage.write(key: _keyNotionApiKey, value: key);
    final current = state.valueOrNull ?? const AppSettings();
    state = AsyncData(current.copyWith(notionApiKey: key));
  }

  Future<void> updatePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
    state = AsyncData(await _loadSettings());
  }

  Future<void> setTheme(String theme) async {
    await updatePreference('theme', theme);
  }

  Future<void> setDefaultView(String view) async {
    await updatePreference('default_view', view);
  }

  Future<void> setFirstDayOfWeek(String day) async {
    await updatePreference('first_day', day);
  }

  Future<void> updateWeatherLocation({
    required String city,
    required double latitude,
    required double longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_city', city);
    await prefs.setDouble('weather_latitude', latitude);
    await prefs.setDouble('weather_longitude', longitude);
    final current = state.valueOrNull ?? const AppSettings();
    state = AsyncData(current.copyWith(
      weatherCity: city,
      weatherLatitude: latitude,
      weatherLongitude: longitude,
    ));
  }

  Future<void> clearAllCredentials() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AsyncData(AppSettings());
  }

  /// Importe les paramètres depuis un export JSON (QR code ou fichier).
  Future<void> importSettings(AppSettings imported) async {
    // Stocker les identifiants sensibles
    if (imported.infomaniakUsername != null) {
      await _storage.write(
          key: _keyInfomaniakUsername, value: imported.infomaniakUsername);
    }
    if (imported.infomaniakAppPassword != null) {
      await _storage.write(
          key: _keyInfomaniakAppPassword,
          value: imported.infomaniakAppPassword);
    }
    if (imported.infomaniakCalendarUrl != null) {
      await _storage.write(
          key: _keyInfomaniakCalendarUrl,
          value: imported.infomaniakCalendarUrl);
    }
    if (imported.notionApiKey != null) {
      await _storage.write(key: _keyNotionApiKey, value: imported.notionApiKey);
    }

    // Stocker les préférences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', imported.theme);
    await prefs.setString('default_view', imported.defaultView);
    await prefs.setString('first_day', imported.firstDayOfWeek);
    await prefs.setInt('reminder_minutes', imported.defaultReminderMinutes);
    await prefs.setInt('morning_hour', imported.morningSummaryHour);
    await prefs.setInt('morning_minute', imported.morningSummaryMinute);
    await prefs.setBool('morning_summary', imported.morningSummaryEnabled);
    await prefs.setBool('reminder_enabled', imported.reminderEnabled);
    await prefs.setString('weather_city', imported.weatherCity);
    await prefs.setDouble('weather_latitude', imported.weatherLatitude);
    await prefs.setDouble('weather_longitude', imported.weatherLongitude);
    if (imported.kDriveId != null) {
      await prefs.setString('kdrive_id', imported.kDriveId!);
    }

    state = AsyncData(imported);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
