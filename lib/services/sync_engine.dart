import 'dart:async';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/models/event_model.dart';
import '../core/models/sync_state_model.dart';
import 'infomaniak_service.dart';
import 'notion_service.dart';
import 'ics_service.dart';
import 'notification_service.dart';

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
  Future<SyncResult> syncAll({
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    if (_isSyncing) return SyncResult.failure;
    _isSyncing = true;
    _syncStreamController.add(SyncStatus.syncing);

    final start = rangeStart ??
        DateTime.now().subtract(const Duration(days: 30));
    final end = rangeEnd ??
        DateTime.now().add(const Duration(days: 365));

    var success = true;

    // Sync Infomaniak
    if (_infomaniak.isConfigured) {
      try {
        await _syncInfomaniak(start, end);
      } catch (e) {
        success = false;
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
        final notionDbs = await _db.getNotionDatabases();
        for (final db in notionDbs) {
          await _db.upsertSyncState(SyncStateModel(
            source: db.notionId,
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
    }

    _isSyncing = false;
    _syncStreamController.add(success ? SyncStatus.success : SyncStatus.error);

    return success ? SyncResult.success : SyncResult.partialSuccess;
  }

  Future<void> _syncInfomaniak(DateTime start, DateTime end) async {
    final state = await _db.getSyncState(AppConstants.sourceInfomaniak);

    // Vérifier si le calendrier a changé via ctag
    final currentToken = await _infomaniak.getSyncToken();
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

    for (final raw in rawEvents) {
      final ical = raw['ical'] as String;
      final etag = raw['etag'] as String?;

      final event = InfomaniakService.parseICalEvent(
        ical,
        calendarId: 'default',
        etag: etag,
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

    // Reprogrammer les notifications
    await _rescheduleNotifications();

    // Mettre à jour le widget Android
    await _updateWidget();
  }

  Future<void> _updateWidget() async {
    try {
      // Import conditionnel — pas disponible sur Linux
      // ignore: avoid_dynamic_calls
      await _tryUpdateWidget();
    } catch (_) {}
  }

  Future<void> _tryUpdateWidget() async {
    // Appel via dynamic pour éviter l'import conditionnel
    // home_widget gère la disponibilité de la plateforme
    const platform = bool.fromEnvironment('dart.library.io');
    if (platform) {
      // WidgetService.updateWidget() appelé depuis la couche app
    }
  }

  Future<void> _syncNotion(DateTime start, DateTime end) async {
    final notionDbs = await _db.getNotionDatabases();
    final allTags = await _db.getAllTags();

    for (final notionDb in notionDbs) {
      if (!notionDb.isEnabled) continue;

      try {
        final pages = await _notion.queryDatabase(
          databaseId: notionDb.notionId,
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
          source: notionDb.notionId,
          lastSyncedAt: DateTime.now(),
          status: SyncStatus.success,
        ));
      } catch (e) {
        await _db.upsertSyncState(SyncStateModel(
          source: notionDb.notionId,
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
        final icsServiceInstance = IcsService();
        final events = await icsServiceInstance.fetchSubscription(sub);

        // Supprimer les anciens événements de cet abonnement
        // (sera remplacé par les nouveaux)
        final db = _db;

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

    final etag = await _infomaniak.putEvent(event);
    await _db.updateEvent(event.copyWith(
      syncedAt: DateTime.now(),
      etag: etag.isNotEmpty ? etag : null,
    ));
  }

  /// Pousse un événement/tâche vers Notion.
  Future<void> pushEventToNotion(EventModel event) async {
    if (!_notion.isConfigured) return;

    final notionDbs = await _db.getNotionDatabases();
    if (notionDbs.isEmpty) return;

    final allTags = await _db.getAllTags();
    final db = notionDbs.first; // V1 : première BDD par défaut

    if (event.notionPageId != null) {
      await _notion.updatePage(
        pageId: event.notionPageId!,
        dbModel: db,
        event: event,
        allTags: allTags,
      );
    } else {
      final page = await _notion.createPage(
        dbModel: db,
        event: event,
        allTags: allTags,
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
