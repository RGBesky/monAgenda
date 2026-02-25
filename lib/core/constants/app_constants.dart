class AppConstants {
  // API Infomaniak
  static const String infomaniakApiBase = 'https://api.infomaniak.com';
  static const String infomaniakCalDavBase = 'https://caldav.infomaniak.com';
  static const String infomaniakScopeCalendar = 'workspace:calendar';
  static const String infomaniakScopeUserInfo = 'user_info';

  // API Notion
  static const String notionApiBase = 'https://api.notion.com/v1';
  static const String notionApiVersion = '2022-06-28';

  // Météo Open-Meteo
  static const String openMeteoApiBase = 'https://api.open-meteo.com/v1';

  // kDrive Infomaniak
  static const String kDriveApiBase = 'https://api.infomaniak.com/2/drive';
  static const String kDriveBackupFileName = 'unified_calendar_backup.enc';
  static const String kDriveBackupFolder = '/unified_calendar';

  // Base de données locale
  static const String dbName = 'unified_calendar.db';
  static const int dbVersion = 1;

  // Tables SQLite
  static const String tableEvents = 'events';
  static const String tableTags = 'tags';
  static const String tableEventTags = 'event_tags';
  static const String tableNotionDatabases = 'notion_databases';
  static const String tableIcsSubscriptions = 'ics_subscriptions';
  static const String tableSyncState = 'sync_state';

  // Sources d'événements
  static const String sourceInfomaniak = 'infomaniak';
  static const String sourceNotion = 'notion';
  static const String sourceIcs = 'ics';

  // Types de tags
  static const String tagTypeCategory = 'category';
  static const String tagTypePriority = 'priority';

  // Délai de rappel par défaut (minutes)
  static const int defaultReminderMinutes = 15;

  // Heure du résumé matinal par défaut
  static const int defaultMorningSummaryHour = 8;
  static const int defaultMorningSummaryMinute = 0;

  // Durée du cache (heures)
  static const int cacheDurationHours = 24;

  // Taille des logos source (px)
  static const double sourceLogoSize = 16.0;

  // Tags prédéfinis
  static const List<Map<String, dynamic>> defaultCategories = [
    {'name': 'Travail', 'color': '#1E88E5'},
    {'name': 'Perso', 'color': '#43A047'},
    {'name': 'Santé', 'color': '#E53935'},
    {'name': 'Famille', 'color': '#FB8C00'},
    {'name': 'Sport', 'color': '#00ACC1'},
    {'name': 'Social', 'color': '#8E24AA'},
    {'name': 'Formation', 'color': '#F4511E'},
    {'name': 'Administratif', 'color': '#6D4C41'},
  ];

  static const List<Map<String, dynamic>> defaultPriorities = [
    {'name': 'Urgent', 'color': '#E53935', 'level': 1},
    {'name': 'Haute', 'color': '#FB8C00', 'level': 2},
    {'name': 'Normale', 'color': '#43A047', 'level': 3},
    {'name': 'Basse', 'color': '#90A4AE', 'level': 4},
  ];

  // Vues calendrier
  static const String viewMonth = 'month';
  static const String viewWeek = 'week';
  static const String viewDay = 'day';
  static const String viewAgenda = 'agenda';

  // Thèmes
  static const String themeAuto = 'auto';
  static const String themeLight = 'light';
  static const String themeDark = 'dark';

  // Premier jour de la semaine
  static const String firstDayMonday = 'monday';
  static const String firstDaySunday = 'sunday';
}
