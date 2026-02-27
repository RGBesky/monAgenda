import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/models/tag_model.dart';
import '../core/utils/crypto_utils.dart';

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
  final String? kDriveDepositLink;
  final bool isOffline;
  // Météo
  final String weatherCity;
  final double weatherLatitude;
  final double weatherLongitude;
  // Tri
  final String eventSortMode;
  final List<String> calendarOrder;

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
    this.kDriveDepositLink,
    this.isOffline = false,
    this.weatherCity = 'Genève',
    this.weatherLatitude = 46.2044,
    this.weatherLongitude = 6.1432,
    this.eventSortMode = AppConstants.sortChronological,
    this.calendarOrder = const [],
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
    String? kDriveDepositLink,
    bool? isOffline,
    String? weatherCity,
    double? weatherLatitude,
    double? weatherLongitude,
    String? eventSortMode,
    List<String>? calendarOrder,
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
      kDriveDepositLink: kDriveDepositLink ?? this.kDriveDepositLink,
      isOffline: isOffline ?? this.isOffline,
      weatherCity: weatherCity ?? this.weatherCity,
      weatherLatitude: weatherLatitude ?? this.weatherLatitude,
      weatherLongitude: weatherLongitude ?? this.weatherLongitude,
      eventSortMode: eventSortMode ?? this.eventSortMode,
      calendarOrder: calendarOrder ?? this.calendarOrder,
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
  /// Inclut les identifiants sensibles et optionnellement les tags.
  Map<String, dynamic> toExportJson({List<TagModel>? tags}) {
    final map = <String, dynamic>{
      'v': 2,
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
      'event_sort': eventSortMode,
      'cal_order': calendarOrder,
    };
    // Ajouter seulement les valeurs non-null
    if (infomaniakUsername != null) map['ik_user'] = infomaniakUsername;
    if (infomaniakAppPassword != null) map['ik_pass'] = infomaniakAppPassword;
    if (infomaniakCalendarUrl != null) map['ik_cal'] = infomaniakCalendarUrl;
    if (notionApiKey != null) map['notion'] = notionApiKey;
    if (kDriveDepositLink != null) map['kdrive_deposit'] = kDriveDepositLink;
    // Tags personnalisés
    if (tags != null && tags.isNotEmpty) {
      map['tags'] = tags
          .map((t) => {
                'type': t.type,
                'name': t.name,
                'color': t.colorHex,
                if (t.infomaniakMapping != null) 'ik_map': t.infomaniakMapping,
                if (t.notionMapping != null) 'notion_map': t.notionMapping,
                'order': t.sortOrder,
              })
          .toList();
    }
    return map;
  }

  /// Encode les paramètres en string chiffrée AES-256 pour QR code.
  /// Le mot de passe est requis — aucune donnée en clair dans le QR.
  String toEncryptedExportString(String password, {List<TagModel>? tags}) {
    final jsonStr = jsonEncode(toExportJson(tags: tags));
    return CryptoUtils.encryptToExportString(jsonStr, password);
  }

  /// [LEGACY - V1] Encode non-chiffré (gzip + base64). Conservé pour migration.
  @Deprecated('Utiliser toEncryptedExportString() pour la V2')
  String toExportString() {
    final jsonStr = jsonEncode(toExportJson());
    final compressed = gzip.encode(utf8.encode(jsonStr));
    return base64Encode(compressed);
  }

  /// Déchiffre un export string AES-256 en AppSettings.
  static AppSettings fromEncryptedExportString(
      String encoded, String password) {
    final jsonStr = CryptoUtils.decryptFromExportString(encoded, password);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return fromExportJson(json);
  }

  /// Extrait les tags depuis un JSON d'export (si présents, v>=2).
  static List<TagModel> parseExportedTags(Map<String, dynamic> json) {
    final tagsJson = json['tags'] as List?;
    if (tagsJson == null) return [];
    return tagsJson.map((t) {
      final m = t as Map<String, dynamic>;
      return TagModel(
        type: m['type'] as String,
        name: m['name'] as String,
        colorHex: m['color'] as String,
        infomaniakMapping: m['ik_map'] as String?,
        notionMapping: m['notion_map'] as String?,
        sortOrder: m['order'] as int? ?? 0,
      );
    }).toList();
  }

  /// Déchiffre et extrait les tags depuis un export AES-256.
  static List<TagModel> parseExportedTagsEncrypted(
      String encoded, String password) {
    final jsonStr = CryptoUtils.decryptFromExportString(encoded, password);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return parseExportedTags(json);
  }

  /// [LEGACY - V1] Décode un export string non-chiffré. Conservé pour migration.
  @Deprecated('Utiliser fromEncryptedExportString() pour la V2')
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
      eventSortMode:
          json['event_sort'] as String? ?? AppConstants.sortChronological,
      calendarOrder: (json['cal_order'] as List?)?.cast<String>() ?? [],
      kDriveDepositLink: (json['kdrive_deposit'] ?? json['kdrive']) as String?,
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
      kDriveDepositLink: prefs.getString('kdrive_deposit_link'),
      weatherCity: prefs.getString('weather_city') ?? 'Genève',
      weatherLatitude: prefs.getDouble('weather_latitude') ?? 46.2044,
      weatherLongitude: prefs.getDouble('weather_longitude') ?? 6.1432,
      eventSortMode:
          prefs.getString('event_sort_mode') ?? AppConstants.sortChronological,
      calendarOrder: _decodeCalendarOrder(prefs.getString('calendar_order')),
    );
  }

  static List<String> _decodeCalendarOrder(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return [];
    }
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

  Future<void> setEventSortMode(String mode) async {
    await updatePreference('event_sort_mode', mode);
  }

  Future<void> setCalendarOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calendar_order', jsonEncode(order));
    final current = state.valueOrNull ?? const AppSettings();
    state = AsyncData(current.copyWith(calendarOrder: order));
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
  /// Importe les paramètres et optionnellement les tags personnalisés.
  /// Les tags sont dédupliqués par nom+type (pas de doublon).
  Future<void> importSettings(AppSettings imported,
      {List<TagModel>? tags}) async {
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
    await prefs.setString('event_sort_mode', imported.eventSortMode);
    await prefs.setString('calendar_order', jsonEncode(imported.calendarOrder));
    if (imported.kDriveDepositLink != null) {
      await prefs.setString('kdrive_deposit_link', imported.kDriveDepositLink!);
    }

    // Importer les tags (dédupliqués par nom+type)
    if (tags != null && tags.isNotEmpty) {
      final db = DatabaseHelper.instance;
      final existingTags = await db.getAllTags();
      final existingKeys =
          existingTags.map((t) => '${t.type}::${t.name.toLowerCase()}').toSet();

      for (final tag in tags) {
        final key = '${tag.type}::${tag.name.toLowerCase()}';
        if (!existingKeys.contains(key)) {
          await db.insertTag(tag);
          existingKeys.add(key);
        }
      }
    }

    state = AsyncData(imported);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
