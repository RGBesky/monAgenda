import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database_helper.dart';
import '../core/models/event_model.dart';
import '../core/models/notion_database_model.dart';
import '../core/constants/app_constants.dart';

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
    return id;
  }

  Future<void> updateEvent(EventModel event) async {
    await DatabaseHelper.instance.updateEvent(event);
    ref.invalidateSelf();
    ref.invalidate(eventsInRangeProvider);
  }

  Future<void> deleteEvent(int id) async {
    await DatabaseHelper.instance.deleteEvent(id);
    ref.invalidateSelf();
    ref.invalidate(eventsInRangeProvider);
  }

  void refresh() {
    ref.invalidateSelf();
    ref.invalidate(eventsInRangeProvider);
  }
}

final eventsNotifierProvider =
    AsyncNotifierProvider<EventsNotifier, List<EventModel>>(
  EventsNotifier.new,
);
