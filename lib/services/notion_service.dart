import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../core/models/event_model.dart';
import '../core/models/notion_database_model.dart';
import '../core/models/tag_model.dart';

/// Service d'intégration Notion.
/// Authentification via API Key (Integration Token).
class NotionService {
  final Dio _dio;
  String? _apiKey;

  NotionService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConstants.notionApiBase,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Notion-Version': AppConstants.notionApiVersion,
          },
        ));

  void setCredentials({required String apiKey}) {
    _apiKey = apiKey;
    _dio.options.headers['Authorization'] = 'Bearer $apiKey';
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Valide la clé API en récupérant le profil utilisateur.
  Future<Map<String, dynamic>> validateApiKey() async {
    final response = await _dio.get('/users/me');
    return response.data as Map<String, dynamic>;
  }

  /// Recherche les bases de données accessibles.
  Future<List<Map<String, dynamic>>> searchDatabases() async {
    final response = await _dio.post('/search', data: {
      'filter': {'value': 'database', 'property': 'object'},
      'sort': {
        'direction': 'descending',
        'timestamp': 'last_edited_time',
      },
    });

    final results = (response.data['results'] as List).cast<Map<String, dynamic>>();
    return results.map((db) => {
      'id': db['id'] as String,
      'name': _extractTitle(db),
      'properties': db['properties'] as Map<String, dynamic>,
    }).toList();
  }

  /// Récupère les propriétés d'une base de données.
  Future<Map<String, dynamic>> getDatabaseSchema(String databaseId) async {
    final response = await _dio.get('/databases/$databaseId');
    return response.data as Map<String, dynamic>;
  }

  /// Requête une base de données pour obtenir les pages (événements).
  Future<List<Map<String, dynamic>>> queryDatabase({
    required String databaseId,
    DateTime? startDate,
    DateTime? endDate,
    String? cursor,
  }) async {
    final body = <String, dynamic>{
      'page_size': 100,
      if (cursor != null) 'start_cursor': cursor,
    };

    // Filtre sur les dates si spécifiées
    if (startDate != null || endDate != null) {
      final dateFilter = <Map<String, dynamic>>[];
      if (startDate != null) {
        dateFilter.add({
          'property': 'Date',
          'date': {'on_or_after': startDate.toIso8601String()},
        });
      }
      if (endDate != null) {
        dateFilter.add({
          'property': 'Date',
          'date': {'on_or_before': endDate.toIso8601String()},
        });
      }
      if (dateFilter.length == 1) {
        body['filter'] = dateFilter.first;
      } else if (dateFilter.length > 1) {
        body['filter'] = {'and': dateFilter};
      }
    }

    final response = await _dio.post(
      '/databases/$databaseId/query',
      data: body,
    );

    final data = response.data as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();

    // Pagination
    if (data['has_more'] == true && data['next_cursor'] != null) {
      final more = await queryDatabase(
        databaseId: databaseId,
        startDate: startDate,
        endDate: endDate,
        cursor: data['next_cursor'] as String,
      );
      return [...results, ...more];
    }

    return results;
  }

  /// Crée une page (tâche/projet) dans Notion.
  Future<Map<String, dynamic>> createPage({
    required NotionDatabaseModel dbModel,
    required EventModel event,
    required List<TagModel> allTags,
  }) async {
    final properties = _buildProperties(dbModel, event, allTags);
    final response = await _dio.post('/pages', data: {
      'parent': {'database_id': dbModel.notionId},
      'properties': properties,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Met à jour une page Notion existante.
  Future<Map<String, dynamic>> updatePage({
    required String pageId,
    required NotionDatabaseModel dbModel,
    required EventModel event,
    required List<TagModel> allTags,
  }) async {
    final properties = _buildProperties(dbModel, event, allTags);
    final response = await _dio.patch('/pages/$pageId', data: {
      'properties': properties,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Archive (supprime) une page Notion.
  Future<void> archivePage(String pageId) async {
    await _dio.patch('/pages/$pageId', data: {'archived': true});
  }

  /// Convertit une page Notion en EventModel.
  EventModel? pageToEvent({
    required Map<String, dynamic> page,
    required NotionDatabaseModel dbModel,
    required List<TagModel> allTags,
  }) {
    try {
      final props = page['properties'] as Map<String, dynamic>;
      final id = page['id'] as String;
      final lastEditedTime = page['last_edited_time'] as String?;

      // Titre
      final titleProp = props[dbModel.titleProperty];
      final title = _extractRichText(titleProp);
      if (title.isEmpty) return null;

      // Dates
      final dateProp = dbModel.startDateProperty != null
          ? props[dbModel.startDateProperty]
          : null;
      DateTime? startDate;
      DateTime? endDate;
      bool isAllDay = false;

      if (dateProp != null && dateProp['date'] != null) {
        final dateObj = dateProp['date'] as Map<String, dynamic>;
        final startStr = dateObj['start'] as String?;
        final endStr = dateObj['end'] as String?;

        if (startStr != null) {
          startDate = DateTime.parse(startStr);
          isAllDay = !startStr.contains('T');
        }
        if (endStr != null) {
          endDate = DateTime.parse(endStr);
        } else if (startDate != null) {
          endDate = isAllDay
              ? startDate
              : startDate.add(const Duration(hours: 1));
        }
      }

      if (startDate == null) return null;

      // Catégories
      final categoryNames = <String>[];
      final tagIdsList = <int>[];
      final matchedTags = <TagModel>[];

      if (dbModel.categoryProperty != null) {
        final catProp = props[dbModel.categoryProperty];
        if (catProp != null) {
          final options = catProp['multi_select'] as List? ?? [];
          for (final opt in options) {
            final name = (opt as Map<String, dynamic>)['name'] as String?;
            if (name != null) {
              categoryNames.add(name);
              final tag = allTags.firstWhereOrNull(
                (t) => t.isCategory && t.name == name,
              );
              if (tag?.id != null) {
                tagIdsList.add(tag!.id!);
                matchedTags.add(tag);
              }
            }
          }
        }
      }

      // Priorité
      if (dbModel.priorityProperty != null) {
        final priProp = props[dbModel.priorityProperty];
        if (priProp != null) {
          final selected = priProp['select'] as Map<String, dynamic>?;
          if (selected != null) {
            final name = selected['name'] as String?;
            if (name != null) {
              final tag = allTags.firstWhereOrNull(
                (t) => t.isPriority && t.name == name,
              );
              if (tag?.id != null) {
                tagIdsList.add(tag!.id!);
                matchedTags.add(tag);
              }
            }
          }
        }
      }

      // Description
      String? description;
      if (dbModel.descriptionProperty != null) {
        final descProp = props[dbModel.descriptionProperty];
        description = _extractRichText(descProp);
        if (description.isEmpty) description = null;
      }

      // Type : multi-day si durée > 1 jour
      final type = (endDate != null &&
              endDate.difference(startDate).inDays > 0 &&
              !isAllDay)
          ? EventType.multiDay
          : EventType.task;

      return EventModel(
        remoteId: id,
        source: AppConstants.sourceNotion,
        type: type,
        title: title,
        startDate: startDate,
        endDate: endDate ?? startDate.add(const Duration(hours: 1)),
        isAllDay: isAllDay,
        description: description,
        tagIds: tagIdsList,
        tags: matchedTags,
        notionPageId: id,
        createdAt: page['created_time'] != null
            ? DateTime.parse(page['created_time'] as String)
            : DateTime.now(),
        updatedAt: lastEditedTime != null
            ? DateTime.parse(lastEditedTime)
            : DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> _buildProperties(
    NotionDatabaseModel dbModel,
    EventModel event,
    List<TagModel> allTags,
  ) {
    final properties = <String, dynamic>{};

    // Titre
    properties[dbModel.titleProperty] = {
      'title': [
        {
          'type': 'text',
          'text': {'content': event.title},
        },
      ],
    };

    // Dates
    if (dbModel.startDateProperty != null) {
      final dateValue = <String, dynamic>{
        'start': event.isAllDay
            ? event.startDate.toIso8601String().split('T').first
            : event.startDate.toIso8601String(),
      };

      if (event.endDate.day != event.startDate.day ||
          event.endDate.hour != event.startDate.hour) {
        dateValue['end'] = event.isAllDay
            ? event.endDate.toIso8601String().split('T').first
            : event.endDate.toIso8601String();
      }

      properties[dbModel.startDateProperty!] = {'date': dateValue};
    }

    // Catégories
    if (dbModel.categoryProperty != null) {
      final categories = event.tags
          .where((t) => t.isCategory)
          .map((t) => {'name': t.name})
          .toList();
      properties[dbModel.categoryProperty!] = {'multi_select': categories};
    }

    // Priorité
    if (dbModel.priorityProperty != null) {
      final priority = event.tags.where((t) => t.isPriority).firstOrNull;
      if (priority != null) {
        properties[dbModel.priorityProperty!] = {
          'select': {'name': priority.name},
        };
      }
    }

    // Description
    if (dbModel.descriptionProperty != null && event.description != null) {
      properties[dbModel.descriptionProperty!] = {
        'rich_text': [
          {
            'type': 'text',
            'text': {'content': event.description!},
          },
        ],
      };
    }

    return properties;
  }

  String _extractTitle(Map<String, dynamic> db) {
    final title = db['title'] as List?;
    if (title == null || title.isEmpty) return 'Sans titre';
    return (title.first as Map)['plain_text'] as String? ?? 'Sans titre';
  }

  String _extractRichText(dynamic prop) {
    if (prop == null) return '';
    final list = (prop['rich_text'] ?? prop['title']) as List?;
    if (list == null || list.isEmpty) return '';
    return list
        .map((item) => (item as Map)['plain_text'] as String? ?? '')
        .join();
  }
}

extension _ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
