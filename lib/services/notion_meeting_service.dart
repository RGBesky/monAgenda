import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../core/models/event_model.dart';
import 'logger_service.dart';
import 'notion_service.dart';

/// Service de création / ouverture de comptes-rendus de réunion dans Notion.
/// Desktop uniquement.
class NotionMeetingService {
  final NotionService _notion;
  final String _meetingDatabaseId;

  NotionMeetingService({
    required NotionService notion,
    required String meetingDatabaseId,
  })  : _notion = notion,
        _meetingDatabaseId = meetingDatabaseId;

  /// Crée ou retrouve la note de réunion liée à l'événement.
  /// Retourne l'URL de la page Notion.
  Future<String> createOrOpen(EventModel event) async {
    // 1. Chercher une page existante avec le même titre dans la DB Meeting
    final existing = await _findExistingPage(event.title);
    if (existing != null) {
      AppLogger.instance.info(
        'MeetingNote',
        'Page existante trouvée : ${existing['id']}',
      );
      return _pageUrl(existing['id'] as String);
    }

    // 2. Créer une nouvelle page
    final pageId = await _createPage(event);
    AppLogger.instance.info(
      'MeetingNote',
      'Page créée : $pageId pour "${event.title}"',
    );
    return _pageUrl(pageId);
  }

  /// Recherche une page existante dans la DB "Notes de réunion" par titre.
  Future<Map<String, dynamic>?> _findExistingPage(String title) async {
    try {
      final results = await _notion.queryDatabaseRaw(
        databaseId: _meetingDatabaseId,
        filter: {
          'property': 'Name',
          'title': {'equals': title},
        },
      );
      if (results.isNotEmpty) return results.first;
    } catch (e) {
      AppLogger.instance.warning(
        'MeetingNote',
        'Recherche page échouée : $e',
      );
    }
    return null;
  }

  /// Crée une page dans la DB "Notes de Réunion".
  Future<String> _createPage(EventModel event) async {
    final body = <String, dynamic>{
      'parent': {'database_id': _meetingDatabaseId},
      'properties': {
        'Name': {
          'title': [
            {
              'text': {'content': event.title},
            },
          ],
        },
        'Date': {
          'date': {
            'start': event.startDate.toUtc().toIso8601String(),
            if (event.endDate != event.startDate)
              'end': event.endDate.toUtc().toIso8601String(),
          },
        },
      },
      'children': [
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [
              {
                'text': {'content': 'Compte-rendu'},
              },
            ],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [
              {
                'text': {
                  'content':
                      'Événement : ${event.title}\n'
                      'Date : ${event.startDate.toIso8601String()}\n'
                      '${event.location != null ? "Lieu : ${event.location}\n" : ""}'
                      '${event.participants.isNotEmpty ? "Participants : ${event.participants.map((p) => p.name ?? p.email).join(", ")}\n" : ""}',
                },
              },
            ],
          },
        },
        {
          'object': 'block',
          'type': 'divider',
          'divider': <String, dynamic>{},
        },
        {
          'object': 'block',
          'type': 'heading_3',
          'heading_3': {
            'rich_text': [
              {
                'text': {'content': 'Notes'},
              },
            ],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': <Map<String, dynamic>>[],
          },
        },
      ],
    };

    final pageId = await _notion.createPageRaw(body);
    return pageId;
  }

  String _pageUrl(String pageId) {
    // Notion page URL format — ids sans tirets
    final cleanId = pageId.replaceAll('-', '');
    return 'https://www.notion.so/$cleanId';
  }
}

// ─── Riverpod ────────────────────────────────────────────────

/// Provider du service Meeting Note.
/// Null si Notion non configuré ou DB Meeting non définie.
final notionMeetingServiceProvider = Provider<NotionMeetingService?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null ||
      !settings.isNotionConfigured ||
      settings.notionMeetingDatabaseId == null ||
      settings.notionMeetingDatabaseId!.isEmpty) {
    return null;
  }
  return NotionMeetingService(
    notion: ref.watch(notionServiceProvider),
    meetingDatabaseId: settings.notionMeetingDatabaseId!,
  );
});
