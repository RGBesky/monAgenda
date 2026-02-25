import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../core/models/event_model.dart';
import '../core/models/ics_subscription_model.dart';
import '../core/utils/date_utils.dart';

/// Service pour les abonnements .ics publics (lecture seule).
class IcsService {
  final Dio _dio;

  IcsService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// Télécharge et parse un calendrier .ics public.
  Future<List<EventModel>> fetchSubscription(
    IcsSubscriptionModel subscription,
  ) async {
    final response = await _dio.get<String>(subscription.url);
    if (response.data == null) return [];
    return parseIcsContent(
      response.data!,
      subscriptionId: subscription.id.toString(),
    );
  }

  /// Parse un contenu .ics en liste d'EventModel.
  static List<EventModel> parseIcsContent(
    String content, {
    String? subscriptionId,
  }) {
    final events = <EventModel>[];
    final vevents = _splitVEvents(content);

    for (final vevent in vevents) {
      final event = _parseVEvent(vevent, subscriptionId: subscriptionId);
      if (event != null) events.add(event);
    }

    return events;
  }

  /// Parse un fichier .ics importé localement.
  static List<EventModel> parseIcsFile(String content) {
    return parseIcsContent(content);
  }

  static List<String> _splitVEvents(String content) {
    final events = <String>[];
    final lines = content.split(RegExp(r'\r?\n'));
    final buffer = StringBuffer();
    bool inEvent = false;

    for (final line in lines) {
      if (line.trim() == 'BEGIN:VEVENT') {
        inEvent = true;
        buffer.clear();
        buffer.writeln(line);
      } else if (line.trim() == 'END:VEVENT') {
        buffer.writeln(line);
        events.add(buffer.toString());
        inEvent = false;
      } else if (inEvent) {
        // Gestion des lignes pliées (RFC 5545)
        if (line.startsWith(' ') || line.startsWith('\t')) {
          buffer.write(line.trim());
        } else {
          buffer.writeln(line);
        }
      }
    }

    return events;
  }

  static EventModel? _parseVEvent(
    String vevent, {
    String? subscriptionId,
  }) {
    try {
      String? getValue(String key) {
        final regex = RegExp('$key[^:]*:(.+)', caseSensitive: false);
        return regex.firstMatch(vevent)?.group(1)?.trim();
      }

      final uid = getValue('UID');
      final summary = getValue('SUMMARY');
      if (uid == null || summary == null) return null;

      final dtstart = getValue('DTSTART') ?? '';
      final dtend = getValue('DTEND');
      final rrule = getValue('RRULE');
      final location = getValue('LOCATION');
      final description = getValue('DESCRIPTION');

      final isAllDay =
          vevent.contains('DTSTART;VALUE=DATE') && !dtstart.contains('T');

      final startDate = dtstart.isNotEmpty
          ? CalendarDateUtils.fromICalDate(dtstart)
          : DateTime.now();

      DateTime endDate;
      if (dtend != null && dtend.isNotEmpty) {
        endDate = CalendarDateUtils.fromICalDate(dtend);
      } else {
        endDate = isAllDay
            ? startDate
            : startDate.add(const Duration(hours: 1));
      }

      EventType type = EventType.appointment;
      if (isAllDay) type = EventType.allDay;
      if (rrule != null && rrule.isNotEmpty) type = EventType.recurring;

      return EventModel(
        remoteId: uid,
        source: AppConstants.sourceIcs,
        type: type,
        title: _unescapeIcs(summary),
        startDate: startDate,
        endDate: endDate,
        isAllDay: isAllDay,
        location: location != null ? _unescapeIcs(location) : null,
        description: description != null ? _unescapeIcs(description) : null,
        rrule: rrule,
        icsSubscriptionId: subscriptionId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  static String _unescapeIcs(String value) {
    return value
        .replaceAll('\\n', '\n')
        .replaceAll('\\,', ',')
        .replaceAll('\\;', ';')
        .replaceAll('\\\\', '\\');
  }

  /// Exporte une liste d'événements en format .ics.
  static String exportToIcs(List<EventModel> events, {String calName = 'Unified Calendar'}) {
    final sb = StringBuffer();
    sb.writeln('BEGIN:VCALENDAR');
    sb.writeln('VERSION:2.0');
    sb.writeln('PRODID:-//Unified Calendar//FR');
    sb.writeln('CALSCALE:GREGORIAN');
    sb.writeln('X-WR-CALNAME:$calName');

    for (final event in events) {
      sb.writeln('BEGIN:VEVENT');
      sb.writeln('UID:${event.remoteId ?? event.id}@unified-calendar');
      sb.writeln('DTSTAMP:${CalendarDateUtils.toICalDateTime(DateTime.now())}');

      if (event.isAllDay) {
        sb.writeln(
          'DTSTART;VALUE=DATE:${CalendarDateUtils.toICalDate(event.startDate)}',
        );
        sb.writeln(
          'DTEND;VALUE=DATE:${CalendarDateUtils.toICalDate(event.endDate)}',
        );
      } else {
        sb.writeln(
          'DTSTART:${CalendarDateUtils.toICalDateTime(event.startDate)}',
        );
        sb.writeln(
          'DTEND:${CalendarDateUtils.toICalDateTime(event.endDate)}',
        );
      }

      sb.writeln('SUMMARY:${_escapeIcs(event.title)}');
      if (event.location != null) {
        sb.writeln('LOCATION:${_escapeIcs(event.location!)}');
      }
      if (event.description != null) {
        sb.writeln('DESCRIPTION:${_escapeIcs(event.description!)}');
      }
      if (event.rrule != null) {
        sb.writeln('RRULE:${event.rrule}');
      }

      final categories = event.tags
          .where((t) => t.isCategory)
          .map((t) => t.name)
          .join(',');
      if (categories.isNotEmpty) {
        sb.writeln('CATEGORIES:$categories');
      }

      sb.writeln('END:VEVENT');
    }

    sb.writeln('END:VCALENDAR');
    return sb.toString();
  }

  static String _escapeIcs(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }
}
