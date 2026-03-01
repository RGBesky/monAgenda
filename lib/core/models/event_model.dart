import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../constants/app_constants.dart';
import 'tag_model.dart';

enum EventType {
  appointment, // Rendez-vous simple
  allDay, // Journée entière
  recurring, // Récurrent
  task, // Tâche Notion
  multiDay, // Projet multi-jours Notion
}

class ParticipantModel extends Equatable {
  final String email;
  final String? name;
  final String status; // 'accepted', 'declined', 'pending'

  const ParticipantModel({
    required this.email,
    this.name,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'status': status,
      };

  factory ParticipantModel.fromMap(Map<String, dynamic> map) =>
      ParticipantModel(
        email: map['email'] as String,
        name: map['name'] as String?,
        status: map['status'] as String? ?? 'pending',
      );

  @override
  List<Object?> get props => [email, status];
}

class EventModel extends Equatable {
  final int? id;
  final String? remoteId; // UID ical ou page ID Notion
  final String source; // 'infomaniak', 'notion', 'ics'
  final EventType type;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final bool isAllDay;
  final String? location;
  final String? description;
  final List<ParticipantModel> participants;
  final List<int> tagIds; // IDs locaux des tags
  final List<TagModel> tags; // Objets tags (jointure)
  final String? rrule; // Règle récurrence RRULE
  final String? recurrenceId; // Pour les exceptions de récurrence
  final String? calendarId; // ID calendrier Infomaniak
  final String? notionPageId;
  final String? icsSubscriptionId;
  final String? status; // État d'avancement (Notion)
  final int? reminderMinutes;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? syncedAt;
  final String? etag; // ETag pour la détection de conflits CalDAV
  final List<String> smartAttachments; // Chemins fichiers attachés (Desktop)

  const EventModel({
    this.id,
    this.remoteId,
    required this.source,
    required this.type,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.isAllDay = false,
    this.location,
    this.description,
    this.participants = const [],
    this.tagIds = const [],
    this.tags = const [],
    this.rrule,
    this.recurrenceId,
    this.calendarId,
    this.notionPageId,
    this.icsSubscriptionId,
    this.status,
    this.reminderMinutes,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
    this.syncedAt,
    this.etag,
    this.smartAttachments = const [],
  });

  bool get isFromInfomaniak => source == AppConstants.sourceInfomaniak;
  bool get isFromNotion => source == AppConstants.sourceNotion;
  bool get isFromIcs => source == AppConstants.sourceIcs;
  bool get isTask => type == EventType.task;
  bool get isMultiDay =>
      type == EventType.multiDay ||
      (endDate.difference(startDate).inDays > 0 && !isAllDay);

  TagModel? get priorityTag => tags.where((t) => t.isPriority).firstOrNull;
  List<TagModel> get categoryTags => tags.where((t) => t.isCategory).toList();
  TagModel? get statusTag => tags.where((t) => t.isStatus).firstOrNull;

  EventModel copyWith({
    int? id,
    String? remoteId,
    String? source,
    EventType? type,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    bool? isAllDay,
    String? location,
    String? description,
    List<ParticipantModel>? participants,
    List<int>? tagIds,
    List<TagModel>? tags,
    String? rrule,
    String? recurrenceId,
    String? calendarId,
    String? notionPageId,
    String? icsSubscriptionId,
    String? status,
    int? reminderMinutes,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    String? etag,
    List<String>? smartAttachments,
  }) {
    return EventModel(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      source: source ?? this.source,
      type: type ?? this.type,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      description: description ?? this.description,
      participants: participants ?? this.participants,
      tagIds: tagIds ?? this.tagIds,
      tags: tags ?? this.tags,
      rrule: rrule ?? this.rrule,
      recurrenceId: recurrenceId ?? this.recurrenceId,
      calendarId: calendarId ?? this.calendarId,
      notionPageId: notionPageId ?? this.notionPageId,
      icsSubscriptionId: icsSubscriptionId ?? this.icsSubscriptionId,
      status: status ?? this.status,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      etag: etag ?? this.etag,
      smartAttachments: smartAttachments ?? this.smartAttachments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'source': source,
      'type': type.name,
      'title': title,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_all_day': isAllDay ? 1 : 0,
      'location': location,
      'description': description,
      'participants': jsonEncode(participants.map((p) => p.toMap()).toList()),
      'tag_ids': jsonEncode(tagIds),
      'rrule': rrule,
      'recurrence_id': recurrenceId,
      'calendar_id': calendarId,
      'notion_page_id': notionPageId,
      'ics_subscription_id': icsSubscriptionId,
      'status': status,
      'reminder_minutes': reminderMinutes,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'etag': etag,
      'smart_attachments': jsonEncode(smartAttachments),
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    final participantsList = map['participants'] != null
        ? (jsonDecode(map['participants'] as String) as List)
            .map((p) => ParticipantModel.fromMap(p as Map<String, dynamic>))
            .toList()
        : <ParticipantModel>[];

    final tagIdsList = map['tag_ids'] != null
        ? (jsonDecode(map['tag_ids'] as String) as List)
            .map((id) => id as int)
            .toList()
        : <int>[];

    return EventModel(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as String?,
      source: map['source'] as String,
      type: EventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => EventType.appointment,
      ),
      title: map['title'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isAllDay: (map['is_all_day'] as int?) == 1,
      location: map['location'] as String?,
      description: map['description'] as String?,
      participants: participantsList,
      tagIds: tagIdsList,
      rrule: map['rrule'] as String?,
      recurrenceId: map['recurrence_id'] as String?,
      calendarId: map['calendar_id'] as String?,
      notionPageId: map['notion_page_id'] as String?,
      icsSubscriptionId: map['ics_subscription_id'] as String?,
      status: map['status'] as String?,
      reminderMinutes: map['reminder_minutes'] as int?,
      isDeleted: (map['is_deleted'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      etag: map['etag'] as String?,
      smartAttachments: map['smart_attachments'] != null
          ? (jsonDecode(map['smart_attachments'] as String) as List)
              .cast<String>()
          : <String>[],
    );
  }

  @override
  List<Object?> get props => [
        id,
        remoteId,
        source,
        type,
        title,
        startDate,
        endDate,
        isAllDay,
        location,
        description,
        participants,
        tagIds,
        tags,
        rrule,
        recurrenceId,
        calendarId,
        notionPageId,
        icsSubscriptionId,
        status,
        reminderMinutes,
        isDeleted,
        createdAt,
        updatedAt,
        syncedAt,
        etag,
        smartAttachments,
      ];
}
