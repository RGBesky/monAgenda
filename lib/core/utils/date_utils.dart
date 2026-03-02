import 'package:intl/intl.dart';

class CalendarDateUtils {
  static final DateFormat _isoDate = DateFormat('yyyyMMdd');
  static final DateFormat _isoDateTime = DateFormat("yyyyMMdd'T'HHmmss'Z'");
  static final DateFormat _displayDate = DateFormat('d MMMM yyyy', 'fr_FR');
  static final DateFormat _displayTime = DateFormat('HH:mm', 'fr_FR');
  static final DateFormat _displayDateTime = DateFormat('d MMM yyyy à HH:mm', 'fr_FR');
  static final DateFormat _displayShortDate = DateFormat('d MMM', 'fr_FR');

  static String toICalDate(DateTime date) => _isoDate.format(date.toUtc());

  static String toICalDateTime(DateTime date) =>
      _isoDateTime.format(date.toUtc());

  static DateTime? fromICalDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      if (value.contains('T')) {
        return DateTime.parse(
          value.replaceAll('-', '').replaceAll(':', ''),
        ).toLocal();
      }
      return DateTime(
        int.parse(value.substring(0, 4)),
        int.parse(value.substring(4, 6)),
        int.parse(value.substring(6, 8)),
      );
    } catch (_) {
      return null;
    }
  }

  static String formatDisplayDate(DateTime date) => _displayDate.format(date);
  static String formatDisplayTime(DateTime date) => _displayTime.format(date);
  static String formatDisplayDateTime(DateTime date) =>
      _displayDateTime.format(date);
  static String formatShortDate(DateTime date) =>
      _displayShortDate.format(date);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  static DateTime startOfWeek(DateTime date, {bool mondayFirst = true}) {
    final weekday = date.weekday;
    final daysToSubtract = mondayFirst ? (weekday - 1) : weekday % 7;
    return startOfDay(date.subtract(Duration(days: daysToSubtract)));
  }

  static DateTime endOfWeek(DateTime date, {bool mondayFirst = true}) {
    final start = startOfWeek(date, mondayFirst: mondayFirst);
    return endOfDay(start.add(const Duration(days: 6)));
  }

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

  static List<DateTime> daysInRange(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var current = startOfDay(start);
    while (!current.isAfter(startOfDay(end))) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  static String relativeDateLabel(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) return "Aujourd'hui";
    if (isSameDay(date, now.add(const Duration(days: 1)))) return 'Demain';
    if (isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Hier';
    return formatDisplayDate(date);
  }

  static String formatDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inDays >= 1) {
      final days = diff.inDays;
      return '$days jour${days > 1 ? 's' : ''}';
    }
    if (diff.inHours >= 1) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return minutes > 0
          ? '${hours}h${minutes.toString().padLeft(2, '0')}'
          : '${hours}h';
    }
    return '${diff.inMinutes} min';
  }
}
