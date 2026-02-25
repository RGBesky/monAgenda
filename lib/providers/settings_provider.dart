import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

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
    );
  }

  Future<void> updateInfomaniakCredentials({
    required String username,
    required String appPassword,
    String? calendarUrl,
  }) async {
    await _storage.write(key: _keyInfomaniakUsername, value: username);
    await _storage.write(key: _keyInfomaniakAppPassword, value: appPassword);
    if (calendarUrl != null) {
      await _storage.write(key: _keyInfomaniakCalendarUrl, value: calendarUrl);
    }
    final current = state.valueOrNull ?? const AppSettings();
    state = AsyncData(current.copyWith(
      infomaniakUsername: username,
      infomaniakAppPassword: appPassword,
      infomaniakCalendarUrl: calendarUrl,
    ));
  }

  Future<void> updateInfomaniakCalendarUrl(String url) async {
    await _storage.write(key: _keyInfomaniakCalendarUrl, value: url);
    final current = state.valueOrNull ?? const AppSettings();
    state = AsyncData(current.copyWith(infomaniakCalendarUrl: url));
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

  Future<void> clearAllCredentials() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AsyncData(AppSettings());
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
