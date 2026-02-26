class AppConstants {
  // Infomaniak CalDAV
  static const String infomaniakApiBase = 'https://api.infomaniak.com';
  static const String infomaniakCalDavBase = 'https://sync.infomaniak.com';
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
  static const int dbVersion = 5;

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
  static const String tagTypeStatus = 'status';

  // Délai de rappel par défaut (minutes)
  static const int defaultReminderMinutes = 15;

  // Heure du résumé matinal par défaut
  static const int defaultMorningSummaryHour = 8;
  static const int defaultMorningSummaryMinute = 0;

  // Durée du cache (heures)
  static const int cacheDurationHours = 24;

  // Taille des logos source (px)
  static const double sourceLogoSize = 16.0;

  // Tags prédéfinis — palette Notion
  static const List<Map<String, dynamic>> defaultCategories = [
    {'name': 'Travail', 'color': '#007AFF'},
    {'name': 'Perso', 'color': '#34C759'},
    {'name': 'Santé', 'color': '#FF3B30'},
    {'name': 'Famille', 'color': '#FF9500'},
    {'name': 'Sport', 'color': '#30B0C7'},
    {'name': 'Social', 'color': '#AF52DE'},
    {'name': 'Formation', 'color': '#FFCC00'},
    {'name': 'Administratif', 'color': '#8E8E93'},
  ];

  static const List<Map<String, dynamic>> defaultPriorities = [
    {'name': 'Urgent', 'color': '#FF3B30', 'level': 1},
    {'name': 'Haute', 'color': '#FF9500', 'level': 2},
    {'name': 'Normale', 'color': '#34C759', 'level': 3},
    {'name': 'Basse', 'color': '#8E8E93', 'level': 4},
  ];

  static const List<Map<String, dynamic>> defaultStatuses = [
    {'name': 'À faire', 'color': '#8ABBE6'},
    {'name': 'En cours', 'color': '#EAE08C'},
    {'name': 'Fait', 'color': '#82D2CC'},
    {'name': 'Annulé', 'color': '#F2A5B8'},
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
