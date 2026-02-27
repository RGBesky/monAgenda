import '../core/models/notion_database_model.dart';
import 'notion_service.dart';
import 'logger_service.dart';

/// Résultat de la validation d'un schéma Notion.
class SchemaValidationResult {
  final String databaseName;
  final String databaseId;
  final List<String> missingProperties;
  final List<String> warnings;
  final bool isValid;

  const SchemaValidationResult({
    required this.databaseName,
    required this.databaseId,
    this.missingProperties = const [],
    this.warnings = const [],
    required this.isValid,
  });

  @override
  String toString() =>
      'SchemaValidation($databaseName): ${isValid ? "OK" : "ERREUR"}'
      '${missingProperties.isNotEmpty ? " — manquant: ${missingProperties.join(", ")}" : ""}'
      '${warnings.isNotEmpty ? " — avertissements: ${warnings.join(", ")}" : ""}';
}

/// Vérifie que les bases Notion configurées possèdent
/// les propriétés attendues (Date, Tags/Category, Status).
class NotionSchemaValidator {
  final NotionService _notion;
  final AppLogger _logger;

  NotionSchemaValidator({
    required NotionService notion,
    AppLogger? logger,
  })  : _notion = notion,
        _logger = logger ?? AppLogger.instance;

  /// Valide toutes les bases Notion configurées et activées.
  /// Retourne la liste des résultats de validation.
  Future<List<SchemaValidationResult>> validateAll(
    List<NotionDatabaseModel> databases,
  ) async {
    if (!_notion.isConfigured) return [];

    final results = <SchemaValidationResult>[];

    for (final db in databases) {
      if (!db.isEnabled) continue;

      try {
        final result = await validateDatabase(db);
        results.add(result);

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

  /// Valide une base Notion individuelle.
  /// Vérifie que les colonnes configurées (Date, Tags/Category, Status)
  /// existent réellement dans le schéma distant.
  Future<SchemaValidationResult> validateDatabase(
    NotionDatabaseModel db,
  ) async {
    final schema = await _notion.getDatabaseSchema(db.effectiveSourceId);
    final props = schema['properties'] as Map<String, dynamic>? ?? {};
    final propNames = props.keys.toSet();

    final missing = <String>[];
    final warnings = <String>[];

    // ── Vérification propriété Date (obligatoire) ──
    final dateProp = db.startDateProperty;
    if (dateProp == null || dateProp.isEmpty) {
      missing.add('Date (non configurée)');
    } else if (!propNames.contains(dateProp)) {
      missing.add(
          'Date "$dateProp" (introuvable — propriétés: ${propNames.join(", ")})');
    } else {
      // Vérifier le type
      final type = _propType(props, dateProp);
      if (type != 'date') {
        warnings.add(
          'Date "$dateProp" est de type "$type" au lieu de "date"',
        );
      }
    }

    // ── Vérification propriété Category/Tags (recommandée) ──
    final catProp = db.categoryProperty;
    if (catProp != null && catProp.isNotEmpty) {
      if (!propNames.contains(catProp)) {
        missing.add(
            'Catégorie "$catProp" (introuvable — propriétés: ${propNames.join(", ")})');
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

    // ── Vérification propriété Status (recommandée) ──
    final statusProp = db.statusProperty;
    if (statusProp != null && statusProp.isNotEmpty) {
      if (!propNames.contains(statusProp)) {
        missing.add(
            'Status "$statusProp" (introuvable — propriétés: ${propNames.join(", ")})');
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

    // ── Vérification propriété Titre ──
    if (!propNames.contains(db.titleProperty)) {
      missing.add(
          'Titre "${db.titleProperty}" (introuvable — propriétés: ${propNames.join(", ")})');
    } else {
      final type = _propType(props, db.titleProperty);
      if (type != 'title') {
        warnings.add(
          'Titre "${db.titleProperty}" est de type "$type" au lieu de "title"',
        );
      }
    }

    return SchemaValidationResult(
      databaseName: db.name,
      databaseId: db.effectiveSourceId,
      missingProperties: missing,
      warnings: warnings,
      isValid: missing.isEmpty,
    );
  }

  /// Extrait le type d'une propriété Notion.
  String _propType(Map<String, dynamic> props, String name) {
    final prop = props[name] as Map<String, dynamic>?;
    return prop?['type'] as String? ?? 'unknown';
  }
}
