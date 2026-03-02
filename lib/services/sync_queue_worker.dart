import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import '../core/models/event_model.dart';
import '../core/models/notion_database_model.dart';
import 'infomaniak_service.dart';
import 'notion_service.dart';
import 'logger_service.dart';

/// Actions possibles dans la queue de sync.
class SyncAction {
  static const String createEvent = 'create';
  static const String updateEvent = 'update';
  static const String deleteEvent = 'delete';
}

/// Callback pour signaler les erreurs serveur (429/500/503/timeout).
typedef ServerErrorCallback = void Function(String errorMessage);

/// Worker qui dépile la sync_queue quand la connectivité est disponible.
/// Fonctionne en mode "best effort" : les erreurs sont loguées, pas propagées.
class SyncQueueWorker {
  final DatabaseHelper _db;
  final InfomaniakService _infomaniak;
  final NotionService _notion;
  final _log = AppLogger.instance;

  /// Callback optionnel pour notifier le provider d'erreur serveur.
  ServerErrorCallback? onServerError;

  bool _isProcessing = false;

  SyncQueueWorker({
    required DatabaseHelper db,
    required InfomaniakService infomaniak,
    required NotionService notion,
    this.onServerError,
  })  : _db = db,
        _infomaniak = infomaniak,
        _notion = notion;

  /// Traite toutes les actions en attente dans la queue.
  /// Retourne le nombre d'actions traitées avec succès.
  Future<int> processQueue() async {
    if (_isProcessing) return 0;
    _isProcessing = true;

    int successCount = 0;

    try {
      final pendingActions = await _db.getPendingSyncActions();
      _log.info('SyncQueue', '${pendingActions.length} action(s) en attente');

      for (final action in pendingActions) {
        final id = action['id'] as int;
        final actionType = action['action'] as String;
        final source = action['source'] as String;
        final payload = action['payload'] as String;

        try {
          await _processAction(actionType, source, payload);
          await _db.completeSyncAction(id);
          successCount++;
          _log.info('SyncQueue', 'Action $actionType/$source traitée');
        } catch (e) {
          await _db.failSyncAction(id, e.toString());
          _log.error('SyncQueue', 'Échec $actionType/$source', e);

          // Détecter les erreurs serveur (saturé, rate-limit, timeout)
          if (_isServerError(e)) {
            final msg = _serverErrorMessage(e);
            onServerError?.call(msg);
          }
        }
      }
    } finally {
      _isProcessing = false;
    }

    return successCount;
  }

  Future<void> _processAction(
    String actionType,
    String source,
    String payload,
  ) async {
    final data = jsonDecode(payload) as Map<String, dynamic>;

    switch (source) {
      case AppConstants.sourceInfomaniak:
        await _processInfomaniakAction(actionType, data);
        break;
      case AppConstants.sourceNotion:
        await _processNotionAction(actionType, data);
        break;
      default:
        _log.warning('SyncQueue', 'Source inconnue : $source');
    }
  }

  Future<void> _processInfomaniakAction(
    String actionType,
    Map<String, dynamic> data,
  ) async {
    if (!_infomaniak.isConfigured) {
      throw Exception('Infomaniak non configuré');
    }

    switch (actionType) {
      case SyncAction.createEvent:
      case SyncAction.updateEvent:
        final event = EventModel.fromMap(data);
        _log.info('SyncQueue',
            'PUT Infomaniak: "${event.title}" (remoteId=${event.remoteId})');
        await _infomaniak.putEvent(event);
        break;
      case SyncAction.deleteEvent:
        final remoteId = data['remote_id'] as String?;
        final calendarUrl = data['calendar_id'] as String?;
        final etag = data['etag'] as String?;
        if (remoteId != null) {
          _log.info('SyncQueue', 'DELETE Infomaniak: remoteId=$remoteId');
          await _infomaniak.deleteEvent(
            remoteId,
            calendarUrl: calendarUrl,
            etag: etag,
          );
        }
        break;
    }
  }

  Future<void> _processNotionAction(
    String actionType,
    Map<String, dynamic> data,
  ) async {
    if (!_notion.isConfigured) {
      throw Exception('Notion non configuré');
    }

    switch (actionType) {
      case SyncAction.createEvent:
        final event = EventModel.fromMap(data);
        final notionDbs = await _db.getNotionDatabases();
        if (notionDbs.isEmpty) {
          throw Exception('Aucune base de données Notion configurée');
        }
        // Déterminer la BDD cible via calendarId ou fallback première BDD
        final db = _findNotionDb(notionDbs, event.calendarId);
        final allTags = await _db.getAllTags();

        Map<String, dynamic>? schema;
        try {
          schema = await _notion.getDatabaseSchema(db.effectiveSourceId);
        } catch (e) {
          _log.warning('SyncQueue', 'getDatabaseSchema failed (create): $e');
        }

        _log.info('SyncQueue',
            'CREATE Notion: "${event.title}" vers BDD "${db.name}"');
        final page = await _notion.createPage(
          dbModel: db,
          event: event,
          allTags: allTags,
          schema: schema,
        );
        // Mettre à jour l'événement local avec le pageId Notion
        if (event.id != null) {
          await _db.updateEvent(event.copyWith(
            notionPageId: page['id'] as String?,
            remoteId: page['id'] as String?,
            calendarId: db.effectiveSourceId,
            syncedAt: DateTime.now(),
          ));
        }
        break;

      case SyncAction.updateEvent:
        final event = EventModel.fromMap(data);
        if (event.notionPageId == null) {
          _log.warning('SyncQueue',
              'UPDATE Notion: pas de pageId pour "${event.title}", ignoré');
          return;
        }
        final notionDbs = await _db.getNotionDatabases();
        if (notionDbs.isEmpty) {
          throw Exception('Aucune base de données Notion configurée');
        }
        final db = _findNotionDb(notionDbs, event.calendarId);
        final allTags = await _db.getAllTags();

        Map<String, dynamic>? schema;
        try {
          schema = await _notion.getDatabaseSchema(db.effectiveSourceId);
        } catch (e) {
          _log.warning('SyncQueue', 'getDatabaseSchema failed (update): $e');
        }

        _log.info('SyncQueue',
            'UPDATE Notion: "${event.title}" (pageId=${event.notionPageId})');
        await _notion.updatePage(
          pageId: event.notionPageId!,
          dbModel: db,
          event: event,
          allTags: allTags,
          schema: schema,
        );
        break;

      case SyncAction.deleteEvent:
        final pageId = data['notion_page_id'] as String?;
        if (pageId != null) {
          _log.info('SyncQueue', 'DELETE Notion: pageId=$pageId');
          await _notion.archivePage(pageId);
        }
        break;
    }
  }

  /// Trouve la BDD Notion correspondant au calendarId, ou la première par défaut.
  NotionDatabaseModel _findNotionDb(
    List<NotionDatabaseModel> dbs,
    String? calendarId,
  ) {
    if (calendarId != null) {
      final match =
          dbs.where((d) => d.effectiveSourceId == calendarId).firstOrNull;
      if (match != null) return match;
    }
    return dbs.first;
  }

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
