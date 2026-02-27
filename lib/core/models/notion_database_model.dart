import 'dart:convert';
import 'package:equatable/equatable.dart';

class NotionDatabaseModel extends Equatable {
  final int? id;
  final String notionId; // ID de la base de données Notion
  final String? dataSourceId; // ID du data source (API 2025-09-03)
  final String name;
  final String titleProperty; // Nom de la propriété titre
  final String? startDateProperty;
  final String? endDateProperty;
  final String? categoryProperty;
  final String? priorityProperty;

  /// Liste de propriétés Notion à concaténer dans la description.
  /// Rétro-compatible : une seule valeur est possible (migration transparente).
  final List<String> descriptionProperties;
  final String? participantsProperty;
  final String? statusProperty;
  final String? locationProperty; // Où ?
  final String? objectiveProperty; // Pourquoi ?
  final String? materialProperty; // Quoi ?
  final bool isEnabled;
  final DateTime? lastSyncedAt;

  const NotionDatabaseModel({
    this.id,
    required this.notionId,
    this.dataSourceId,
    required this.name,
    this.titleProperty = 'Name',
    this.startDateProperty,
    this.endDateProperty,
    this.categoryProperty,
    this.priorityProperty,
    this.descriptionProperties = const [],
    this.participantsProperty,
    this.statusProperty,
    this.locationProperty,
    this.objectiveProperty,
    this.materialProperty,
    this.isEnabled = true,
    this.lastSyncedAt,
  });

  /// Getter rétro-compatible : renvoie la première propriété ou null.
  String? get descriptionProperty =>
      descriptionProperties.isNotEmpty ? descriptionProperties.first : null;

  /// L'identifiant effectif pour les opérations API (data_source_id ou fallback notionId).
  String get effectiveSourceId => dataSourceId ?? notionId;

  NotionDatabaseModel copyWith({
    int? id,
    String? notionId,
    String? dataSourceId,
    String? name,
    String? titleProperty,
    String? startDateProperty,
    String? endDateProperty,
    String? categoryProperty,
    String? priorityProperty,
    List<String>? descriptionProperties,
    String? participantsProperty,
    String? statusProperty,
    String? locationProperty,
    String? objectiveProperty,
    String? materialProperty,
    bool? isEnabled,
    DateTime? lastSyncedAt,
  }) {
    return NotionDatabaseModel(
      id: id ?? this.id,
      notionId: notionId ?? this.notionId,
      dataSourceId: dataSourceId ?? this.dataSourceId,
      name: name ?? this.name,
      titleProperty: titleProperty ?? this.titleProperty,
      startDateProperty: startDateProperty ?? this.startDateProperty,
      endDateProperty: endDateProperty ?? this.endDateProperty,
      categoryProperty: categoryProperty ?? this.categoryProperty,
      priorityProperty: priorityProperty ?? this.priorityProperty,
      descriptionProperties:
          descriptionProperties ?? this.descriptionProperties,
      participantsProperty: participantsProperty ?? this.participantsProperty,
      statusProperty: statusProperty ?? this.statusProperty,
      locationProperty: locationProperty ?? this.locationProperty,
      objectiveProperty: objectiveProperty ?? this.objectiveProperty,
      materialProperty: materialProperty ?? this.materialProperty,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notion_id': notionId,
      'data_source_id': dataSourceId,
      'name': name,
      'title_property': titleProperty,
      'start_date_property': startDateProperty,
      'end_date_property': endDateProperty,
      'category_property': categoryProperty,
      'priority_property': priorityProperty,
      // Stocké en JSON array pour multi-select, rétro-compatible
      'description_property': descriptionProperties.isEmpty
          ? null
          : jsonEncode(descriptionProperties),
      'participants_property': participantsProperty,
      'status_property': statusProperty,
      'location_property': locationProperty,
      'objective_property': objectiveProperty,
      'material_property': materialProperty,
      'is_enabled': isEnabled ? 1 : 0,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
  }

  factory NotionDatabaseModel.fromMap(Map<String, dynamic> map) {
    // Rétro-compatibilité : description_property peut être un JSON array
    // ou une simple string (ancienne version).
    final rawDesc = map['description_property'] as String?;
    List<String> descProps = [];
    if (rawDesc != null && rawDesc.isNotEmpty) {
      if (rawDesc.startsWith('[')) {
        descProps = (jsonDecode(rawDesc) as List).cast<String>();
      } else {
        descProps = [rawDesc];
      }
    }

    return NotionDatabaseModel(
      id: map['id'] as int?,
      notionId: map['notion_id'] as String,
      dataSourceId: map['data_source_id'] as String?,
      name: map['name'] as String,
      titleProperty: map['title_property'] as String? ?? 'Name',
      startDateProperty: map['start_date_property'] as String?,
      endDateProperty: map['end_date_property'] as String?,
      categoryProperty: map['category_property'] as String?,
      priorityProperty: map['priority_property'] as String?,
      descriptionProperties: descProps,
      participantsProperty: map['participants_property'] as String?,
      statusProperty: map['status_property'] as String?,
      locationProperty: map['location_property'] as String?,
      objectiveProperty: map['objective_property'] as String?,
      materialProperty: map['material_property'] as String?,
      isEnabled: (map['is_enabled'] as int?) == 1,
      lastSyncedAt: map['last_synced_at'] != null
          ? DateTime.parse(map['last_synced_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, notionId, name];
}
