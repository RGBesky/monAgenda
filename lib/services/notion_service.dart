import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:collection/collection.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_colors.dart';
import '../core/models/event_model.dart';
import '../core/models/notion_database_model.dart';
import '../core/models/tag_model.dart';
import '../core/security/cert_pins.dart';
import 'logger_service.dart';

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
        )) {
    // V3 : Certificate pinning pour Notion API
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        if (host.contains('notion.so') || host.contains('notion.com')) {
          final sha256 = crypto.sha256.convert(cert.der).toString();
          if (!kNotionCertPins.contains(sha256)) {
            AppLogger.instance.error(
              'CertPin',
              'Certificate pinning FAIL on $host : $sha256',
            );
          }
        }
        return false;
      };
      return client;
    };
  }

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

  /// Requête brute sur une base de données avec filtre arbitraire.
  /// Retourne les résultats (pages) comme List<Map>.
  Future<List<Map<String, dynamic>>> queryDatabaseRaw({
    required String databaseId,
    Map<String, dynamic>? filter,
  }) async {
    final body = <String, dynamic>{};
    if (filter != null) body['filter'] = filter;
    final response = await _dio.post(
      '/databases/$databaseId/query',
      data: body,
    );
    return (response.data['results'] as List).cast<Map<String, dynamic>>();
  }

  /// Crée une page avec un body brut (properties + children).
  /// Retourne l'ID de la page créée.
  Future<String> createPageRaw(Map<String, dynamic> body) async {
    final response = await _dio.post('/pages', data: body);
    return response.data['id'] as String;
  }

  /// Met à jour la date d'une page Notion (propriété "Date").
  Future<void> updatePageDate(String pageId, DateTime date) async {
    await _dio.patch('/pages/$pageId', data: {
      'properties': {
        'Date': {
          'date': {'start': date.toUtc().toIso8601String()},
        },
      },
    });
  }

  /// Extrait les options de catégorie, priorité et statut depuis le schéma
  /// d'une BDD Notion.
  /// Retourne les TagModels pour les options qui n'existent pas encore localement.
  List<TagModel> extractMissingCategoryTags({
    required Map<String, dynamic> schema,
    required NotionDatabaseModel dbModel,
    required List<TagModel> allTags,
  }) {
    final missingTags = <TagModel>[];
    final props = schema['properties'] as Map<String, dynamic>? ?? {};

    // ── Helper : extraire les options d'une propriété Notion ──
    List<Map<String, dynamic>> extractOptions(String? propName) {
      if (propName == null) return [];
      final prop = props[propName] as Map<String, dynamic>?;
      if (prop == null) return [];
      final type = prop['type'] as String?;
      List<Map<String, dynamic>> options = [];

      if (type == 'multi_select') {
        final ms = prop['multi_select'] as Map<String, dynamic>?;
        options = (ms?['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      } else if (type == 'select') {
        final sel = prop['select'] as Map<String, dynamic>?;
        options =
            (sel?['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      } else if (type == 'status') {
        final st = prop['status'] as Map<String, dynamic>?;
        options = (st?['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      }
      return options;
    }

    // ── Helper : ajouter les tags manquants pour un type donné ──
    void addMissing(String? propName, String tagType) {
      final options = extractOptions(propName);
      final existingCount = allTags.where((t) => t.type == tagType).length;

      for (int i = 0; i < options.length; i++) {
        final name = options[i]['name'] as String?;
        final color = options[i]['color'] as String? ?? 'default';
        if (name == null || name.isEmpty) continue;

        final exists = allTags.any((t) => t.type == tagType && t.name == name);
        // Vérifier aussi dans missingTags déjà ajoutés
        final alreadyAdded =
            missingTags.any((t) => t.type == tagType && t.name == name);
        if (!exists && !alreadyAdded) {
          missingTags.add(TagModel(
            type: tagType,
            name: name,
            colorHex: AppColors.toHex(AppColors.fromNotionColor(color)),
            notionMapping: name,
            sortOrder: existingCount + i,
          ));
        }
      }
    }

    // ── Créer les tags manquants pour chaque mapping ──
    // Éviter de traiter la même propriété Notion sous plusieurs types
    final processedProps = <String>{};

    if (dbModel.categoryProperty != null) {
      processedProps.add(dbModel.categoryProperty!);
      addMissing(dbModel.categoryProperty, AppConstants.tagTypeCategory);
    }
    if (dbModel.priorityProperty != null &&
        !processedProps.contains(dbModel.priorityProperty)) {
      processedProps.add(dbModel.priorityProperty!);
      addMissing(dbModel.priorityProperty, AppConstants.tagTypePriority);
    }
    if (dbModel.statusProperty != null &&
        !processedProps.contains(dbModel.statusProperty)) {
      addMissing(dbModel.statusProperty, AppConstants.tagTypeStatus);
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
          startDate = DateTime.parse(startStr).toLocal();
          isAllDay = !startStr.contains('T');
        }
        if (endStr != null) {
          endDate = DateTime.parse(endStr).toLocal();
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

      // Priorité — support select, multi_select, status
      // Skip si même propriété que catégorie (évite les doublons)
      if (dbModel.priorityProperty != null &&
          dbModel.priorityProperty != dbModel.categoryProperty) {
        final priProp = props[dbModel.priorityProperty];
        if (priProp != null) {
          final priType = priProp['type'] as String?;
          List<Map<String, dynamic>> priOptions = [];

          if (priType == 'select') {
            final sel = priProp['select'] as Map<String, dynamic>?;
            if (sel != null) priOptions = [sel];
          } else if (priType == 'multi_select') {
            priOptions = ((priProp['multi_select'] as List?) ?? [])
                .cast<Map<String, dynamic>>();
          } else if (priType == 'status') {
            final st = priProp['status'] as Map<String, dynamic>?;
            if (st != null) priOptions = [st];
          }

          for (final opt in priOptions) {
            final name = opt['name'] as String?;
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

      // Description — enrichie avec Markdown + toutes les propriétés non-mappées
      final descParts = <String>[];

      // Propriétés déjà consommées par un mapping dédié (titre, date, catégorie, etc.)
      final mappedProps = <String?>{
        dbModel.titleProperty,
        dbModel.startDateProperty,
        dbModel.endDateProperty,
        dbModel.categoryProperty,
        dbModel.priorityProperty,
        dbModel.statusProperty,
        ...dbModel.descriptionProperties,
        dbModel.locationProperty,
        dbModel.objectiveProperty,
        dbModel.materialProperty,
        dbModel.participantsProperty,
      };

      // 1. Texte principal — concaténation de toutes les propriétés description mappées
      for (final descPropName in dbModel.descriptionProperties) {
        final descProp = props[descPropName];
        if (descProp == null) continue;
        // Essayer d'abord le rich_text/markdown, sinon la valeur générique
        final mainDesc = _extractRichTextAsMarkdown(descProp);
        if (mainDesc.isNotEmpty) {
          descParts.add(mainDesc);
        } else {
          final fallback =
              _extractPropertyValue(descProp as Map<String, dynamic>);
          if (fallback.isNotEmpty) {
            descParts.add(fallback);
          }
        }
      }

      // 2. Où ?
      if (dbModel.locationProperty != null) {
        final locProp = props[dbModel.locationProperty];
        final locText = _extractRichTextAsMarkdown(locProp);
        if (locText.isNotEmpty) {
          descParts.add('📍 Où : $locText');
        }
      }

      // 3. Pourquoi ?
      if (dbModel.objectiveProperty != null) {
        final objProp = props[dbModel.objectiveProperty];
        final objText = _extractRichTextAsMarkdown(objProp);
        if (objText.isNotEmpty) {
          descParts.add('🎯 Pourquoi : $objText');
        }
      }

      // 4. Quoi ?
      if (dbModel.materialProperty != null) {
        final matProp = props[dbModel.materialProperty];
        final matText = _extractRichTextAsMarkdown(matProp);
        if (matText.isNotEmpty) {
          descParts.add('🧰 Quoi : $matText');
        }
      }

      // 5. Auto-inclusion de TOUTES les propriétés non-mappées
      //    (comme dans Make/Integromat : toutes les données sont accessibles)
      for (final entry in props.entries) {
        if (mappedProps.contains(entry.key)) continue;
        final val = entry.value;
        if (val is! Map<String, dynamic>) continue;
        final propType = val['type'] as String?;
        // Inclure tous les types exploitables (texte, choix, nombre, formule…)
        const includedTypes = {
          'rich_text',
          'url',
          'email',
          'phone_number',
          'number',
          'checkbox',
          'formula',
          'rollup',
          'select',
          'multi_select',
          'status',
          'date',
          'people',
          'files',
        };
        if (propType == null || !includedTypes.contains(propType)) continue;
        final value = _extractPropertyValue(val);
        if (value.isEmpty) continue;
        descParts.add('📎 ${entry.key} : $value');
      }

      // 5. État d'avancement — mapper vers un tag de statut
      // Skip si même propriété que catégorie ou priorité
      String? statusValue;
      if (dbModel.statusProperty != null &&
          dbModel.statusProperty != dbModel.categoryProperty &&
          dbModel.statusProperty != dbModel.priorityProperty) {
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
        }
      }

      // Mapper le statut Notion vers un tag de statut local
      if (statusValue != null && statusValue.isNotEmpty) {
        final statusTags =
            allTags.where((t) => t.type == AppConstants.tagTypeStatus).toList();
        final matchedStatus = statusTags
            .where((t) => t.name.toLowerCase() == statusValue!.toLowerCase())
            .firstOrNull;
        if (matchedStatus != null && matchedStatus.id != null) {
          if (!matchedTags.any((t) => t.id == matchedStatus.id)) {
            matchedTags.add(matchedStatus);
            tagIdsList.add(matchedStatus.id!);
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
        calendarId: dbModel.effectiveSourceId,
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

    // Description — on écrit uniquement dans la première propriété description mappée
    if (dbModel.descriptionProperties.isNotEmpty && event.description != null) {
      // Extraire le texte avant les sections emoji ajoutées
      final cleanDesc = _extractMainDescription(event.description!);
      if (cleanDesc.isNotEmpty) {
        properties[dbModel.descriptionProperties.first] = {
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

    // État d'avancement — pousser depuis statusTag si disponible
    if (dbModel.statusProperty != null) {
      final stTag = event.statusTag;
      final stName = stTag?.name ?? event.status;
      if (stName != null) {
        properties[dbModel.statusProperty!] = {
          'status': {'name': stName},
        };
      }
    }

    return properties;
  }

  /// Extrait le texte principal de la description, avant les sections enrichies (📍/🎯/🧰/📊/📎).
  String _extractMainDescription(String description) {
    final lines = description.split('\n');
    final buffer = StringBuffer();
    for (final line in lines) {
      if (line.startsWith('📍') ||
          line.startsWith('🎯') ||
          line.startsWith('🧰') ||
          line.startsWith('📊') ||
          line.startsWith('📎')) {
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

  /// Extrait le texte brut (plain_text) d'une propriété Notion.
  String _extractRichText(dynamic prop) {
    if (prop == null) return '';
    final list = (prop['rich_text'] ?? prop['title']) as List?;
    if (list == null || list.isEmpty) return '';
    return list
        .map((item) => (item as Map)['plain_text'] as String? ?? '')
        .join();
  }

  /// Extrait le contenu d'une propriété Notion en préservant le formatage
  /// Markdown (gras, italique, code, barré, liens) et les emojis.
  String _extractRichTextAsMarkdown(dynamic prop) {
    if (prop == null) return '';
    final list = (prop['rich_text'] ?? prop['title']) as List?;
    if (list == null || list.isEmpty) return '';

    return list.map((item) {
      final map = item as Map<String, dynamic>;
      String text = map['plain_text'] as String? ?? '';
      if (text.isEmpty) return '';

      // Annotations Notion → Markdown
      final annotations = map['annotations'] as Map<String, dynamic>?;
      if (annotations != null) {
        final bold = annotations['bold'] == true;
        final italic = annotations['italic'] == true;
        final strikethrough = annotations['strikethrough'] == true;
        final code = annotations['code'] == true;

        if (code) text = '`$text`';
        if (bold && italic) {
          text = '***$text***';
        } else if (bold) {
          text = '**$text**';
        } else if (italic) {
          text = '*$text*';
        }
        if (strikethrough) text = '~~$text~~';
      }

      // Liens
      final href = map['href'] as String?;
      if (href != null && href.isNotEmpty) {
        text = '[$text]($href)';
      }

      return text;
    }).join();
  }

  /// Extrait la valeur "affichable" d'une propriété Notion de n'importe quel type.
  String _extractPropertyValue(Map<String, dynamic> prop) {
    final type = prop['type'] as String?;
    switch (type) {
      case 'rich_text':
      case 'title':
        return _extractRichTextAsMarkdown(prop);
      case 'url':
        return (prop['url'] as String?) ?? '';
      case 'email':
        return (prop['email'] as String?) ?? '';
      case 'phone_number':
        return (prop['phone_number'] as String?) ?? '';
      case 'number':
        final num = prop['number'];
        return num != null ? num.toString() : '';
      case 'checkbox':
        return (prop['checkbox'] == true) ? '✅' : '☐';
      case 'select':
        final sel = prop['select'] as Map<String, dynamic>?;
        return sel?['name'] as String? ?? '';
      case 'multi_select':
        final ms = (prop['multi_select'] as List?) ?? [];
        return ms.map((e) => (e as Map)['name'] as String? ?? '').join(', ');
      case 'status':
        final st = prop['status'] as Map<String, dynamic>?;
        return st?['name'] as String? ?? '';
      case 'formula':
        final formula = prop['formula'] as Map<String, dynamic>?;
        if (formula == null) return '';
        final fType = formula['type'] as String?;
        if (fType == 'string') return formula['string'] as String? ?? '';
        if (fType == 'number') return formula['number']?.toString() ?? '';
        if (fType == 'boolean') return formula['boolean'] == true ? '✅' : '☐';
        return '';
      case 'rollup':
        final rollup = prop['rollup'] as Map<String, dynamic>?;
        if (rollup == null) return '';
        final rType = rollup['type'] as String?;
        if (rType == 'number') return rollup['number']?.toString() ?? '';
        if (rType == 'array') {
          final arr = (rollup['array'] as List?) ?? [];
          return arr
              .map((e) {
                if (e is Map<String, dynamic>) return _extractPropertyValue(e);
                return e.toString();
              })
              .where((s) => s.isNotEmpty)
              .join(', ');
        }
        return '';
      case 'date':
        final date = prop['date'] as Map<String, dynamic>?;
        if (date == null) return '';
        final start = date['start'] as String? ?? '';
        final end = date['end'] as String?;
        return end != null ? '$start → $end' : start;
      case 'people':
        final people = (prop['people'] as List?) ?? [];
        return people
            .map((p) => (p as Map)['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ');
      case 'files':
        final files = (prop['files'] as List?) ?? [];
        return files
            .map((f) {
              final fMap = f as Map<String, dynamic>;
              final name = fMap['name'] as String? ?? '';
              final fileObj = fMap['file'] as Map<String, dynamic>?;
              final extObj = fMap['external'] as Map<String, dynamic>?;
              final url =
                  fileObj?['url'] as String? ?? extObj?['url'] as String? ?? '';
              return name.isNotEmpty ? '[$name]($url)' : url;
            })
            .where((s) => s.isNotEmpty)
            .join(', ');
      default:
        return '';
    }
  }
}
