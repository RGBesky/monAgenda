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

  /// URL du calendrier actuellement configurée.
  String? get calendarUrl => _calendarUrl;

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

    // Pour une mise à jour, récupérer l'ETag frais du serveur
    // afin d'éviter 412 Precondition Failed
    String? freshEtag;
    if (event.etag != null) {
      try {
        final headResp = await _calDavDio.request(
          eventUrl,
          options: Options(method: 'HEAD'),
        );
        freshEtag = headResp.headers.value('ETag');
      } catch (_) {
        // Si HEAD échoue, tenter sans If-Match
      }
    }

    final response = await _calDavDio.put(
      eventUrl,
      data: icsData,
      options: Options(
        headers: {
          'Content-Type': 'text/calendar; charset=utf-8',
          if (freshEtag != null) 'If-Match': freshEtag,
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

    // Récupérer l'ETag frais pour éviter 412
    String? freshEtag;
    try {
      final headResp = await _calDavDio.request(
        eventUrl,
        options: Options(method: 'HEAD'),
      );
      freshEtag = headResp.headers.value('ETag');
    } catch (_) {}

    await _calDavDio.delete(
      eventUrl,
      options: Options(
        headers: {
          if (freshEtag != null) 'If-Match': freshEtag,
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
    // Description + métadonnées tags encodées
    final descWithTags = _encodeDescriptionWithTags(event);
    if (descWithTags.isNotEmpty) {
      sb.writeln('DESCRIPTION:${_escapeIcs(descWithTags)}');
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

  /// Encode la description + les tags dans un seul champ DESCRIPTION iCal.
  /// Format :
  ///   <description texte>
  ///   ---
  ///   #priorité:[Haute] #catégorie:[Santé,Travail] #statut:[En cours]
  static String _encodeDescriptionWithTags(EventModel event) {
    final parts = <String>[];

    // Texte de description réel
    if (event.description != null && event.description!.isNotEmpty) {
      parts.add(event.description!);
    }

    // Construire la ligne de métadonnées tags
    final tagParts = <String>[];

    final priTag = event.tags.where((t) => t.isPriority).firstOrNull;
    if (priTag != null) {
      tagParts.add('#priorité:[${priTag.name}]');
    }

    final catTags = event.tags.where((t) => t.isCategory).toList();
    if (catTags.isNotEmpty) {
      tagParts.add('#catégorie:[${catTags.map((t) => t.name).join(',')}]');
    }

    final statusTag = event.tags.where((t) => t.isStatus).firstOrNull;
    if (statusTag != null) {
      tagParts.add('#statut:[${statusTag.name}]');
    }

    if (tagParts.isNotEmpty) {
      parts.add('---');
      parts.add(tagParts.join(' '));
    }

    return parts.join('\n');
  }

  /// Décode la description iCal : extrait le texte réel et les tags encodés.
  /// Retourne (description nettoyée, liste de noms de tags trouvés par type).
  static _ParsedDescription _decodeDescriptionWithTags(String raw) {
    final unescaped = raw.replaceAll('\\n', '\n');
    final lines = unescaped.split('\n');

    // Chercher le séparateur ---
    final sepIndex = lines.lastIndexOf('---');
    if (sepIndex < 0 || sepIndex >= lines.length - 1) {
      // Pas de métadonnées
      return _ParsedDescription(
        description: unescaped.trim().isEmpty ? null : unescaped.trim(),
      );
    }

    // Texte avant le ---
    final descPart = lines.sublist(0, sepIndex).join('\n').trim();
    // Ligne(s) après le ---
    final metaLine = lines.sublist(sepIndex + 1).join(' ').trim();

    // Parser les tags : #type:[valeur]
    final tagRegex = RegExp(r'#(priorité|catégorie|statut):\[([^\]]+)\]');
    final priorityNames = <String>[];
    final categoryNames = <String>[];
    final statusNames = <String>[];

    for (final match in tagRegex.allMatches(metaLine)) {
      final type = match.group(1)!;
      final values = match.group(2)!.split(',').map((s) => s.trim()).toList();
      switch (type) {
        case 'priorité':
          priorityNames.addAll(values);
          break;
        case 'catégorie':
          categoryNames.addAll(values);
          break;
        case 'statut':
          statusNames.addAll(values);
          break;
      }
    }

    return _ParsedDescription(
      description: descPart.isEmpty ? null : descPart,
      priorityNames: priorityNames,
      categoryNames: categoryNames,
      statusNames: statusNames,
    );
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

  /// Décode les entités XML courantes.
  static String _decodeXmlEntities(String s) {
    return s
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&apos;', "'");
  }

  String _extractDisplayName(String xmlResponse) {
    final nameRegex =
        RegExp(r'<(?:d:|D:)?displayname[^>]*>(.*?)</(?:d:|D:)?displayname>');
    final match = nameRegex.firstMatch(xmlResponse);
    return match?.group(1) ?? 'Calendrier';
  }

  List<Map<String, dynamic>> _parseCalendarList(String xmlResponse) {
    final calendars = <Map<String, dynamic>>[];
    final hrefRegex = RegExp(r'<(?:d:|D:)?href[^>]*>(.*?)</(?:d:|D:)?href>');
    final nameRegex =
        RegExp(r'<(?:d:|D:)?displayname[^>]*>(.*?)</(?:d:|D:)?displayname>');

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
      r'<(?:d:|D:)?response[^>]*>(.*?)</(?:d:|D:)?response>',
      dotAll: true,
    );
    final etagRegex =
        RegExp(r'<(?:d:|D:)?getetag[^>]*>(.*?)</(?:d:|D:)?getetag>');
    final calDataRegex = RegExp(
      r'<(?:c:|cal:|C:)?calendar-data[^>]*>(.*?)</(?:c:|cal:|C:)?calendar-data>',
      dotAll: true,
    );

    for (final match in responseRegex.allMatches(xmlResponse)) {
      final block = match.group(1) ?? '';
      final rawEtag = etagRegex.firstMatch(block)?.group(1);
      final calData = calDataRegex.firstMatch(block)?.group(1);

      if (calData != null) {
        // Décoder les entités XML dans l'ETag (&quot; → ")
        final etag = rawEtag != null ? _decodeXmlEntities(rawEtag) : null;
        events.add({'etag': etag, 'ical': calData.trim()});
      }
    }

    return events;
  }

  String? _extractSyncToken(String xmlResponse) {
    final tokenRegex = RegExp(
      r'<(?:d:|D:)?sync-token[^>]*>(.*?)</(?:d:|D:)?sync-token>|<(?:cs:|CS:)?getctag[^>]*>(.*?)</(?:cs:|CS:)?getctag>',
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
      // Extraire uniquement le bloc VEVENT pour éviter de capturer
      // les propriétés du VTIMEZONE (ex: DTSTART du bloc STANDARD)
      final veventMatch = RegExp(
        r'BEGIN:VEVENT(.*?)END:VEVENT',
        dotAll: true,
      ).firstMatch(ical);
      final veventBlock = veventMatch?.group(1) ?? ical;

      // Dé-folder les lignes iCal (RFC 5545 §3.1 : continuation = CRLF + espace/tab)
      final unfolded = veventBlock
          .replaceAll('\r\n ', '')
          .replaceAll('\r\n\t', '')
          .replaceAll('\n ', '')
          .replaceAll('\n\t', '');

      String getValue(String key) {
        // Cherche "$key" suivi de params optionnels puis ":" et capture la valeur
        // jusqu'à la fin de la ligne (ou fin du texte)
        final regex = RegExp(
          '^$key[^:\\r\\n]*:(.+)\$',
          multiLine: true,
        );
        return regex.firstMatch(unfolded)?.group(1)?.trim() ?? '';
      }

      final uid = getValue('UID');
      final summary = getValue('SUMMARY');
      if (uid.isEmpty || summary.isEmpty) return null;

      final dtstart = getValue('DTSTART');
      final dtend = getValue('DTEND');
      // Détection all-day : VALUE=DATE explicite OU valeur sans heure (8 chiffres)
      final isAllDay = ical.contains('DTSTART;VALUE=DATE') ||
          (dtstart.isNotEmpty && !dtstart.contains('T'));

      final startDate = dtstart.isNotEmpty
          ? CalendarDateUtils.fromICalDate(dtstart)
          : DateTime.now();
      final endDate = dtend.isNotEmpty
          ? CalendarDateUtils.fromICalDate(dtend)
          : startDate.add(const Duration(hours: 1));

      final location = getValue('LOCATION');
      final rawDescription = getValue('DESCRIPTION');
      final rrule = getValue('RRULE');
      final categories = getValue('CATEGORIES');
      final priorityStr = getValue('PRIORITY');

      // Décoder description + tags encodés dans DESCRIPTION
      final parsed = _decodeDescriptionWithTags(rawDescription);
      final description = parsed.description ?? '';

      // Catégories depuis CATEGORIES iCal standard
      final categoryNames = categories.isNotEmpty
          ? categories.split(',').map((c) => c.trim()).toList()
          : <String>[];
      // Ajouter les catégories encodées dans DESCRIPTION (sans doublons)
      for (final cn in parsed.categoryNames) {
        if (!categoryNames.contains(cn)) categoryNames.add(cn);
      }

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

        // Priorité depuis PRIORITY iCal standard
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
        // Priorité depuis DESCRIPTION encodée (fallback)
        if (!matchedTags.any((t) => t.isPriority)) {
          for (final pn in parsed.priorityNames) {
            final tag = allTags
                .where((t) =>
                    t.isPriority &&
                    t.name.toLowerCase() == pn.toLowerCase())
                .firstOrNull;
            if (tag?.id != null) {
              matchedTags.add(tag!);
              tagIds.add(tag.id!);
              break;
            }
          }
        }

        // Statut depuis DESCRIPTION encodée
        for (final sn in parsed.statusNames) {
          final tag = allTags
              .where((t) =>
                  t.isStatus &&
                  t.name.toLowerCase() == sn.toLowerCase())
              .firstOrNull;
          if (tag?.id != null) {
            matchedTags.add(tag!);
            tagIds.add(tag.id!);
            break;
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
            description.isNotEmpty ? description : null,
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

/// Résultat du décodage de la description iCal avec métadonnées tags.
class _ParsedDescription {
  final String? description;
  final List<String> priorityNames;
  final List<String> categoryNames;
  final List<String> statusNames;

  const _ParsedDescription({
    this.description,
    this.priorityNames = const [],
    this.categoryNames = const [],
    this.statusNames = const [],
  });
}
