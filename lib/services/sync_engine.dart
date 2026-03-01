import 'dart:async';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/models/event_model.dart';
import '../core/models/sync_state_model.dart';
import 'infomaniak_service.dart';
import 'notion_service.dart';
import 'notion_schema_validator.dart';
import 'ics_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';
import 'logger_service.dart';

/// Callback pour signaler une erreur serveur (429/500/503/timeout).
typedef ServerErrorCallback = void Function(String message);

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

  /// Callback optionnel pour notifier le provider d'erreur serveur.
  ServerErrorCallback? onServerError;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncEngine({
    required DatabaseHelper db,
    required InfomaniakService infomaniak,
    required NotionService notion,
    required IcsService ics,
    required NotificationService notifications,
    this.onServerError,
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
        if (_isServerError(e)) {
          onServerError?.call(_serverErrorMessage(e));
        }
        await _db.upsertSyncState(SyncStateModel(
          source: AppConstants.sourceInfomaniak,
          status: SyncStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }

    // Validation schéma Notion + Sync
    if (_notion.isConfigured) {
      try {
        // Valider le schéma avant la sync (avec auto-remap des propriétés renommées)
        final notionDbs = await _db.getNotionDatabases();
        final validator = NotionSchemaValidator(notion: _notion, db: _db);
        final validationResults = await validator.validateAll(notionDbs);

        // Signaler les remappings automatiques (info, pas erreur)
        final remappedDbs =
            validationResults.where((r) => r.hasRemappings).toList();
        if (remappedDbs.isNotEmpty) {
          for (final r in remappedDbs) {
            errors['Notion:${r.databaseName}'] =
                '⚑ Propriété(s) remappée(s) : ${r.remappedProperties.join(", ")}';
          }
          AppLogger.instance.info(
            'SyncEngine',
            '${remappedDbs.length} base(s) Notion avec propriétés remappées automatiquement',
          );
        }

        // Seules les bases véritablement invalides (après remap) sont des erreurs
        final invalidDbs = validationResults.where((r) => !r.isValid).toList();
        if (invalidDbs.isNotEmpty) {
          for (final r in invalidDbs) {
            errors['Notion:${r.databaseName}'] =
                'Schéma invalide — ${r.missingProperties.join(", ")}';
          }
          AppLogger.instance.warning(
            'SyncEngine',
            '${invalidDbs.length} base(s) Notion avec schéma invalide (après remap)',
          );
        }

        // Collecter les IDs des bases invalides pour les exclure de la sync
        final invalidDbIds = invalidDbs.map((r) => r.databaseId).toSet();

        // Relire les bases depuis SQLite (le remap a pu mettre à jour les mappings)
        await _syncNotion(start, end, skipDatabaseIds: invalidDbIds);
      } catch (e) {
        success = false;
        errors['Notion'] = e.toString();
        if (_isServerError(e)) {
          onServerError?.call(_serverErrorMessage(e));
        }
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

    // Extraire le calendarId depuis l'URL configurée
    final calUrl = _infomaniak.calendarUrl ?? '';
    final calendarId = calUrl.isNotEmpty
        ? Uri.parse(calUrl)
                .pathSegments
                .where((s) => s.isNotEmpty)
                .lastOrNull ??
            'default'
        : 'default';

    // Détecter un changement de calendrier
    final previousCalId = state?.syncToken?.startsWith('cal:') == true
        ? state!.syncToken!.substring(4).split('|').first
        : null;
    final calendarChanged =
        previousCalId != null && previousCalId != calendarId;

    if (calendarChanged) {
      // Purger les événements de l'ancien calendrier
      await _db.deleteEventsBySource(AppConstants.sourceInfomaniak);
      await _db.deleteSyncState(AppConstants.sourceInfomaniak);
    }

    // Vérifier si le calendrier a changé via ctag
    String? currentToken;
    try {
      currentToken = await _infomaniak.getSyncToken();
    } catch (_) {
      // ctag non disponible, on force la sync
    }

    // Composite token : calendarId + ctag pour détecter les changements
    final compositeToken = 'cal:$calendarId|${currentToken ?? ''}';

    // Vérifier si la DB a des événements Infomaniak
    final eventsCount = await _db.getEventsCount();

    if (!calendarChanged &&
        currentToken != null &&
        state?.syncToken == compositeToken &&
        state?.status == SyncStatus.success &&
        eventsCount > 0) {
      return;
    }

    // Full sync : supprimer les anciens et ré-importer
    await _db.deleteEventsBySource(AppConstants.sourceInfomaniak);

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
        calendarId: calendarId,
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
      syncToken: compositeToken,
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

  Future<void> _syncNotion(DateTime start, DateTime end,
      {Set<String> skipDatabaseIds = const {}}) async {
    // Relire depuis SQLite (le remap a pu mettre à jour les mappings)
    final notionDbs = await _db.getNotionDatabases();
    var allTags = await _db.getAllTags();

    for (final notionDb in notionDbs) {
      if (!notionDb.isEnabled) continue;

      // Exclure les bases dont le schéma est resté invalide après remap
      if (skipDatabaseIds.contains(notionDb.effectiveSourceId)) {
        AppLogger.instance.warning(
          'SyncEngine',
          'Base Notion "${notionDb.name}" ignorée (schéma invalide)',
        );
        continue;
      }

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
      // Ne JAMAIS ressusciter un event supprimé localement offline.
      // La sync_queue propagera la suppression vers le serveur distant.
      if (existing.isDeleted) return;

      // Pour les sources distantes (Notion, ICS), toujours écraser avec les
      // données fraîches : l'enrichissement local (description multi-propriétés,
      // tags…) peut changer même si la page Notion n'a pas été modifiée.
      // On conserve l'ID local et le createdAt.
      final isRemoteSource = event.source == AppConstants.sourceNotion ||
          event.source == AppConstants.sourceIcs;

      final remoteUpdated = event.updatedAt ?? DateTime.now();
      final localUpdated = existing.updatedAt ?? DateTime(2000);

      if (isRemoteSource || remoteUpdated.isAfter(localUpdated)) {
        await _db.updateEvent(event.copyWith(
          id: existing.id,
          syncedAt: DateTime.now(),
        ));
      } else if (existing.id != null) {
        // Toujours rafraîchir les tags même si le contenu n'a pas changé
        // (les tags dépendent du mapping courant, pas des données de l'event)
        await _db.updateEventTags(existing.id!, event.tagIds);

        // Backfill calendar_id si vide (events créés avant ce champ)
        if ((existing.calendarId == null || existing.calendarId!.isEmpty) &&
            event.calendarId != null &&
            event.calendarId!.isNotEmpty) {
          await _db.updateEvent(existing.copyWith(
            calendarId: event.calendarId,
          ));
        }
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
    if (!_infomaniak.isConfigured) {
      AppLogger.instance.error(
        'SyncEngine',
        'pushEventToInfomaniak: service NON configuré (username/password manquants)',
      );
      throw Exception(
          'Infomaniak n\'est pas configuré. Vérifiez vos paramètres.');
    }
    if (event.id == null) {
      AppLogger.instance
          .error('SyncEngine', 'pushEventToInfomaniak: event.id est null');
      throw Exception('Impossible de pousser un événement sans ID local.');
    }

    AppLogger.instance.info(
      'SyncEngine',
      'pushEventToInfomaniak: PUT event "${event.title}" (remoteId=${event.remoteId}, calUrl=${_infomaniak.calendarUrl})',
    );

    final etag = await _infomaniak.putEvent(event);
    await _db.updateEvent(event.copyWith(
      syncedAt: DateTime.now(),
      etag: etag.isNotEmpty ? etag : null,
    ));

    // Nettoyer la queue offline pour cet événement (push direct réussi)
    await _db.completePendingSyncActionsForEvent(event.id!);

    AppLogger.instance.info(
      'SyncEngine',
      'pushEventToInfomaniak: succès pour "${event.title}" (etag=$etag)',
    );
  }

  /// Pousse un événement/tâche vers Notion.
  Future<void> pushEventToNotion(EventModel event) async {
    if (!_notion.isConfigured) {
      AppLogger.instance.error(
        'SyncEngine',
        'pushEventToNotion: service NON configuré (API key manquante)',
      );
      throw Exception('Notion n\'est pas configuré. Vérifiez vos paramètres.');
    }

    final notionDbs = await _db.getNotionDatabases();
    if (notionDbs.isEmpty) {
      AppLogger.instance.error(
        'SyncEngine',
        'pushEventToNotion: aucune base de données Notion configurée',
      );
      throw Exception('Aucune base de données Notion configurée.');
    }

    final allTags = await _db.getAllTags();

    // Déterminer la BDD cible : celle du calendarId de l'événement, ou la première
    final db = (event.calendarId != null
            ? notionDbs
                .where((d) => d.effectiveSourceId == event.calendarId)
                .firstOrNull
            : null) ??
        notionDbs.first;

    AppLogger.instance.info(
      'SyncEngine',
      'pushEventToNotion: push "${event.title}" vers BDD "${db.name}" (pageId=${event.notionPageId})',
    );

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
        calendarId: db.effectiveSourceId,
        syncedAt: DateTime.now(),
      ));
    }

    // Nettoyer la queue offline pour cet événement (push direct réussi)
    if (event.id != null) {
      await _db.completePendingSyncActionsForEvent(event.id!);
    }

    AppLogger.instance.info(
      'SyncEngine',
      'pushEventToNotion: succès pour "${event.title}"',
    );
  }

  /// Supprime un événement et propage la suppression vers la source.
  Future<void> deleteEvent(EventModel event) async {
    await _db.deleteEvent(event.id!);

    try {
      bool remoteDeleteSuccess = false;
      if (event.isFromInfomaniak && _infomaniak.isConfigured) {
        if (event.remoteId != null) {
          await _infomaniak.deleteEvent(
            event.remoteId!,
            etag: event.etag,
          );
          remoteDeleteSuccess = true;
        }
      } else if (event.isFromNotion && _notion.isConfigured) {
        if (event.notionPageId != null) {
          await _notion.archivePage(event.notionPageId!);
          remoteDeleteSuccess = true;
        }
      }

      // Si la suppression distante a réussi, nettoyer l'entrée sync_queue
      // (évite un retry inutile qui retournera 404).
      if (remoteDeleteSuccess && event.id != null) {
        final db = await _db.database;
        await db.delete(
          AppConstants.tableSyncQueue,
          where: 'event_id = ? AND action = ? AND status = ?',
          whereArgs: [event.id, 'delete', 'pending'],
        );
      }
    } catch (e) {
      // La suppression locale est déjà faite.
      // Si le serveur échoue (404, réseau…), on logue sans propager.
      // La sync_queue prendra le relais au prochain cycle.
      AppLogger.instance.warning(
        'SyncEngine',
        'Suppression distante échouée : $e',
      );
    }

    if (event.id != null) {
      await _notifications.cancelEventReminder(event.id!);
    }
  }

  void dispose() {
    _syncStreamController.close();
  }

  // ── Détection d'erreurs serveur (mutualisée) ──────────────────────────

  /// Détecte si l'erreur est liée au serveur (429, 500, 503, timeout).
  bool _isServerError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 429 || code == 500 || code == 503) return true;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return true;
      }
    }
    if (e is TimeoutException) return true;
    return false;
  }

  /// Génère un message d'erreur lisible pour les erreurs serveur.
  String _serverErrorMessage(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 429) return 'Serveur surchargé (429 — trop de requêtes)';
      if (code == 500) return 'Erreur interne du serveur (500)';
      if (code == 503) return 'Serveur indisponible (503)';
      return 'Délai de connexion dépassé';
    }
    return 'Synchronisation en erreur (timeout)';
  }
}
