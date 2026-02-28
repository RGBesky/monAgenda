import '../core/database/database_helper.dart';
import '../core/models/notion_database_model.dart';
import 'notion_service.dart';
import 'logger_service.dart';

/// Résultat de la validation d'un schéma Notion.
class SchemaValidationResult {
  final String databaseName;
  final String databaseId;
  final List<String> missingProperties;
  final List<String> warnings;
  final List<String> remappedProperties;
  final bool isValid;

  const SchemaValidationResult({
    required this.databaseName,
    required this.databaseId,
    this.missingProperties = const [],
    this.warnings = const [],
    this.remappedProperties = const [],
    required this.isValid,
  });

  bool get hasRemappings => remappedProperties.isNotEmpty;

  @override
  String toString() =>
      'SchemaValidation($databaseName): ${isValid ? "OK" : "ERREUR"}'
      '${missingProperties.isNotEmpty ? " — manquant: ${missingProperties.join(", ")}" : ""}'
      '${remappedProperties.isNotEmpty ? " — remappé: ${remappedProperties.join(", ")}" : ""}'
      '${warnings.isNotEmpty ? " — avertissements: ${warnings.join(", ")}" : ""}';
}

/// Vérifie que les bases Notion configurées possèdent
/// les propriétés attendues (Date, Tags/Category, Status).
/// Remappe automatiquement les propriétés renommées côté Notion.
class NotionSchemaValidator {
  final NotionService _notion;
  final DatabaseHelper _db;
  final AppLogger _logger;

  NotionSchemaValidator({
    required NotionService notion,
    DatabaseHelper? db,
    AppLogger? logger,
  })  : _notion = notion,
        _db = db ?? DatabaseHelper.instance,
        _logger = logger ?? AppLogger.instance;

  /// Valide et remappe toutes les bases Notion configurées et activées.
  /// Retourne la liste des résultats de validation (après remapping).
  /// Les bases dont le mapping est corrigé automatiquement sont marquées
  /// valides avec des entrées dans [remappedProperties].
  Future<List<SchemaValidationResult>> validateAll(
    List<NotionDatabaseModel> databases,
  ) async {
    if (!_notion.isConfigured) return [];

    final results = <SchemaValidationResult>[];

    for (final db in databases) {
      if (!db.isEnabled) continue;

      try {
        final result = await validateAndRemap(db);
        results.add(result);

        if (result.hasRemappings) {
          _logger.info(
            'NotionSchemaValidator',
            '${result.remappedProperties.length} propriété(s) remappée(s) '
                'automatiquement pour "${db.name}"',
            result.remappedProperties.join('\n'),
          );
        }

        if (!result.isValid) {
          _logger.warning(
            'NotionSchemaValidator',
            'Schéma invalide pour "${db.name}"',
            result.toString(),
          );
        } else if (result.warnings.isNotEmpty) {
          _logger.info(
            'NotionSchemaValidator',
            'Schéma OK avec avertissements pour "${db.name}"',
            result.warnings.join('\n'),
          );
        }
      } catch (e) {
        _logger.error(
          'NotionSchemaValidator',
          'Impossible de valider "${db.name}": $e',
        );
        results.add(SchemaValidationResult(
          databaseName: db.name,
          databaseId: db.effectiveSourceId,
          missingProperties: ['(erreur de connexion)'],
          isValid: false,
        ));
      }
    }

    return results;
  }

  /// Valide une base Notion et remappe automatiquement les propriétés
  /// introuvables en cherchant par type dans le schéma distant.
  ///
  /// Stratégie de remapping :
  /// 1. Propriété configurée introuvable → chercher par type exact
  /// 2. Si une seule correspondance par type → remapper automatiquement
  /// 3. Si plusieurs correspondances → chercher par nom similaire (candidats connus)
  /// 4. Si aucune correspondance → marquer comme erreur
  ///
  /// Le modèle SQLite est mis à jour immédiatement en cas de remapping.
  Future<SchemaValidationResult> validateAndRemap(
    NotionDatabaseModel db,
  ) async {
    final schema = await _notion.getDatabaseSchema(db.effectiveSourceId);
    final props = schema['properties'] as Map<String, dynamic>? ?? {};
    final propNames = props.keys.toSet();

    final missing = <String>[];
    final warnings = <String>[];
    final remapped = <String>[];

    // Accumule les changements de mapping pour un seul copyWith + update
    String titleProp = db.titleProperty;
    String? dateProp = db.startDateProperty;
    String? catProp = db.categoryProperty;
    String? statusProp = db.statusProperty;
    bool changed = false;

    // ── Vérification + auto-remap : Titre ──
    if (!propNames.contains(titleProp)) {
      final remap = _findByType(props, 'title');
      if (remap != null) {
        remapped.add('Titre: "${db.titleProperty}" → "$remap"');
        titleProp = remap;
        changed = true;
      } else {
        missing.add(
            'Titre "$titleProp" (introuvable — propriétés: ${propNames.join(", ")})');
      }
    } else {
      final type = _propType(props, titleProp);
      if (type != 'title') {
        warnings.add(
          'Titre "$titleProp" est de type "$type" au lieu de "title"',
        );
      }
    }

    // ── Vérification + auto-remap : Date (obligatoire) ──
    if (dateProp == null || dateProp.isEmpty) {
      // Pas configurée → tenter de trouver automatiquement
      final remap = _findByTypeWithCandidates(
        props,
        'date',
        ['Date', 'Date limite', 'Deadline', 'Échéance', 'Due', 'Date de début'],
      );
      if (remap != null) {
        remapped.add('Date: (non configurée) → "$remap"');
        dateProp = remap;
        changed = true;
      } else {
        missing.add('Date (non configurée, aucune propriété date trouvée)');
      }
    } else if (!propNames.contains(dateProp)) {
      // Configurée mais renommée → chercher par type + candidats
      final remap = _findByTypeWithCandidates(
        props,
        'date',
        [
          'Date',
          'Date limite',
          'Deadline',
          'Échéance',
          'Due',
          'Date de début',
          dateProp
        ],
      );
      if (remap != null) {
        remapped.add('Date: "$dateProp" → "$remap"');
        dateProp = remap;
        changed = true;
      } else {
        missing.add(
            'Date "$dateProp" (introuvable — propriétés: ${propNames.join(", ")})');
      }
    } else {
      final type = _propType(props, dateProp);
      if (type != 'date') {
        warnings.add(
          'Date "$dateProp" est de type "$type" au lieu de "date"',
        );
      }
    }

    // ── Vérification + auto-remap : Category/Tags (recommandée) ──
    if (catProp != null && catProp.isNotEmpty) {
      if (!propNames.contains(catProp)) {
        final remap = _findByTypeWithCandidates(
          props,
          'select',
          ['Projet', 'Catégorie', 'Category', 'Tags', 'Type', catProp],
          alternateTypes: ['multi_select'],
        );
        if (remap != null) {
          remapped.add('Catégorie: "$catProp" → "$remap"');
          catProp = remap;
          changed = true;
        } else {
          warnings.add(
              'Catégorie "$catProp" (introuvable — ignorée pour cette sync)');
        }
      } else {
        final type = _propType(props, catProp);
        if (type != 'select' && type != 'multi_select') {
          warnings.add(
            'Catégorie "$catProp" est de type "$type" au lieu de "select"/"multi_select"',
          );
        }
      }
    } else {
      warnings.add('Aucune propriété Catégorie/Tags configurée');
    }

    // ── Vérification + auto-remap : Status (recommandée) ──
    if (statusProp != null && statusProp.isNotEmpty) {
      if (!propNames.contains(statusProp)) {
        final remap = _findByTypeWithCandidates(
          props,
          'status',
          ['État', 'Status', 'Statut', statusProp],
          alternateTypes: ['select'],
        );
        if (remap != null) {
          remapped.add('Status: "$statusProp" → "$remap"');
          statusProp = remap;
          changed = true;
        } else {
          warnings.add(
              'Status "$statusProp" (introuvable — ignorée pour cette sync)');
        }
      } else {
        final type = _propType(props, statusProp);
        if (type != 'status' && type != 'select') {
          warnings.add(
            'Status "$statusProp" est de type "$type" au lieu de "status"/"select"',
          );
        }
      }
    } else {
      warnings.add('Aucune propriété Status configurée');
    }

    // ── Persister le remapping en SQLite si des changements ont été détectés ──
    if (changed && db.id != null) {
      final updated = db.copyWith(
        titleProperty: titleProp,
        startDateProperty: dateProp,
        categoryProperty: catProp,
        statusProperty: statusProp,
      );
      await _db.updateNotionDatabase(updated);
      _logger.info(
        'NotionSchemaValidator',
        'Mapping SQLite mis à jour pour "${db.name}"',
        remapped.join(' | '),
      );
    }

    return SchemaValidationResult(
      databaseName: db.name,
      databaseId: db.effectiveSourceId,
      missingProperties: missing,
      warnings: warnings,
      remappedProperties: remapped,
      isValid: missing.isEmpty,
    );
  }

  /// Cherche une propriété par type exact.
  /// Retourne le nom si une seule correspondance, null sinon.
  String? _findByType(Map<String, dynamic> props, String type) {
    final matches = props.entries
        .where((e) => _propType(props, e.key) == type)
        .map((e) => e.key)
        .toList();
    return matches.length == 1 ? matches.first : null;
  }

  /// Cherche une propriété par type + noms candidats.
  /// 1. Filtrer par [type] (+ [alternateTypes])
  /// 2. Si une seule correspondance → retourner directement
  /// 3. Si plusieurs → chercher parmi les candidats (insensible à la casse)
  /// 4. Sinon → retourner la première correspondance de type
  String? _findByTypeWithCandidates(
    Map<String, dynamic> props,
    String type,
    List<String> candidates, {
    List<String> alternateTypes = const [],
  }) {
    final validTypes = {type, ...alternateTypes};
    final matches = props.entries
        .where((e) => validTypes.contains(_propType(props, e.key)))
        .map((e) => e.key)
        .toList();

    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first;

    // Plusieurs correspondances → préférer un candidat connu
    for (final candidate in candidates) {
      final match = matches.firstWhereOrNull(
        (m) => m.toLowerCase() == candidate.toLowerCase(),
      );
      if (match != null) return match;
    }

    // Recherche partielle : le nom contient un candidat
    for (final candidate in candidates) {
      final match = matches.firstWhereOrNull(
        (m) => m.toLowerCase().contains(candidate.toLowerCase()),
      );
      if (match != null) return match;
    }

    // Fallback : prendre la première correspondance par type
    return matches.first;
  }

  /// Extrait le type d'une propriété Notion.
  String _propType(Map<String, dynamic> props, String name) {
    final prop = props[name] as Map<String, dynamic>?;
    return prop?['type'] as String? ?? 'unknown';
  }
}

/// Extension pour firstWhereOrNull (évite l'import de collection).
extension _IterableExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
