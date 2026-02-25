import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../core/models/event_model.dart';
import '../core/models/tag_model.dart';
import '../core/utils/date_utils.dart';

/// Service CalDAV pour Infomaniak Calendar.
/// Authentification via Basic Auth (username + mot de passe d'application).
/// URL de synchronisation : https://sync.infomaniak.com/calendars/{user}/{calendar-uuid}
class InfomaniakService {
  final Dio _calDavDio;
  String? _username;
  String? _appPassword;
  String? _calendarUrl; // URL CalDAV complète

  InfomaniakService()
      : _calDavDio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

  void setCredentials({
    required String username,
    required String appPassword,
    String? calendarUrl,
  }) {
    _username = username;
    _appPassword = appPassword;
    _calendarUrl = calendarUrl;

    // Basic Auth
    final basicAuth = base64Encode(utf8.encode('$username:$appPassword'));
    _calDavDio.options.headers['Authorization'] = 'Basic $basicAuth';
  }

  bool get isConfigured =>
      _username != null &&
      _username!.isNotEmpty &&
      _appPassword != null &&
      _appPassword!.isNotEmpty;

  /// Valide les identifiants en faisant un PROPFIND sur l'URL CalDAV.
  Future<Map<String, dynamic>> validateCredentials() async {
    if (_username == null || _appPassword == null) {
      throw Exception('Identifiants non configurés');
    }

    // Tester l'accès avec un PROPFIND sur le calendrier ou la racine
    final testUrl = _calendarUrl ??
        '${AppConstants.infomaniakCalDavBase}/calendars/$_username/';

    final response = await _calDavDio.request(
      testUrl,
      options: Options(
        method: 'PROPFIND',
        headers: {
          'Content-Type': 'application/xml; charset=utf-8',
          'Depth': '0',
        },
      ),
      data: '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:displayname/>
    <d:resourcetype/>
  </d:prop>
</d:propfind>''',
    );

    if (response.statusCode == 207 || response.statusCode == 200) {
      final name = _extractDisplayName(response.data as String);
      return {'displayname': name, 'username': _username};
    }

    throw Exception('Authentification échouée (${response.statusCode})');
  }

  /// Récupère la liste des calendriers disponibles pour l'utilisateur.
  Future<List<Map<String, dynamic>>> getCalendars() async {
    final baseUrl =
        '${AppConstants.infomaniakCalDavBase}/calendars/$_username/';

    final response = await _calDavDio.request(
      baseUrl,
      options: Options(
        method: 'PROPFIND',
        headers: {
          'Content-Type': 'application/xml; charset=utf-8',
          'Depth': '1',
        },
      ),
      data: '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:displayname/>
    <d:resourcetype/>
    <c:calendar-description/>
  </d:prop>
</d:propfind>''',
    );
    return _parseCalendarList(response.data as String);
  }

  /// Récupère les événements dans une plage de dates.
  Future<List<Map<String, dynamic>>> fetchEvents({
    required DateTime start,
    required DateTime end,
    String? calendarUrl,
  }) async {
    final url = calendarUrl ?? _calendarUrl;
    if (url == null || url.isEmpty) {
      throw Exception('URL du calendrier non configurée');
    }

    final calUrl = url.endsWith('/') ? url : '$url/';

    final response = await _calDavDio.request(
      calUrl,
      options: Options(
        method: 'REPORT',
        headers: {
          'Content-Type': 'application/xml; charset=utf-8',
          'Depth': '1',
        },
      ),
      data: '''<?xml version="1.0" encoding="utf-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:getetag/>
    <c:calendar-data/>
  </d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VEVENT">
        <c:time-range start="${CalendarDateUtils.toICalDateTime(start)}"
                      end="${CalendarDateUtils.toICalDateTime(end)}"/>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>''',
    );

    return _parseEventMultiStatus(response.data as String);
  }

  /// Crée ou met à jour un événement via PUT CalDAV.
  Future<String> putEvent(EventModel event, {String? calendarUrl}) async {
    final url = calendarUrl ?? _calendarUrl;
    if (url == null || url.isEmpty) {
      throw Exception('URL du calendrier non configurée');
    }

    final calUrl = url.endsWith('/') ? url : '$url/';
    final uid = event.remoteId ?? _generateUid();
    final eventUrl = '$calUrl$uid.ics';

    final icsData = _eventToIcs(event.copyWith(remoteId: uid));

    final response = await _calDavDio.put(
      eventUrl,
      data: icsData,
      options: Options(
        headers: {
          'Content-Type': 'text/calendar; charset=utf-8',
          if (event.etag != null) 'If-Match': event.etag,
        },
      ),
    );

    return response.headers.value('ETag') ?? '';
  }

  /// Supprime un événement via DELETE CalDAV.
  Future<void> deleteEvent(String uid,
      {String? calendarUrl, String? etag}) async {
    final url = calendarUrl ?? _calendarUrl;
    if (url == null || url.isEmpty) return;

    final calUrl = url.endsWith('/') ? url : '$url/';
    final eventUrl = '$calUrl$uid.ics';

    await _calDavDio.delete(
      eventUrl,
      options: Options(
        headers: {
          if (etag != null) 'If-Match': etag,
        },
      ),
    );
  }

  /// Récupère le sync-token (ctag) du calendrier.
  Future<String?> getSyncToken({String? calendarUrl}) async {
    final url = calendarUrl ?? _calendarUrl;
    if (url == null || url.isEmpty) return null;

    final calUrl = url.endsWith('/') ? url : '$url/';

    final response = await _calDavDio.request(
      calUrl,
      options: Options(
        method: 'PROPFIND',
        headers: {
          'Content-Type': 'application/xml; charset=utf-8',
          'Depth': '0',
        },
      ),
      data: '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/">
  <d:prop>
    <cs:getctag/>
    <d:sync-token/>
  </d:prop>
</d:propfind>''',
    );

    return _extractSyncToken(response.data as String);
  }

  // ============================================================
  // Helpers iCalendar
  // ============================================================

  String _eventToIcs(EventModel event) {
    final sb = StringBuffer();
    sb.writeln('BEGIN:VCALENDAR');
    sb.writeln('VERSION:2.0');
    sb.writeln('PRODID:-//Unified Calendar//FR');
    sb.writeln('CALSCALE:GREGORIAN');
    sb.writeln('BEGIN:VEVENT');
    sb.writeln('UID:${event.remoteId}');
    sb.writeln('DTSTAMP:${CalendarDateUtils.toICalDateTime(DateTime.now())}');

    if (event.isAllDay) {
      sb.writeln(
          'DTSTART;VALUE=DATE:${CalendarDateUtils.toICalDate(event.startDate)}');
      sb.writeln(
          'DTEND;VALUE=DATE:${CalendarDateUtils.toICalDate(event.endDate)}');
    } else {
      sb.writeln(
          'DTSTART:${CalendarDateUtils.toICalDateTime(event.startDate)}');
      sb.writeln('DTEND:${CalendarDateUtils.toICalDateTime(event.endDate)}');
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

    // Tags catégories → CATEGORIES
    final categories = event.tags
        .where((t) => t.isCategory)
        .map((t) => t.infomaniakMapping ?? t.name)
        .join(',');
    if (categories.isNotEmpty) {
      sb.writeln('CATEGORIES:$categories');
    }

    // Tag priorité → PRIORITY (1=urgent, 9=basse)
    final priority = event.tags.where((t) => t.isPriority).firstOrNull;
    if (priority != null) {
      sb.writeln('PRIORITY:${priority.infomaniakMapping ?? '5'}');
    }

    // Participants
    for (final participant in event.participants) {
      sb.writeln(
        'ATTENDEE;CN=${participant.name ?? participant.email}:mailto:${participant.email}',
      );
    }

    // Rappel
    if (event.reminderMinutes != null) {
      sb.writeln('BEGIN:VALARM');
      sb.writeln('TRIGGER:-PT${event.reminderMinutes}M');
      sb.writeln('ACTION:DISPLAY');
      sb.writeln('DESCRIPTION:Rappel');
      sb.writeln('END:VALARM');
    }

    sb.writeln('END:VEVENT');
    sb.writeln('END:VCALENDAR');
    return sb.toString();
  }

  String _escapeIcs(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  String _generateUid() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$timestamp-unified-calendar@infomaniak';
  }

  String _extractDisplayName(String xmlResponse) {
    final nameRegex = RegExp(r'<d:displayname>(.*?)</d:displayname>');
    final match = nameRegex.firstMatch(xmlResponse);
    return match?.group(1) ?? 'Calendrier';
  }

  List<Map<String, dynamic>> _parseCalendarList(String xmlResponse) {
    final calendars = <Map<String, dynamic>>[];
    final hrefRegex = RegExp(r'<d:href>(.*?)</d:href>');
    final nameRegex = RegExp(r'<d:displayname>(.*?)</d:displayname>');

    final hrefs = hrefRegex.allMatches(xmlResponse).toList();
    final names = nameRegex.allMatches(xmlResponse).toList();

    for (int i = 0; i < hrefs.length; i++) {
      final href = hrefs[i].group(1) ?? '';
      if (href.endsWith('/') && !href.endsWith('//')) {
        final segments = href.split('/').where((s) => s.isNotEmpty).toList();
        final id = segments.isNotEmpty ? segments.last : href;
        calendars.add({
          'id': id,
          'href': href,
          'name': i < names.length ? names[i].group(1) ?? id : id,
          'url': '${AppConstants.infomaniakCalDavBase}$href',
        });
      }
    }

    return calendars;
  }

  List<Map<String, dynamic>> _parseEventMultiStatus(String xmlResponse) {
    final events = <Map<String, dynamic>>[];
    final responseRegex = RegExp(
      r'<d:response>(.*?)</d:response>',
      dotAll: true,
    );
    final etagRegex = RegExp(r'<d:getetag>(.*?)</d:getetag>');
    final calDataRegex = RegExp(
      r'<c:calendar-data>(.*?)</c:calendar-data>',
      dotAll: true,
    );

    for (final match in responseRegex.allMatches(xmlResponse)) {
      final block = match.group(1) ?? '';
      final etag = etagRegex.firstMatch(block)?.group(1);
      final calData = calDataRegex.firstMatch(block)?.group(1);

      if (calData != null) {
        events.add({'etag': etag, 'ical': calData.trim()});
      }
    }

    return events;
  }

  String? _extractSyncToken(String xmlResponse) {
    final tokenRegex = RegExp(
      r'<d:sync-token>(.*?)</d:sync-token>|<cs:getctag>(.*?)</cs:getctag>',
    );
    final match = tokenRegex.firstMatch(xmlResponse);
    return match?.group(1) ?? match?.group(2);
  }

  /// Parse un bloc iCalendar (VEVENT) en EventModel.
  static EventModel? parseICalEvent(
    String ical, {
    required String calendarId,
    String? etag,
    List<TagModel>? allTags,
  }) {
    try {
      String getValue(String key) {
        final regex = RegExp('$key[^:]*:(.+?)(?=\\r?\\n[A-Z])', dotAll: false);
        return regex.firstMatch(ical)?.group(1)?.trim() ?? '';
      }

      final uid = getValue('UID');
      final summary = getValue('SUMMARY');
      if (uid.isEmpty || summary.isEmpty) return null;

      final dtstart = getValue('DTSTART');
      final dtend = getValue('DTEND');
      final isAllDay =
          ical.contains('DTSTART;VALUE=DATE') && !dtstart.contains('T');

      final startDate = dtstart.isNotEmpty
          ? CalendarDateUtils.fromICalDate(dtstart)
          : DateTime.now();
      final endDate = dtend.isNotEmpty
          ? CalendarDateUtils.fromICalDate(dtend)
          : startDate.add(const Duration(hours: 1));

      final location = getValue('LOCATION');
      final description = getValue('DESCRIPTION');
      final rrule = getValue('RRULE');
      final categories = getValue('CATEGORIES');
      final priorityStr = getValue('PRIORITY');

      final categoryNames = categories.isNotEmpty
          ? categories.split(',').map((c) => c.trim()).toList()
          : <String>[];

      final matchedTags = <TagModel>[];
      final tagIds = <int>[];

      if (allTags != null) {
        for (final catName in categoryNames) {
          final tag = allTags
              .where(
                (t) =>
                    t.isCategory &&
                    (t.infomaniakMapping == catName || t.name == catName),
              )
              .firstOrNull;
          if (tag?.id != null) {
            matchedTags.add(tag!);
            tagIds.add(tag.id!);
          }
        }

        if (priorityStr.isNotEmpty) {
          final tag = allTags
              .where(
                (t) => t.isPriority && t.infomaniakMapping == priorityStr,
              )
              .firstOrNull;
          if (tag?.id != null) {
            matchedTags.add(tag!);
            tagIds.add(tag.id!);
          }
        }
      }

      EventType type = EventType.appointment;
      if (isAllDay) type = EventType.allDay;
      if (rrule.isNotEmpty) type = EventType.recurring;

      return EventModel(
        remoteId: uid,
        source: AppConstants.sourceInfomaniak,
        type: type,
        title: summary
            .replaceAll('\\,', ',')
            .replaceAll('\\;', ';')
            .replaceAll('\\n', '\n'),
        startDate: startDate,
        endDate: endDate,
        isAllDay: isAllDay,
        location: location.isNotEmpty ? location.replaceAll('\\,', ',') : null,
        description:
            description.isNotEmpty ? description.replaceAll('\\n', '\n') : null,
        rrule: rrule.isNotEmpty ? rrule : null,
        calendarId: calendarId,
        etag: etag,
        tagIds: tagIds,
        tags: matchedTags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }
}
