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

  // kDrive Infomaniak – lien de dépôt (pas besoin d'authentification)
  static const String kDriveDepositApiBase =
      'https://api.infomaniak.com/3/external/share';
  static const String kDriveBackupFileName = 'unified_calendar_backup.enc';
  static const String kDriveLocalBackupDir = 'backups';

  // Base de données locale
  static const String dbName = 'unified_calendar.db';
  // ATTENTION : la version effective est gérée par kCurrentDbVersion dans db_migrations.dart
  // Cette constante est conservée pour référence mais NE PLUS L'UTILISER dans openDatabase().
  static const int dbVersion = 6; // Legacy — voir db_migrations.dart

  // Tables SQLite
  static const String tableEvents = 'events';
  static const String tableTags = 'tags';
  static const String tableEventTags = 'event_tags';
  static const String tableNotionDatabases = 'notion_databases';
  static const String tableIcsSubscriptions = 'ics_subscriptions';
  static const String tableSyncState = 'sync_state';
  static const String tableSyncQueue = 'sync_queue';
  static const String tableSystemLogs = 'system_logs';

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
  static const double sourceLogoSize = 18.0;

  // Tags prédéfinis — palette Stabilo Boss × Paper Mate Flair
  static const List<Map<String, dynamic>> defaultCategories = [
    {'name': 'Travail', 'color': '#42A5F5'},      // blueMedium
    {'name': 'Perso', 'color': '#9CD8A8'},         // greenPastel
    {'name': 'Santé', 'color': '#66BB6A'},         // greenMedium
    {'name': 'Famille', 'color': '#CCA0DC'},       // violetPastel
    {'name': 'Sport', 'color': '#26C6DA'},         // cyanMedium
    {'name': 'Social', 'color': '#F06292'},        // pinkMedium
    {'name': 'Formation', 'color': '#FFEE58'},     // yellowMedium
    {'name': 'Administratif', 'color': '#E6D2A8'}, // neutralPale
  ];

  static const List<Map<String, dynamic>> defaultPriorities = [
    {'name': 'Urgent', 'color': '#E53935', 'level': 1},   // redVif
    {'name': 'Haute', 'color': '#FB8C00', 'level': 2},    // orangeVif
    {'name': 'Normale', 'color': '#1E88E5', 'level': 3},  // blueVif
    {'name': 'Basse', 'color': '#82D2CC', 'level': 4},    // cyanPastel
  ];

  static const List<Map<String, dynamic>> defaultStatuses = [
    {'name': 'À faire', 'color': '#8ABBE6'},   // bluePastel
    {'name': 'En cours', 'color': '#FFEE58'},   // yellowMedium
    {'name': 'Fait', 'color': '#82D2CC'},       // cyanPastel
    {'name': 'Annulé', 'color': '#F2A5B8'},     // pinkPastel
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

  // Tri des événements
  static const String sortChronological = 'chronological';
  static const String sortByCalendar = 'by_calendar';
}
