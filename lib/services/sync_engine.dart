import 'dart:async';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/models/event_model.dart';
import '../core/models/sync_state_model.dart';
import 'infomaniak_service.dart';
import 'notion_service.dart';
import 'ics_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';

enum SyncResult { success, partialSuccess, failure, offline }

/// Moteur de synchronisation central.
/// Orchestre la fusion des données depuis toutes les sources.
/// Résolution de conflits : last-write-wins (V1).
class SyncEngine {
  final DatabaseHelper _db;
  final InfomaniakService _infomaniak;
  final NotionService _notion;
  final IcsService _ics;
  final NotificationService _notifications;

  final _syncStreamController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStream => _syncStreamController.stream;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncEngine({
    required DatabaseHelper db,
    required InfomaniakService infomaniak,
    required NotionService notion,
    required IcsService ics,
    required NotificationService notifications,
  })  : _db = db,
        _infomaniak = infomaniak,
        _notion = notion,
        _ics = ics,
        _notifications = notifications;

  /// Synchronisation complète de toutes les sources.
  /// Retourne un tuple (SyncResult, Map<source, errorMessage>).
  Future<(SyncResult, Map<String, String>)> syncAll({
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    if (_isSyncing) return (SyncResult.failure, <String, String>{});
    _isSyncing = true;
    _syncStreamController.add(SyncStatus.syncing);

    final start =
        rangeStart ?? DateTime.now().subtract(const Duration(days: 30));
    final end = rangeEnd ?? DateTime.now().add(const Duration(days: 365));

    var success = true;
    final errors = <String, String>{};

    // Sync Infomaniak
    if (_infomaniak.isConfigured) {
      try {
        await _syncInfomaniak(start, end);
      } catch (e) {
        success = false;
        errors['Infomaniak'] = e.toString();
        await _db.upsertSyncState(SyncStateModel(
          source: AppConstants.sourceInfomaniak,
          status: SyncStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }

    // Sync Notion
    if (_notion.isConfigured) {
      try {
        await _syncNotion(start, end);
      } catch (e) {
        success = false;
        errors['Notion'] = e.toString();
        final notionDbs = await _db.getNotionDatabases();
        for (final db in notionDbs) {
          await _db.upsertSyncState(SyncStateModel(
            source: db.effectiveSourceId,
            status: SyncStatus.error,
            errorMessage: e.toString(),
          ));
        }
      }
    }

    // Sync abonnements .ics
    try {
      await _syncIcsSubscriptions();
    } catch (e) {
      success = false;
      errors['.ics'] = e.toString();
    }

    _isSyncing = false;
    _syncStreamController.add(success ? SyncStatus.success : SyncStatus.error);

    return (
      success ? SyncResult.success : SyncResult.partialSuccess,
      errors,
    );
  }

  Future<void> _syncInfomaniak(DateTime start, DateTime end) async {
    final state = await _db.getSyncState(AppConstants.sourceInfomaniak);

    // Vérifier si le calendrier a changé via ctag
    String? currentToken;
    try {
      currentToken = await _infomaniak.getSyncToken();
    } catch (_) {
      // ctag non disponible, on force la sync
    }

    if (currentToken != null &&
        state?.syncToken == currentToken &&
        state?.status == SyncStatus.success) {
      // Pas de changement
      return;
    }

    final rawEvents = await _infomaniak.fetchEvents(
      start: start,
      end: end,
    );

    final allTags = await _db.getAllTags();

    for (final raw in rawEvents) {
      final ical = raw['ical'] as String;
      final etag = raw['etag'] as String?;

      final event = InfomaniakService.parseICalEvent(
        ical,
        calendarId: 'default',
        etag: etag,
        allTags: allTags,
      );

      if (event != null) {
        await _upsertEvent(event);
      }
    }

    await _db.upsertSyncState(SyncStateModel(
      source: AppConstants.sourceInfomaniak,
      lastSyncedAt: DateTime.now(),
      syncToken: currentToken,
      status: SyncStatus.success,
    ));

    // Reprogrammer les notifications (non supporté sur desktop)
    try {
      await _rescheduleNotifications();
    } catch (_) {}

    // Mettre à jour le widget Android
    try {
      await _updateWidget();
    } catch (_) {}
  }

  Future<void> _updateWidget() async {
    try {
      await WidgetService.updateWidget();
    } catch (_) {}
  }

  Future<void> _syncNotion(DateTime start, DateTime end) async {
    final notionDbs = await _db.getNotionDatabases();
    var allTags = await _db.getAllTags();

    for (final notionDb in notionDbs) {
      if (!notionDb.isEnabled) continue;

      try {
        // ── Pré-créer les tags catégorie depuis le schéma Notion ──
        try {
          final schema =
              await _notion.getDatabaseSchema(notionDb.effectiveSourceId);
          final missingTags = _notion.extractMissingCategoryTags(
            schema: schema,
            dbModel: notionDb,
            allTags: allTags,
          );
          for (final tag in missingTags) {
            await _db.insertTag(tag);
          }
          if (missingTags.isNotEmpty) {
            allTags = await _db.getAllTags();
          }
        } catch (_) {
          // Schema fetch failed — continuer avec les tags existants
        }

        final pages = await _notion.queryDatabase(
          databaseId: notionDb.effectiveSourceId,
          dateProperty: notionDb.startDateProperty,
          startDate: start,
          endDate: end,
        );

        for (final page in pages) {
          final event = _notion.pageToEvent(
            page: page,
            dbModel: notionDb,
            allTags: allTags,
          );

          if (event != null) {
            await _upsertEvent(event);
          }
        }

        await _db.upsertSyncState(SyncStateModel(
          source: notionDb.effectiveSourceId,
          lastSyncedAt: DateTime.now(),
          status: SyncStatus.success,
        ));
      } catch (e) {
        await _db.upsertSyncState(SyncStateModel(
          source: notionDb.effectiveSourceId,
          status: SyncStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _syncIcsSubscriptions() async {
    final subscriptions = await _db.getIcsSubscriptions();

    for (final sub in subscriptions) {
      if (!sub.isEnabled) continue;

      try {
        final events = await _ics.fetchSubscription(sub);

        // Supprimer les anciens événements de cet abonnement
        await _deleteEventsByIcsSubscription(sub.id.toString());

        for (final event in events) {
          await _upsertEvent(event.copyWith(
            icsSubscriptionId: sub.id.toString(),
          ));
        }

        final updatedSub = sub.copyWith(lastSyncedAt: DateTime.now());
        await _db.updateIcsSubscription(updatedSub);
      } catch (e) {
        // Ignorer les erreurs de sync .ics
      }
    }
  }

  /// Supprime les événements d'un abonnement .ics avant ré-import.
  Future<void> _deleteEventsByIcsSubscription(String subscriptionId) async {
    final db = await _db.database;
    await db.delete(
      AppConstants.tableEvents,
      where: 'ics_subscription_id = ? AND source = ?',
      whereArgs: [subscriptionId, AppConstants.sourceIcs],
    );
  }

  Future<void> _upsertEvent(EventModel event) async {
    if (event.remoteId == null) return;

    final existing = await _db.getEventByRemoteId(
      event.remoteId!,
      event.source,
    );

    if (existing == null) {
      await _db.insertEvent(event.copyWith(
        createdAt: DateTime.now(),
        syncedAt: DateTime.now(),
      ));
    } else {
      // Last-write-wins : si la version distante est plus récente
      final remoteUpdated = event.updatedAt ?? DateTime.now();
      final localUpdated = existing.updatedAt ?? DateTime(2000);

      if (remoteUpdated.isAfter(localUpdated)) {
        await _db.updateEvent(event.copyWith(
          id: existing.id,
          syncedAt: DateTime.now(),
        ));
      }
    }
  }

  Future<void> _rescheduleNotifications() async {
    final events = await _db.getEventsByDateRange(
      DateTime.now(),
      DateTime.now().add(const Duration(days: 7)),
    );

    for (final event in events) {
      if (event.reminderMinutes != null) {
        await _notifications.scheduleEventReminder(event);
      }
    }
  }

  /// Pousse un événement local vers Infomaniak.
  Future<void> pushEventToInfomaniak(EventModel event) async {
    if (!_infomaniak.isConfigured) return;
    if (event.id == null) return;

    final etag = await _infomaniak.putEvent(event);
    await _db.updateEvent(event.copyWith(
      syncedAt: DateTime.now(),
      etag: etag.isNotEmpty ? etag : null,
    ));
  }

  /// Pousse un événement/tâche vers Notion.
  Future<void> pushEventToNotion(EventModel event) async {
    if (!_notion.isConfigured) {
      throw Exception('Notion n\'est pas configuré. Vérifiez vos paramètres.');
    }

    final notionDbs = await _db.getNotionDatabases();
    if (notionDbs.isEmpty) {
      throw Exception('Aucune base de données Notion configurée.');
    }

    final allTags = await _db.getAllTags();
    final db = notionDbs.first; // V1 : première BDD par défaut

    // Récupérer le schéma pour détecter les types de propriétés
    Map<String, dynamic>? schema;
    try {
      schema = await _notion.getDatabaseSchema(db.effectiveSourceId);
    } catch (_) {}

    if (event.notionPageId != null) {
      await _notion.updatePage(
        pageId: event.notionPageId!,
        dbModel: db,
        event: event,
        allTags: allTags,
        schema: schema,
      );
    } else {
      final page = await _notion.createPage(
        dbModel: db,
        event: event,
        allTags: allTags,
        schema: schema,
      );
      await _db.updateEvent(event.copyWith(
        notionPageId: page['id'] as String?,
        remoteId: page['id'] as String?,
        syncedAt: DateTime.now(),
      ));
    }
  }

  /// Supprime un événement et propage la suppression vers la source.
  Future<void> deleteEvent(EventModel event) async {
    await _db.deleteEvent(event.id!);

    if (event.isFromInfomaniak && _infomaniak.isConfigured) {
      if (event.remoteId != null) {
        await _infomaniak.deleteEvent(
          event.remoteId!,
          etag: event.etag,
        );
      }
    } else if (event.isFromNotion && _notion.isConfigured) {
      if (event.notionPageId != null) {
        await _notion.archivePage(event.notionPageId!);
      }
    }

    if (event.id != null) {
      await _notifications.cancelEventReminder(event.id!);
    }
  }

  void dispose() {
    _syncStreamController.close();
  }
}
