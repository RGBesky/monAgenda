import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';
import '../models/event_model.dart';
import '../models/tag_model.dart';
import '../../services/logger_service.dart';
import '../models/notion_database_model.dart';
import '../models/ics_subscription_model.dart';
import '../models/sync_state_model.dart';
import 'db_migrations.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  static const _secureStorage = FlutterSecureStorage();
  static const _dbKeyStorageKey = 'db_encryption_key';

  DatabaseHelper._internal();

  /// Helper pour extraire la première valeur entière d'un résultat rawQuery.
  /// Remplace Sqflite.firstIntValue qui n'est pas disponible via sqflite_common_ffi.
  static int _firstIntValue(List<Map<String, Object?>> result) {
    if (result.isEmpty) return 0;
    final firstRow = result.first;
    if (firstRow.isEmpty) return 0;
    final val = firstRow.values.first;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return 0;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Génère une clé aléatoire de 32 octets (base64) et la stocke dans flutter_secure_storage.
  static Future<String> _generateAndStoreKey() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64Encode(bytes);
    await _secureStorage.write(key: _dbKeyStorageKey, value: key);
    return key;
  }

  /// Récupère la clé de chiffrement DB depuis le stockage sécurisé.
  /// La génère si elle n'existe pas encore (premier lancement).
  static Future<String> _getDbEncryptionKey() async {
    final existing = await _secureStorage.read(key: _dbKeyStorageKey);
    return existing ?? await _generateAndStoreKey();
  }

  /// Migre une DB desktop existante non chiffrée vers SQLCipher.
  /// Utilise sqlcipher_export pour convertir sans perte de données.
  /// Ne fait rien si la DB est déjà chiffrée ou n'existe pas.
  Future<void> _migrateToEncryptedIfNeeded(String dbPath, String key) async {
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) return; // Pas de DB → onCreate la créera chiffrée

    // Tester si la DB est déjà chiffrée : essayer de l'ouvrir sans clé
    // Si ça échoue c'est déjà chiffré → rien à faire
    try {
      final testDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          readOnly: true,
          singleInstance: false,
        ),
      );
      // Si on arrive ici, la DB est non chiffrée (lisible sans clé)
      // Lire le user_version pour le restaurer après migration
      final versionResult = await testDb.rawQuery('PRAGMA user_version');
      final currentVersion = _firstIntValue(versionResult);
      await testDb.close();

      // Chemin temporaire pour la DB chiffrée
      final encPath = '$dbPath.enc';
      final encFile = File(encPath);
      if (encFile.existsSync()) encFile.deleteSync();

      // Ouvrir la DB non chiffrée et exporter vers une chiffrée
      final plainDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await plainDb
          .rawQuery("ATTACH DATABASE '$encPath' AS encrypted KEY '$key'");
      await plainDb.rawQuery("SELECT sqlcipher_export('encrypted')");
      await plainDb.rawQuery("DETACH DATABASE encrypted");
      await plainDb.close();

      // Remplacer l'ancienne DB par la chiffrée
      final backupPath = '$dbPath.bak';
      dbFile.renameSync(backupPath);
      File(encPath).renameSync(dbPath);

      // Restaurer le user_version dans la DB chiffrée
      final newDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          singleInstance: false,
          onConfigure: (db) async {
            await db.rawQuery("PRAGMA key = '$key'");
          },
        ),
      );
      await newDb.execute('PRAGMA user_version = $currentVersion');
      await newDb.close();

      // Supprimer le backup
      final bakFile = File(backupPath);
      if (bakFile.existsSync()) bakFile.deleteSync();

      AppLogger.instance
          .info('DatabaseHelper', 'Migration SQLCipher desktop réussie');
    } catch (_) {
      // La DB n'est pas lisible sans clé → déjà chiffrée, rien à faire
      AppLogger.instance.info('DatabaseHelper',
          'DB déjà chiffrée ou inaccessible, pas de migration');
    }
  }

  Future<Database> _initDatabase() async {
    final bool isDesktop =
        Platform.isLinux || Platform.isMacOS || Platform.isWindows;

    if (isDesktop) {
      // Desktop : SQLCipher via libsqlcipher.so.1 (chargé dans main.dart)
      final dbKey = await _getDbEncryptionKey();
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = join(dbPath, AppConstants.dbName);

      // Migrer la DB existante non chiffrée si nécessaire
      await _migrateToEncryptedIfNeeded(path, dbKey);

      return databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kCurrentDbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onConfigure: (db) async {
            // Clé SQLCipher AVANT toute lecture (user_version, etc.)
            await db.rawQuery("PRAGMA key = '$dbKey'");
            // WAL mode + busy_timeout — protège contre "database is locked" (F-001)
            await db.execute('PRAGMA journal_mode=WAL');
            await db.execute('PRAGMA busy_timeout=5000');
          },
        ),
      );
    }

    // Mobile : base chiffrée via SQLCipher
    final dbKey = await _getDbEncryptionKey();
    final dbPath = await sqlcipher.getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return sqlcipher.openDatabase(
      path,
      password: dbKey,
      version: kCurrentDbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // WAL mode + busy_timeout — protège contre "database is locked" (F-001)
        await db.execute('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA busy_timeout=5000');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableEvents} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        source TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_all_day INTEGER DEFAULT 0,
        location TEXT,
        description TEXT,
        participants TEXT DEFAULT '[]',
        tag_ids TEXT DEFAULT '[]',
        rrule TEXT,
        recurrence_id TEXT,
        calendar_id TEXT,
        notion_page_id TEXT,
        ics_subscription_id TEXT,
        status TEXT,
        reminder_minutes INTEGER,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        synced_at TEXT,
        etag TEXT,
        smart_attachments TEXT DEFAULT '[]',
        UNIQUE(remote_id, source)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableTags} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        infomaniak_mapping TEXT,
        notion_mapping TEXT,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableEventTags} (
        event_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (event_id, tag_id),
        FOREIGN KEY (event_id) REFERENCES ${AppConstants.tableEvents}(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES ${AppConstants.tableTags}(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableNotionDatabases} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        notion_id TEXT NOT NULL UNIQUE,
        data_source_id TEXT,
        name TEXT NOT NULL,
        title_property TEXT DEFAULT 'Name',
        start_date_property TEXT,
        end_date_property TEXT,
        category_property TEXT,
        priority_property TEXT,
        description_property TEXT,
        participants_property TEXT,
        status_property TEXT,
        location_property TEXT,
        objective_property TEXT,
        material_property TEXT,
        is_enabled INTEGER DEFAULT 1,
        last_synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableIcsSubscriptions} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL UNIQUE,
        color_hex TEXT DEFAULT '#78909C',
        is_enabled INTEGER DEFAULT 1,
        last_synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableSyncState} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL UNIQUE,
        last_synced_at TEXT,
        sync_token TEXT,
        status TEXT DEFAULT 'idle',
        error_message TEXT
      )
    ''');

    // Index pour les requêtes fréquentes
    await db.execute(
      'CREATE INDEX idx_events_start_date ON ${AppConstants.tableEvents}(start_date)',
    );
    await db.execute(
      'CREATE INDEX idx_events_source ON ${AppConstants.tableEvents}(source)',
    );
    await db.execute(
      'CREATE INDEX idx_events_deleted ON ${AppConstants.tableEvents}(is_deleted)',
    );

    // ── V2 : Table sync_queue (offline-first) ──
    await db.execute('''
      CREATE TABLE ${AppConstants.tableSyncQueue} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        source TEXT NOT NULL,
        event_id INTEGER,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sync_queue_status ON ${AppConstants.tableSyncQueue}(status)',
    );

    // ── V2 : Table system_logs (gestion erreurs silencieuses) ──
    await db.execute('''
      CREATE TABLE ${AppConstants.tableSystemLogs} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        level TEXT NOT NULL,
        source TEXT NOT NULL,
        message TEXT NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL,
        is_read INTEGER DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_system_logs_level ON ${AppConstants.tableSystemLogs}(level)',
    );

    // ── V12 : Table cert_pins (auto-rotation TOFU) ──
    await db.execute('''
      CREATE TABLE cert_pins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        host TEXT NOT NULL UNIQUE,
        der_sha256 TEXT NOT NULL,
        issuer TEXT,
        subject TEXT,
        expires_at TEXT,
        first_seen TEXT NOT NULL,
        last_verified TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_cert_pins_host ON cert_pins(host)',
    );

    // Tags par défaut
    await _insertDefaultTags(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableNotionDatabases} ADD COLUMN location_property TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableNotionDatabases} ADD COLUMN objective_property TEXT',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableNotionDatabases} ADD COLUMN material_property TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableNotionDatabases} ADD COLUMN data_source_id TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableEvents} ADD COLUMN status TEXT',
      );
    }
    if (oldVersion < 5) {
      // Ajouter les tags de statut par défaut
      for (int i = 0; i < AppConstants.defaultStatuses.length; i++) {
        final st = AppConstants.defaultStatuses[i];
        await db.insert(AppConstants.tableTags, {
          'type': AppConstants.tagTypeStatus,
          'name': st['name'],
          'color_hex': st['color'],
          'sort_order': i,
        });
      }
    }
    if (oldVersion < 6) {
      // V2 : sync_queue pour offline-first
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableSyncQueue} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          source TEXT NOT NULL,
          event_id INTEGER,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0,
          last_error TEXT,
          status TEXT DEFAULT 'pending'
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON ${AppConstants.tableSyncQueue}(status)',
      );
      // V2 : system_logs pour gestion erreurs silencieuses
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableSystemLogs} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          level TEXT NOT NULL,
          source TEXT NOT NULL,
          message TEXT NOT NULL,
          details TEXT,
          created_at TEXT NOT NULL,
          is_read INTEGER DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_system_logs_level ON ${AppConstants.tableSystemLogs}(level)',
      );
    }

    // ── V7+ : Migrations centralisées (db_migrations.dart) ──
    for (int v = (oldVersion < 7 ? 7 : oldVersion + 1); v <= newVersion; v++) {
      final statements = kMigrations[v];
      if (statements != null) {
        for (final sql in statements) {
          try {
            await db.execute(sql);
          } catch (e) {
            // Ignore "duplicate column" or "table already exists" errors
            if (!e.toString().contains('duplicate column') &&
                !e.toString().contains('already exists')) {
              rethrow;
            }
          }
        }
      }
    }
  }

  Future<void> _insertDefaultTags(Database db) async {
    for (int i = 0; i < AppConstants.defaultCategories.length; i++) {
      final cat = AppConstants.defaultCategories[i];
      await db.insert(AppConstants.tableTags, {
        'type': AppConstants.tagTypeCategory,
        'name': cat['name'],
        'color_hex': cat['color'],
        'infomaniak_mapping': cat['name'],
        'sort_order': i,
      });
    }

    for (int i = 0; i < AppConstants.defaultPriorities.length; i++) {
      final pri = AppConstants.defaultPriorities[i];
      await db.insert(AppConstants.tableTags, {
        'type': AppConstants.tagTypePriority,
        'name': pri['name'],
        'color_hex': pri['color'],
        'infomaniak_mapping': pri['level'].toString(),
        'sort_order': pri['level'] as int,
      });
    }

    for (int i = 0; i < AppConstants.defaultStatuses.length; i++) {
      final st = AppConstants.defaultStatuses[i];
      await db.insert(AppConstants.tableTags, {
        'type': AppConstants.tagTypeStatus,
        'name': st['name'],
        'color_hex': st['color'],
        'sort_order': i,
      });
    }
  }

  // ============================================================
  // EVENTS
  // ============================================================

  Future<int> insertEvent(EventModel event) async {
    final db = await database;
    final id = await db.insert(
      AppConstants.tableEvents,
      event.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (event.tagIds.isNotEmpty) {
      await _updateEventTags(id, event.tagIds);
    }
    return id;
  }

  Future<void> updateEvent(EventModel event) async {
    final db = await database;
    await db.update(
      AppConstants.tableEvents,
      event.toMap()..['updated_at'] = DateTime.now().toIso8601String(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
    if (event.id != null) {
      await _updateEventTags(event.id!, event.tagIds);
    }
  }

  Future<void> _updateEventTags(int eventId, List<int> tagIds) async {
    final db = await database;
    await db.delete(
      AppConstants.tableEventTags,
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
    for (final tagId in tagIds) {
      await db.insert(AppConstants.tableEventTags, {
        'event_id': eventId,
        'tag_id': tagId,
      });
    }
  }

  /// Met à jour les tags d'un événement + la colonne JSON tag_ids.
  Future<void> updateEventTags(int eventId, List<int> tagIds) async {
    await _updateEventTags(eventId, tagIds);
    final db = await database;
    await db.update(
      AppConstants.tableEvents,
      {'tag_ids': jsonEncode(tagIds)},
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  /// Suppression logique d'un événement (is_deleted = 1) directement via SQL.
  /// Indépendant du state Riverpod — fonctionne même si l'event a scrollé hors de la vue.
  /// Enqueue automatiquement l'action DELETE dans la sync_queue.
  /// Annule les CREATE/UPDATE pending pour ce même event (évite push+delete inutile).
  Future<void> deleteEvent(int id) async {
    final db = await database;
    // 1. Récupérer les infos nécessaires avant suppression logique
    final maps = await db.query(
      AppConstants.tableEvents,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    // 2. Suppression logique via SQL
    await db.update(
      AppConstants.tableEvents,
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );

    // 3. Annuler les CREATE/UPDATE pending pour cet event
    //    (si l'event a été créé offline, pas besoin de le pousser puis supprimer)
    await db.delete(
      AppConstants.tableSyncQueue,
      where: 'event_id = ? AND action IN (?, ?) AND status = ?',
      whereArgs: [id, 'create', 'update', 'pending'],
    );

    // 4. Enqueue l'action DELETE dans sync_queue (directement via SQL, pas via Riverpod)
    //    Seulement si l'event a un remote_id (sinon rien à supprimer côté serveur)
    if (maps.isNotEmpty) {
      final source = maps.first['source'] as String? ?? '';
      final remoteId = maps.first['remote_id'] as String?;
      final notionPageId = maps.first['notion_page_id'] as String?;

      // Si pas de remote_id ni notion_page_id, l'event est purement local
      // → rien à pousser vers le serveur, la suppression locale suffit.
      if (remoteId != null || notionPageId != null) {
        await enqueueSyncAction(
          action: 'delete',
          source: source,
          eventId: id,
          payload: jsonEncode(maps.first),
        );
      }
    }
  }

  /// Récupère un événement par son ID local (clé primaire).
  Future<EventModel?> getEventById(int id) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableEvents,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final results = await _mapToEventsWithTags(db, maps);
    return results.firstOrNull;
  }

  Future<List<EventModel>> getEventsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableEvents,
      where: 'is_deleted = 0 AND start_date <= ? AND end_date >= ?',
      whereArgs: [end.toIso8601String(), start.toIso8601String()],
      orderBy: 'start_date ASC',
    );
    return _mapToEventsWithTags(db, maps);
  }

  /// Retourne les événements pour un calendarId (ex: Notion database).
  Future<List<EventModel>> getEventsByCalendarId(String calendarId) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableEvents,
      where: 'is_deleted = 0 AND calendar_id = ?',
      whereArgs: [calendarId],
      orderBy: 'start_date ASC',
    );
    return _mapToEventsWithTags(db, maps);
  }

  /// Retourne le nombre total d'événements non supprimés.
  Future<int> getEventsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AppConstants.tableEvents} WHERE is_deleted = 0',
    );
    return _firstIntValue(result);
  }

  /// Vérifie si la table FTS5 events_fts existe.
  Future<bool> _hasFtsTable(Database db) async {
    try {
      final r = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='events_fts'",
      );
      return r.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<EventModel>> searchEvents({
    String? keyword,
    List<int>? tagIds,
    String? participantEmail,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    final conditions = <String>['is_deleted = 0'];
    final args = <dynamic>[];

    // V3 : FTS5 avec fallback LIKE si la table FTS n'existe pas
    if (keyword != null && keyword.isNotEmpty) {
      final hasFts = await _hasFtsTable(db);
      if (hasFts) {
        final safeKeyword = keyword.replaceAll('"', '""');
        conditions.add(
          'id IN (SELECT rowid FROM events_fts WHERE events_fts MATCH ?)',
        );
        args.add('"$safeKeyword"');
      } else {
        // Fallback LIKE pour les 3 champs indexés par FTS
        conditions.add(
          '(title LIKE ? OR description LIKE ? OR location LIKE ?)',
        );
        final like = '%$keyword%';
        args.addAll([like, like, like]);
      }
    }
    if (startDate != null) {
      conditions.add('start_date >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      conditions.add('end_date <= ?');
      args.add(endDate.toIso8601String());
    }
    if (participantEmail != null) {
      conditions.add('participants LIKE ?');
      args.add('%$participantEmail%');
    }

    final maps = await db.query(
      AppConstants.tableEvents,
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'start_date ASC',
    );

    var events = await _mapToEventsWithTags(db, maps);

    if (tagIds != null && tagIds.isNotEmpty) {
      events = events
          .where((e) => tagIds.any((id) => e.tagIds.contains(id)))
          .toList();
    }

    return events;
  }

  Future<List<EventModel>> _mapToEventsWithTags(
    Database db,
    List<Map<String, dynamic>> maps,
  ) async {
    if (maps.isEmpty) return [];

    final events = maps.map(EventModel.fromMap).toList();
    final eventIds = events.map((e) => e.id!).toList();

    // Batch : 1 seule requête pour tous les tags au lieu de N
    final placeholders = List.filled(eventIds.length, '?').join(',');
    final tagMaps = await db.rawQuery('''
      SELECT et.event_id, t.* FROM ${AppConstants.tableTags} t
      INNER JOIN ${AppConstants.tableEventTags} et ON et.tag_id = t.id
      WHERE et.event_id IN ($placeholders)
      ORDER BY t.type ASC, t.sort_order ASC
    ''', eventIds);

    // Grouper par event_id
    final tagsByEventId = <int, List<TagModel>>{};
    for (final row in tagMaps) {
      final eventId = row['event_id'] as int;
      tagsByEventId.putIfAbsent(eventId, () => []).add(TagModel.fromMap(row));
    }

    return events
        .map((e) => e.copyWith(tags: tagsByEventId[e.id!] ?? []))
        .toList();
  }

  Future<EventModel?> getEventByRemoteId(String remoteId, String source) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableEvents,
      where: 'remote_id = ? AND source = ?',
      whereArgs: [remoteId, source],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final event = EventModel.fromMap(maps.first);
    final tags = await getTagsByEventId(event.id!);
    return event.copyWith(tags: tags);
  }

  // ============================================================
  // TAGS
  // ============================================================

  Future<List<TagModel>> getAllTags() async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableTags,
      orderBy: 'type ASC, sort_order ASC',
    );
    return maps.map(TagModel.fromMap).toList();
  }

  Future<List<TagModel>> getTagsByType(String type) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableTags,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'sort_order ASC',
    );
    return maps.map(TagModel.fromMap).toList();
  }

  Future<List<TagModel>> getTagsByEventId(int eventId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT t.* FROM ${AppConstants.tableTags} t
      INNER JOIN ${AppConstants.tableEventTags} et ON et.tag_id = t.id
      WHERE et.event_id = ?
      ORDER BY t.type ASC, t.sort_order ASC
    ''', [eventId]);
    return maps.map(TagModel.fromMap).toList();
  }

  Future<int> insertTag(TagModel tag) async {
    final db = await database;
    return db.insert(AppConstants.tableTags, tag.toMap()..remove('id'));
  }

  Future<void> updateTag(TagModel tag) async {
    final db = await database;
    await db.update(
      AppConstants.tableTags,
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  Future<void> deleteTag(int id) async {
    final db = await database;
    await db.delete(AppConstants.tableTags, where: 'id = ?', whereArgs: [id]);
  }

  // ============================================================
  // NOTION DATABASES
  // ============================================================

  Future<List<NotionDatabaseModel>> getNotionDatabases() async {
    final db = await database;
    final maps = await db.query(AppConstants.tableNotionDatabases);
    return maps.map(NotionDatabaseModel.fromMap).toList();
  }

  Future<int> insertNotionDatabase(NotionDatabaseModel dbModel) async {
    final db = await database;
    return db.insert(
      AppConstants.tableNotionDatabases,
      dbModel.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateNotionDatabase(NotionDatabaseModel dbModel) async {
    final db = await database;
    await db.update(
      AppConstants.tableNotionDatabases,
      dbModel.toMap(),
      where: 'id = ?',
      whereArgs: [dbModel.id],
    );
  }

  Future<void> deleteNotionDatabase(int id) async {
    final db = await database;
    await db.delete(
      AppConstants.tableNotionDatabases,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // ICS SUBSCRIPTIONS
  // ============================================================

  Future<List<IcsSubscriptionModel>> getIcsSubscriptions() async {
    final db = await database;
    final maps = await db.query(AppConstants.tableIcsSubscriptions);
    return maps.map(IcsSubscriptionModel.fromMap).toList();
  }

  Future<int> insertIcsSubscription(IcsSubscriptionModel sub) async {
    final db = await database;
    return db.insert(
      AppConstants.tableIcsSubscriptions,
      sub.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateIcsSubscription(IcsSubscriptionModel sub) async {
    final db = await database;
    await db.update(
      AppConstants.tableIcsSubscriptions,
      sub.toMap(),
      where: 'id = ?',
      whereArgs: [sub.id],
    );
  }

  Future<void> deleteIcsSubscription(int id) async {
    final db = await database;
    await db.delete(
      AppConstants.tableIcsSubscriptions,
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.delete(
      AppConstants.tableEvents,
      where: 'ics_subscription_id = ?',
      whereArgs: [id.toString()],
    );
  }

  // ============================================================
  // SYNC STATE
  // ============================================================

  Future<SyncStateModel?> getSyncState(String source) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableSyncState,
      where: 'source = ?',
      whereArgs: [source],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SyncStateModel.fromMap(maps.first);
  }

  Future<void> upsertSyncState(SyncStateModel state) async {
    final db = await database;
    await db.insert(
      AppConstants.tableSyncState,
      state.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Supprime physiquement tous les événements d'une source donnée.
  Future<int> deleteEventsBySource(String source) async {
    final db = await database;
    // Supprimer les liens event_tags d'abord
    await db.rawDelete(
      'DELETE FROM ${AppConstants.tableEventTags} WHERE event_id IN '
      '(SELECT id FROM ${AppConstants.tableEvents} WHERE source = ?)',
      [source],
    );
    return db.delete(
      AppConstants.tableEvents,
      where: 'source = ?',
      whereArgs: [source],
    );
  }

  /// Supprime l'état de sync pour une source donnée.
  Future<void> deleteSyncState(String source) async {
    final db = await database;
    await db.delete(
      AppConstants.tableSyncState,
      where: 'source = ?',
      whereArgs: [source],
    );
  }

  // ============================================================
  // SYNC QUEUE (V2 - Offline-first)
  // ============================================================

  /// Ajoute une action à la queue de synchronisation.
  /// Pour les actions UPDATE, déduplique automatiquement :
  /// supprime les UPDATEs pending antérieurs pour le même event_id.
  Future<int> enqueueSyncAction({
    required String action,
    required String source,
    int? eventId,
    required String payload,
  }) async {
    final db = await database;

    // Déduplication : si UPDATE, supprimer les UPDATEs pending antérieurs
    // pour cet event_id (Bug 1 — évite N requêtes API inutiles au retour réseau).
    if (action == 'update' && eventId != null) {
      await db.delete(
        AppConstants.tableSyncQueue,
        where: 'event_id = ? AND action = ? AND status = ?',
        whereArgs: [eventId, 'update', 'pending'],
      );
    }

    return db.insert(AppConstants.tableSyncQueue, {
      'action': action,
      'source': source,
      'event_id': eventId,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'retry_count': 0,
    });
  }

  /// Récupère toutes les actions en attente, triées par ancienneté.
  Future<List<Map<String, dynamic>>> getPendingSyncActions() async {
    final db = await database;
    return db.query(
      AppConstants.tableSyncQueue,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  /// Marque une action comme réussie et la supprime.
  Future<void> completeSyncAction(int id) async {
    final db = await database;
    await db.delete(
      AppConstants.tableSyncQueue,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marque une action en erreur (incrémente retry_count).
  Future<void> failSyncAction(int id, String errorMessage) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE ${AppConstants.tableSyncQueue} SET retry_count = retry_count + 1, '
      'last_error = ?, status = CASE WHEN retry_count >= 5 THEN \'failed\' ELSE \'pending\' END '
      'WHERE id = ?',
      [errorMessage, id],
    );
  }

  /// Nombre d'actions en attente dans la queue.
  Future<int> getPendingSyncCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AppConstants.tableSyncQueue} WHERE status = ?',
      ['pending'],
    );
    return _firstIntValue(result);
  }

  /// Supprime les actions terminées en erreur (après trop de retries).
  Future<void> clearFailedSyncActions() async {
    final db = await database;
    await db.delete(
      AppConstants.tableSyncQueue,
      where: 'status = ?',
      whereArgs: ['failed'],
    );
  }

  /// Supprime toutes les actions pending pour un événement donné.
  /// Utilisé après un push direct réussi pour éviter les doublons.
  Future<void> completePendingSyncActionsForEvent(int eventId) async {
    final db = await database;
    await db.delete(
      AppConstants.tableSyncQueue,
      where: 'event_id = ? AND status = ?',
      whereArgs: [eventId, 'pending'],
    );
  }

  // ============================================================
  // SYSTEM LOGS (V2 - Gestion erreurs silencieuses)
  // ============================================================

  /// Limite max de logs en BDD. Au-delà, les plus anciens sont purgés.
  static const int maxLogEntries = 1000;

  /// Compteur d'insertions pour déclencher le trim périodique.
  int _logInsertCount = 0;

  /// Ajoute un log système avec auto-trim (purge les anciens si > maxLogEntries).
  Future<int> insertSystemLog({
    required String level,
    required String source,
    required String message,
    String? details,
  }) async {
    final db = await database;
    final id = await db.insert(AppConstants.tableSystemLogs, {
      'level': level,
      'source': source,
      'message': message,
      'details': details,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': 0,
    });

    // Auto-trim toutes les 50 insertions pour ne pas checker à chaque fois
    _logInsertCount++;
    if (_logInsertCount >= 50) {
      _logInsertCount = 0;
      await trimLogs(maxLogEntries);
    }

    return id;
  }

  /// Récupère les logs non lus.
  Future<List<Map<String, dynamic>>> getUnreadLogs() async {
    final db = await database;
    return db.query(
      AppConstants.tableSystemLogs,
      where: 'is_read = 0',
      orderBy: 'created_at DESC',
      limit: 50,
    );
  }

  /// Récupère tous les logs (avec filtre optionnel par niveau).
  Future<List<Map<String, dynamic>>> getAllLogs({String? levelFilter}) async {
    final db = await database;
    return db.query(
      AppConstants.tableSystemLogs,
      where: levelFilter != null ? 'level = ?' : null,
      whereArgs: levelFilter != null ? [levelFilter] : null,
      orderBy: 'created_at DESC',
      limit: 500,
    );
  }

  /// Récupère tous les logs récents (dernières 24h), avec filtre optionnel.
  Future<List<Map<String, dynamic>>> getRecentLogs(
      {String? levelFilter}) async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
    if (levelFilter != null) {
      return db.query(
        AppConstants.tableSystemLogs,
        where: 'created_at >= ? AND level = ?',
        whereArgs: [cutoff, levelFilter],
        orderBy: 'created_at DESC',
      );
    }
    return db.query(
      AppConstants.tableSystemLogs,
      where: 'created_at >= ?',
      whereArgs: [cutoff],
      orderBy: 'created_at DESC',
    );
  }

  /// Marque tous les logs comme lus.
  Future<void> markAllLogsAsRead() async {
    final db = await database;
    await db.update(
      AppConstants.tableSystemLogs,
      {'is_read': 1},
      where: 'is_read = 0',
    );
  }

  /// Nombre de logs d'erreur non lus.
  Future<int> getUnreadErrorCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AppConstants.tableSystemLogs} '
      'WHERE is_read = 0 AND level = ?',
      ['error'],
    );
    return _firstIntValue(result);
  }

  /// Nombre total de logs en BDD.
  Future<int> getLogCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AppConstants.tableSystemLogs}',
    );
    return _firstIntValue(result);
  }

  /// Nettoie les logs de plus de [days] jours (défaut 7).
  Future<int> cleanOldLogs({int days = 7}) async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    return db.delete(
      AppConstants.tableSystemLogs,
      where: 'created_at < ?',
      whereArgs: [cutoff],
    );
  }

  /// Garde uniquement les [maxEntries] logs les plus récents.
  Future<int> trimLogs(int maxEntries) async {
    final db = await database;
    // Supprime tous ceux dont l'id n'est pas dans les N plus récents
    return db.rawDelete(
      'DELETE FROM ${AppConstants.tableSystemLogs} '
      'WHERE id NOT IN ('
      '  SELECT id FROM ${AppConstants.tableSystemLogs} '
      '  ORDER BY created_at DESC LIMIT ?'
      ')',
      [maxEntries],
    );
  }

  /// Supprime TOUS les logs.
  Future<int> clearAllLogs() async {
    final db = await database;
    return db.delete(AppConstants.tableSystemLogs);
  }

  /// Purge au démarrage : supprime les vieux logs + trim au max.
  Future<void> startupLogCleanup() async {
    await cleanOldLogs();
    await trimLogs(maxLogEntries);
  }

  // ============================================================
  // CERT PINS (auto-rotation TOFU)
  // ============================================================

  /// Récupère le pin stocké pour un hôte.
  Future<Map<String, dynamic>?> getCertPin(String host) async {
    final db = await database;
    final rows = await db.query(
      'cert_pins',
      where: 'host = ?',
      whereArgs: [host],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Insère ou met à jour le pin pour un hôte.
  Future<void> upsertCertPin({
    required String host,
    required String derSha256,
    String? issuer,
    String? subject,
    DateTime? expiresAt,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await getCertPin(host);
    if (existing == null) {
      await db.insert('cert_pins', {
        'host': host,
        'der_sha256': derSha256,
        'issuer': issuer,
        'subject': subject,
        'expires_at': expiresAt?.toIso8601String(),
        'first_seen': now,
        'last_verified': now,
      });
    } else {
      await db.update(
        'cert_pins',
        {
          'der_sha256': derSha256,
          'issuer': issuer,
          'subject': subject,
          'expires_at': expiresAt?.toIso8601String(),
          'last_verified': now,
        },
        where: 'host = ?',
        whereArgs: [host],
      );
    }
  }

  /// Met à jour la date de dernière vérification.
  Future<void> touchCertPin(String host) async {
    final db = await database;
    await db.update(
      'cert_pins',
      {'last_verified': DateTime.now().toIso8601String()},
      where: 'host = ?',
      whereArgs: [host],
    );
  }

  /// Récupère tous les pins stockés.
  Future<List<Map<String, dynamic>>> getAllCertPins() async {
    final db = await database;
    return db.query('cert_pins', orderBy: 'host ASC');
  }

  /// Supprime le pin d'un hôte.
  Future<void> deleteCertPin(String host) async {
    final db = await database;
    await db.delete('cert_pins', where: 'host = ?', whereArgs: [host]);
  }

  /// Supprime tous les pins.
  Future<void> clearAllCertPins() async {
    final db = await database;
    await db.delete('cert_pins');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
