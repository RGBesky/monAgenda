import 'package:dio/dio.dart';
import 'package:collection/collection.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_colors.dart';
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

    final results =
        (response.data['results'] as List).cast<Map<String, dynamic>>();
    return results.map((db) {
      return {
        'id': db['id'] as String,
        'database_id': db['id'] as String,
        'name': _extractTitle(db),
        'properties': db['properties'] as Map<String, dynamic>,
      };
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
    String? dateProperty,
    DateTime? startDate,
    DateTime? endDate,
    String? cursor,
  }) async {
    final body = <String, dynamic>{
      'page_size': 100,
      if (cursor != null) 'start_cursor': cursor,
    };

    // Filtre sur les dates si une propriété date est spécifiée
    if (dateProperty != null && dateProperty.isNotEmpty) {
      if (startDate != null || endDate != null) {
        final dateFilter = <Map<String, dynamic>>[];
        if (startDate != null) {
          dateFilter.add({
            'property': dateProperty,
            'date': {'on_or_after': startDate.toIso8601String()},
          });
        }
        if (endDate != null) {
          dateFilter.add({
            'property': dateProperty,
            'date': {'on_or_before': endDate.toIso8601String()},
          });
        }
        if (dateFilter.length == 1) {
          body['filter'] = dateFilter.first;
        } else if (dateFilter.length > 1) {
          body['filter'] = {'and': dateFilter};
        }
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
        dateProperty: dateProperty,
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
    Map<String, dynamic>? schema,
  }) async {
    final properties =
        _buildProperties(dbModel, event, allTags, schema: schema);
    final response = await _dio.post('/pages', data: {
      'parent': {'database_id': dbModel.effectiveSourceId},
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
    Map<String, dynamic>? schema,
  }) async {
    final properties =
        _buildProperties(dbModel, event, allTags, schema: schema);
    final response = await _dio.patch('/pages/$pageId', data: {
      'properties': properties,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Archive (supprime) une page Notion.
  Future<void> archivePage(String pageId) async {
    await _dio.patch('/pages/$pageId', data: {'archived': true});
  }

  /// Extrait les options de catégorie depuis le schéma d'une BDD Notion.
  /// Retourne les TagModels pour les options qui n'existent pas encore localement.
  List<TagModel> extractMissingCategoryTags({
    required Map<String, dynamic> schema,
    required NotionDatabaseModel dbModel,
    required List<TagModel> allTags,
  }) {
    final missingTags = <TagModel>[];
    final propName = dbModel.categoryProperty;
    if (propName == null) return missingTags;

    final props = schema['properties'] as Map<String, dynamic>? ?? {};
    final prop = props[propName] as Map<String, dynamic>?;
    if (prop == null) return missingTags;

    final type = prop['type'] as String?;
    List<Map<String, dynamic>> options = [];

    if (type == 'multi_select') {
      final ms = prop['multi_select'] as Map<String, dynamic>?;
      options = (ms?['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } else if (type == 'select') {
      final sel = prop['select'] as Map<String, dynamic>?;
      options = (sel?['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } else if (type == 'status') {
      final st = prop['status'] as Map<String, dynamic>?;
      final groups =
          (st?['groups'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final g in groups) {
        final groupOptions = (g['option_ids'] as List?)?.cast<String>() ?? [];
        // Status options are flat in the 'options' list
        final statusOptions =
            (st?['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final so in statusOptions) {
          if (!options.any((o) => o['id'] == so['id'])) {
            options.add(so);
          }
        }
        if (groupOptions.isNotEmpty) break; // just to trigger reading options
      }
      // Fallback: read options directly
      if (options.isEmpty) {
        options = (st?['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      }
    }

    final existingCount = allTags.where((t) => t.isCategory).length;

    for (int i = 0; i < options.length; i++) {
      final name = options[i]['name'] as String?;
      final color = options[i]['color'] as String? ?? 'default';
      if (name == null || name.isEmpty) continue;

      final exists = allTags.any((t) => t.isCategory && t.name == name);
      if (!exists) {
        missingTags.add(TagModel(
          type: AppConstants.tagTypeCategory,
          name: name,
          colorHex: AppColors.toHex(AppColors.fromNotionColor(color)),
          notionMapping: name,
          sortOrder: existingCount + i,
        ));
      }
    }

    return missingTags;
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
      DateTime? startDate;
      DateTime? endDate;
      bool isAllDay = false;

      // Chercher la propriété date configurée, ou auto-détecter
      Map<String, dynamic>? dateProp;
      if (dbModel.startDateProperty != null) {
        dateProp = props[dbModel.startDateProperty] as Map<String, dynamic>?;
      }
      // Fallback : chercher la première propriété de type 'date'
      if (dateProp == null || dateProp['date'] == null) {
        for (final entry in props.entries) {
          final val = entry.value;
          if (val is Map<String, dynamic> &&
              val['type'] == 'date' &&
              val['date'] != null) {
            dateProp = val;
            break;
          }
        }
      }

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
          endDate =
              isAllDay ? startDate : startDate.add(const Duration(hours: 1));
        }
      }

      if (startDate == null) return null;

      // Catégories — support multi_select ET select
      final categoryNames = <String>[];
      final tagIdsList = <int>[];
      final matchedTags = <TagModel>[];

      if (dbModel.categoryProperty != null) {
        final catProp = props[dbModel.categoryProperty];
        if (catProp != null) {
          final catType = catProp['type'] as String?;
          List<Map<String, dynamic>> catOptions = [];

          if (catType == 'multi_select') {
            catOptions = ((catProp['multi_select'] as List?) ?? [])
                .cast<Map<String, dynamic>>();
          } else if (catType == 'select') {
            final selected = catProp['select'] as Map<String, dynamic>?;
            if (selected != null) catOptions = [selected];
          } else if (catType == 'status') {
            final statusObj = catProp['status'] as Map<String, dynamic>?;
            if (statusObj != null) catOptions = [statusObj];
          }

          for (final opt in catOptions) {
            final name = opt['name'] as String?;
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

      // Description — enrichie avec Où / Pourquoi / Quoi
      final descParts = <String>[];

      // 1. Texte principal (Comment ?)
      if (dbModel.descriptionProperty != null) {
        final descProp = props[dbModel.descriptionProperty];
        final mainDesc = _extractRichText(descProp);
        if (mainDesc.isNotEmpty) {
          descParts.add(mainDesc);
        }
      }

      // 2. Où ?
      if (dbModel.locationProperty != null) {
        final locProp = props[dbModel.locationProperty];
        final locText = _extractRichText(locProp);
        if (locText.isNotEmpty) {
          descParts.add('📍 Où : $locText');
        }
      }

      // 3. Pourquoi ?
      if (dbModel.objectiveProperty != null) {
        final objProp = props[dbModel.objectiveProperty];
        final objText = _extractRichText(objProp);
        if (objText.isNotEmpty) {
          descParts.add('🎯 Pourquoi : $objText');
        }
      }

      // 4. Quoi ?
      if (dbModel.materialProperty != null) {
        final matProp = props[dbModel.materialProperty];
        final matText = _extractRichText(matProp);
        if (matText.isNotEmpty) {
          descParts.add('🧰 Quoi : $matText');
        }
      }

      // 5. État d'avancement
      String? statusValue;
      if (dbModel.statusProperty != null) {
        final statusProp = props[dbModel.statusProperty];
        if (statusProp != null) {
          // Notion status peut être 'status', 'select' ou 'rich_text'
          final statusObj = statusProp['status'] as Map<String, dynamic>?;
          final selectObj = statusProp['select'] as Map<String, dynamic>?;
          if (statusObj != null) {
            statusValue = statusObj['name'] as String?;
          } else if (selectObj != null) {
            statusValue = selectObj['name'] as String?;
          } else {
            final rt = _extractRichText(statusProp);
            if (rt.isNotEmpty) statusValue = rt;
          }
          if (statusValue != null && statusValue.isNotEmpty) {
            descParts.add('📊 État : $statusValue');
          }
        }
      }

      final description = descParts.isNotEmpty ? descParts.join('\n\n') : null;

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
        status: statusValue,
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
    List<TagModel> allTags, {
    Map<String, dynamic>? schema,
  }) {
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

    // Catégories — détecter le type depuis le schéma (select / multi_select / status)
    if (dbModel.categoryProperty != null) {
      final categories = event.tags.where((t) => t.isCategory).toList();

      // Déterminer le type réel de la propriété depuis le schéma
      String catType = 'multi_select'; // fallback
      if (schema != null) {
        final schemaProps = schema['properties'] as Map<String, dynamic>? ?? {};
        final catProp =
            schemaProps[dbModel.categoryProperty] as Map<String, dynamic>?;
        if (catProp != null) {
          catType = catProp['type'] as String? ?? 'multi_select';
        }
      }

      if (catType == 'select') {
        // select : une seule catégorie
        final first = categories.firstOrNull;
        if (first != null) {
          properties[dbModel.categoryProperty!] = {
            'select': {'name': first.name},
          };
        }
      } else if (catType == 'status') {
        final first = categories.firstOrNull;
        if (first != null) {
          properties[dbModel.categoryProperty!] = {
            'status': {'name': first.name},
          };
        }
      } else {
        // multi_select (défaut)
        properties[dbModel.categoryProperty!] = {
          'multi_select': categories.map((t) => {'name': t.name}).toList(),
        };
      }
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

    // Description — on écrit uniquement le texte principal (sans les sections enrichies)
    if (dbModel.descriptionProperty != null && event.description != null) {
      // Extraire le texte avant les sections emoji ajoutées
      final cleanDesc = _extractMainDescription(event.description!);
      if (cleanDesc.isNotEmpty) {
        properties[dbModel.descriptionProperty!] = {
          'rich_text': [
            {
              'type': 'text',
              'text': {'content': cleanDesc},
            },
          ],
        };
      }
    }

    // Où ? — écrire dans la propriété Notion dédiée si elle existe
    if (dbModel.locationProperty != null && event.location != null) {
      properties[dbModel.locationProperty!] = {
        'rich_text': [
          {
            'type': 'text',
            'text': {'content': event.location!},
          },
        ],
      };
    }

    // État d'avancement
    if (dbModel.statusProperty != null && event.status != null) {
      properties[dbModel.statusProperty!] = {
        'status': {'name': event.status!},
      };
    }

    return properties;
  }

  /// Extrait le texte principal de la description, avant les sections enrichies (📍/🎯/🧰/📊).
  String _extractMainDescription(String description) {
    final lines = description.split('\n');
    final buffer = StringBuffer();
    for (final line in lines) {
      if (line.startsWith('📍') ||
          line.startsWith('🎯') ||
          line.startsWith('🧰') ||
          line.startsWith('📊')) {
        break;
      }
      buffer.writeln(line);
    }
    return buffer.toString().trim();
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
