import 'package:equatable/equatable.dart';

class NotionDatabaseModel extends Equatable {
  final int? id;
  final String notionId;         // ID de la base de données Notion
  final String name;
  final String titleProperty;    // Nom de la propriété titre
  final String? startDateProperty;
  final String? endDateProperty;
  final String? categoryProperty;
  final String? priorityProperty;
  final String? descriptionProperty;
  final String? participantsProperty;
  final String? statusProperty;
  final bool isEnabled;
  final DateTime? lastSyncedAt;

  const NotionDatabaseModel({
    this.id,
    required this.notionId,
    required this.name,
    this.titleProperty = 'Name',
    this.startDateProperty,
    this.endDateProperty,
    this.categoryProperty,
    this.priorityProperty,
    this.descriptionProperty,
    this.participantsProperty,
    this.statusProperty,
    this.isEnabled = true,
    this.lastSyncedAt,
  });

  NotionDatabaseModel copyWith({
    int? id,
    String? notionId,
    String? name,
    String? titleProperty,
    String? startDateProperty,
    String? endDateProperty,
    String? categoryProperty,
    String? priorityProperty,
    String? descriptionProperty,
    String? participantsProperty,
    String? statusProperty,
    bool? isEnabled,
    DateTime? lastSyncedAt,
  }) {
    return NotionDatabaseModel(
      id: id ?? this.id,
      notionId: notionId ?? this.notionId,
      name: name ?? this.name,
      titleProperty: titleProperty ?? this.titleProperty,
      startDateProperty: startDateProperty ?? this.startDateProperty,
      endDateProperty: endDateProperty ?? this.endDateProperty,
      categoryProperty: categoryProperty ?? this.categoryProperty,
      priorityProperty: priorityProperty ?? this.priorityProperty,
      descriptionProperty: descriptionProperty ?? this.descriptionProperty,
      participantsProperty: participantsProperty ?? this.participantsProperty,
      statusProperty: statusProperty ?? this.statusProperty,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notion_id': notionId,
      'name': name,
      'title_property': titleProperty,
      'start_date_property': startDateProperty,
      'end_date_property': endDateProperty,
      'category_property': categoryProperty,
      'priority_property': priorityProperty,
      'description_property': descriptionProperty,
      'participants_property': participantsProperty,
      'status_property': statusProperty,
      'is_enabled': isEnabled ? 1 : 0,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
  }

  factory NotionDatabaseModel.fromMap(Map<String, dynamic> map) {
    return NotionDatabaseModel(
      id: map['id'] as int?,
      notionId: map['notion_id'] as String,
      name: map['name'] as String,
      titleProperty: map['title_property'] as String? ?? 'Name',
      startDateProperty: map['start_date_property'] as String?,
      endDateProperty: map['end_date_property'] as String?,
      categoryProperty: map['category_property'] as String?,
      priorityProperty: map['priority_property'] as String?,
      descriptionProperty: map['description_property'] as String?,
      participantsProperty: map['participants_property'] as String?,
      statusProperty: map['status_property'] as String?,
      isEnabled: (map['is_enabled'] as int?) == 1,
      lastSyncedAt: map['last_synced_at'] != null
          ? DateTime.parse(map['last_synced_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, notionId, name];
}
