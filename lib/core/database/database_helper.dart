import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';
import '../models/event_model.dart';
import '../models/tag_model.dart';
import '../models/notion_database_model.dart';
import '../models/ics_subscription_model.dart';
import '../models/sync_state_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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

  Future<void> deleteEvent(int id) async {
    final db = await database;
    await db.update(
      AppConstants.tableEvents,
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
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

    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('(title LIKE ? OR description LIKE ?)');
      args.addAll(['%$keyword%', '%$keyword%']);
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
    final events = <EventModel>[];
    for (final map in maps) {
      final event = EventModel.fromMap(map);
      final tags = await getTagsByEventId(event.id!);
      events.add(event.copyWith(tags: tags));
    }
    return events;
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

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
