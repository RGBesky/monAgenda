import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database_helper.dart';
import '../core/models/event_model.dart';
import '../core/models/notion_database_model.dart';
import '../core/constants/app_constants.dart';
import '../services/background_worker_service.dart';
import '../services/sync_queue_worker.dart';
import '../services/logger_service.dart';
import '../services/widget_service.dart';

/// Plage de dates pour le chargement des événements.
class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange({required this.start, required this.end});

  @override
  bool operator ==(Object other) =>
      other is DateRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Provider de la plage de dates actuellement affichée.
final displayedDateRangeProvider = StateProvider<DateRange>((ref) {
  final now = DateTime.now();
  return DateRange(
    start: DateTime(now.year, now.month - 1),
    end: DateTime(now.year, now.month + 3),
  );
});

/// Provider de la date sélectionnée.
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Sources masquées (calendarId des BDD Notion / ICS désactivées).
/// Set<String> contenant les effectiveSourceId des BDD à masquer.
final hiddenSourcesProvider = StateProvider<Set<String>>((ref) => {});

/// Provider des bases de données Notion.
final notionDatabasesProvider =
    FutureProvider<List<NotionDatabaseModel>>((ref) async {
  return DatabaseHelper.instance.getNotionDatabases();
});

/// Provider des événements pour la plage affichée (avec filtrage sources).
final eventsInRangeProvider = FutureProvider<List<EventModel>>((ref) async {
  final range = ref.watch(displayedDateRangeProvider);
  final hidden = ref.watch(hiddenSourcesProvider);
  final events = await DatabaseHelper.instance
      .getEventsByDateRange(range.start, range.end);
  if (hidden.isEmpty) return events;
  return events.where((e) {
    // Filtrer Infomaniak
    if (e.source == AppConstants.sourceInfomaniak &&
        hidden.contains('infomaniak')) {
      return false;
    }
    // Pour les événements Notion, filtrer par calendarId (= effectiveSourceId)
    if (e.source == AppConstants.sourceNotion && e.calendarId != null) {
      return !hidden.contains(e.calendarId);
    }
    return true;
  }).toList();
});

/// Provider des événements pour un jour donné (avec filtrage sources).
final eventsForDayProvider =
    FutureProvider.family<List<EventModel>, DateTime>((ref, date) async {
  final start = DateTime(date.year, date.month, date.day);
  final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
  final hidden = ref.watch(hiddenSourcesProvider);
  final events = await DatabaseHelper.instance.getEventsByDateRange(start, end);
  if (hidden.isEmpty) return events;
  return events.where((e) {
    // Filtrer Infomaniak
    if (e.source == AppConstants.sourceInfomaniak &&
        hidden.contains('infomaniak')) {
      return false;
    }
    if (e.source == AppConstants.sourceNotion && e.calendarId != null) {
      return !hidden.contains(e.calendarId);
    }
    return true;
  }).toList();
});

class EventsNotifier extends AsyncNotifier<List<EventModel>> {
  @override
  Future<List<EventModel>> build() async {
    final range = ref.watch(displayedDateRangeProvider);
    return DatabaseHelper.instance.getEventsByDateRange(range.start, range.end);
  }

  Future<int> createEvent(EventModel event) async {
    final id = await DatabaseHelper.instance.insertEvent(event);
    ref.invalidateSelf();
    ref.invalidate(eventsInRangeProvider);
    // V2 : Optimistic UI — enqueue sync action pour push ultérieur
    if (event.source == AppConstants.sourceInfomaniak ||
        event.source == AppConstants.sourceNotion) {
      try {
        await DatabaseHelper.instance.enqueueSyncAction(
          action: SyncAction.createEvent,
          source: event.source,
          eventId: id,
          payload: jsonEncode(event.copyWith(id: id).toMap()),
        );
      } catch (e) {
        AppLogger.instance
            .error('EventsNotifier', 'enqueueSyncAction create failed', e);
      }
    }
    // V2 : reprogrammer les notifications en background
    BackgroundWorkerService.rescheduleNow();
    // Rafraîchir le widget Android
    WidgetService.updateWidget();
    return id;
  }

  Future<void> updateEvent(EventModel event) async {
    await DatabaseHelper.instance.updateEvent(event);
    ref.invalidateSelf();
    ref.invalidate(eventsInRangeProvider);
    // V2 : Enqueue sync action
    if (event.source == AppConstants.sourceInfomaniak ||
        event.source == AppConstants.sourceNotion) {
      try {
        await DatabaseHelper.instance.enqueueSyncAction(
          action: SyncAction.updateEvent,
          source: event.source,
          eventId: event.id,
          payload: jsonEncode(event.toMap()),
        );
      } catch (e) {
        AppLogger.instance
            .error('EventsNotifier', 'enqueueSyncAction update failed', e);
      }
    }
    // V2 : reprogrammer les notifications en background
    BackgroundWorkerService.rescheduleNow();
    // Rafraîchir le widget Android
    WidgetService.updateWidget();
  }

  Future<void> deleteEvent(int id) async {
    // DatabaseHelper.deleteEvent() fait déjà : is_deleted=1 + enqueueSyncAction('delete').
    // Ne PAS enqueue une 2e fois ici (double-enqueue provoquait des 404 au dépilage).
    final db = DatabaseHelper.instance;
    await db.deleteEvent(id);
    _invalidateAll();

    // V2 : reprogrammer les notifications en background
    BackgroundWorkerService.rescheduleNow();
    // Rafraîchir le widget Android
    WidgetService.updateWidget();
  }

  void refresh() {
    _invalidateAll();
  }

  /// Invalide tous les providers liés aux événements.
  void _invalidateAll() {
    ref.invalidateSelf();
    ref.invalidate(eventsInRangeProvider);
    // eventsForDayProvider est family → pas d'invalidation globale,
    // mais l'invalidation de eventsNotifierProvider suffit car il est
    // le provider racine que les vues day watchen indirectement.
  }
}

final eventsNotifierProvider =
    AsyncNotifierProvider<EventsNotifier, List<EventModel>>(
  EventsNotifier.new,
);

/// Map calendarId → nom de la base Notion (pour affichage dans les vues).
final notionDbNamesMapProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final dbs = await DatabaseHelper.instance.getNotionDatabases();
  return {for (final db in dbs) db.effectiveSourceId: db.name};
});
