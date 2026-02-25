import 'package:home_widget/home_widget.dart';
import '../core/database/database_helper.dart';
import '../core/models/event_model.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/platform_utils.dart';

/// Service de mise à jour du widget Android (7 jours glissants).
class WidgetService {
  static const String _appGroupId = 'com.example.unified_calendar';
  static const String _widgetName = 'CalendarWidgetProvider';

  /// Met à jour le widget avec les événements des 7 prochains jours.
  static Future<void> updateWidget() async {
    if (!PlatformUtils.supportsAndroidWidget) return;

    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      final now = DateTime.now();
      final end = now.add(const Duration(days: 7));

      final events = await DatabaseHelper.instance.getEventsByDateRange(
        CalendarDateUtils.startOfDay(now),
        CalendarDateUtils.endOfDay(end),
      );

      // Sérialiser les événements pour le widget
      final eventData = _buildWidgetData(events, now, end);

      await HomeWidget.saveWidgetData<String>(
        'widget_events',
        eventData,
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
