import 'package:home_widget/home_widget.dart';
import '../core/database/database_helper.dart';
import '../core/models/event_model.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/platform_utils.dart';

/// Service de mise à jour du widget Android (7 prochains RDV).
class WidgetService {
  static const String _appGroupId = 'com.example.unified_calendar';
  static const String _widgetName = 'CalendarWidgetProvider';
  static const int _maxEvents = 7;

  /// Dernière signature (évite les updates inutiles).
  static String _lastSignature = '';

  /// Met à jour le widget avec les 7 prochains événements.
  static Future<void> updateWidget() async {
    if (!PlatformUtils.supportsAndroidWidget) return;

    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      final now = DateTime.now();
      final end = now.add(const Duration(days: 14));

      final events = await DatabaseHelper.instance.getEventsByDateRange(
        CalendarDateUtils.startOfDay(now),
        CalendarDateUtils.endOfDay(end),
      );

      // Trier par date puis prendre les 7 premiers
      events.sort((a, b) => a.startDate.compareTo(b.startDate));
      final next = events.take(_maxEvents).toList();

      // Déduplication : ne mettre à jour que si la liste a changé
      final signature =
          next.map((e) => '${e.id}|${e.title}|${e.startDate}').join(';');
      if (signature == _lastSignature) return;
      _lastSignature = signature;

      // Sauver chaque événement individuellement
      for (int i = 0; i < _maxEvents; i++) {
        if (i < next.length) {
          final e = next[i];
          final time = e.isAllDay
              ? 'Toute la journée'
              : CalendarDateUtils.formatDisplayTime(e.startDate);
          final date = CalendarDateUtils.relativeDateLabel(e.startDate);
          await HomeWidget.saveWidgetData<String>('event_${i}_title', e.title);
          await HomeWidget.saveWidgetData<String>(
              'event_${i}_time', '$date · $time');
        } else {
          await HomeWidget.saveWidgetData<String>('event_${i}_title', '');
          await HomeWidget.saveWidgetData<String>('event_${i}_time', '');
        }
      }

      await HomeWidget.saveWidgetData<int>('event_count', next.length);

      // Legacy : garder aussi la clé texte pour compatibilité
      await HomeWidget.saveWidgetData<String>(
        'widget_events',
        _buildWidgetData(events, now, end),
      );

      await HomeWidget.updateWidget(
        androidName: _widgetName,
      );
    } catch (e) {
      // Widget non critique
    }
  }

  static String _buildWidgetData(
    List<EventModel> events,
    DateTime start,
    DateTime end,
  ) {
    final buffer = StringBuffer();
    final days = CalendarDateUtils.daysInRange(start, end);

    for (final day in days) {
      final dayEvents = events
          .where((e) => CalendarDateUtils.isSameDay(e.startDate, day))
          .take(3)
          .toList();

      if (dayEvents.isEmpty) continue;

      final label = CalendarDateUtils.relativeDateLabel(day);
      buffer.writeln('=== $label ===');

      for (final event in dayEvents) {
        final time = event.isAllDay
            ? 'Toute la journée'
            : CalendarDateUtils.formatDisplayTime(event.startDate);
        buffer.writeln('$time  ${event.title}');
      }
    }

    return buffer.toString().trim();
  }
}
