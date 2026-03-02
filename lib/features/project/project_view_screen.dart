import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/event_model.dart';
import '../../providers/events_provider.dart';
import '../../providers/sync_provider.dart';
import '../../services/logger_service.dart';

// ─── Model ────────────────────────────────────────────────────

/// Tâche Notion sans date, candidate au Time Blocking.
class NotionTaskModel {
  final String id; // Notion page ID
  final String title;
  final String? category;
  final String? status;
  final String? priority;
  final String databaseName;
  final Color color;
  final String databaseId;

  const NotionTaskModel({
    required this.id,
    required this.title,
    this.category,
    this.status,
    this.priority,
    this.databaseName = '',
    this.color = const Color(0xFF5856D6),
    required this.databaseId,
  });

  NotionTaskModel copyWith({
    String? id,
    String? title,
    String? category,
    String? status,
    String? priority,
    String? databaseName,
    Color? color,
    String? databaseId,
  }) {
    return NotionTaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      databaseName: databaseName ?? this.databaseName,
      color: color ?? this.color,
      databaseId: databaseId ?? this.databaseId,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────

/// Charge les tâches Notion sans date (=non planifiées).
class NotionProjectTasksNotifier extends AsyncNotifier<List<NotionTaskModel>> {
  @override
  Future<List<NotionTaskModel>> build() async {
    return _loadUndatedTasks();
  }

  Future<List<NotionTaskModel>> _loadUndatedTasks() async {
    final notion = ref.read(notionServiceProvider);
    if (!notion.isConfigured) return [];

    try {
      final dbs = await ref.read(notionDatabasesProvider.future);
      final tasks = <NotionTaskModel>[];

      for (final db in dbs) {
        final results = await notion.queryDatabaseRaw(
          databaseId: db.effectiveSourceId,
          filter: {
            'property': db.startDateProperty ?? 'Date',
            'date': {'is_empty': true},
          },
        );
        for (final page in results) {
          final title = _extractPageTitle(page);
          if (title.isEmpty) continue;
          final props = page['properties'] as Map<String, dynamic>? ?? {};
          tasks.add(NotionTaskModel(
            id: page['id'] as String,
            title: title,
            category: _extractSelectValue(props, db.categoryProperty),
            status: _extractStatusValue(props, db.statusProperty),
            priority: _extractSelectValue(props, db.priorityProperty),
            databaseName: db.name,
            databaseId: db.effectiveSourceId,
            color: AppColors.sourceNotion,
          ));
        }
      }
      return tasks;
    } catch (e) {
      AppLogger.instance.error('ProjectView', 'Erreur chargement tâches', e);
      return [];
    }
  }

  String _extractPageTitle(Map<String, dynamic> page) {
    final props = page['properties'] as Map<String, dynamic>? ?? {};
    for (final entry in props.entries) {
      final prop = entry.value as Map<String, dynamic>;
      if (prop['type'] == 'title') {
        final titleList = prop['title'] as List?;
        if (titleList != null && titleList.isNotEmpty) {
          return (titleList.first['plain_text'] as String?) ?? '';
        }
      }
    }
    return '';
  }

  /// Extrait la valeur d'une propriété select/multi_select Notion.
  String? _extractSelectValue(
      Map<String, dynamic> props, String? propertyName) {
    if (propertyName == null) return null;
    final prop = props[propertyName] as Map<String, dynamic>?;
    if (prop == null) return null;
    final type = prop['type'] as String?;
    if (type == 'select') {
      final select = prop['select'] as Map<String, dynamic>?;
      return select?['name'] as String?;
    } else if (type == 'multi_select') {
      final list = prop['multi_select'] as List?;
      if (list != null && list.isNotEmpty) {
        return (list.first as Map<String, dynamic>)['name'] as String?;
      }
    }
    return null;
  }

  /// Extrait la valeur d'une propriété status Notion.
  String? _extractStatusValue(
      Map<String, dynamic> props, String? propertyName) {
    if (propertyName == null) return null;
    final prop = props[propertyName] as Map<String, dynamic>?;
    if (prop == null) return null;
    final type = prop['type'] as String?;
    if (type == 'status') {
      final status = prop['status'] as Map<String, dynamic>?;
      return status?['name'] as String?;
    }
    // Fallback : certaines BDD utilisent un select pour le statut
    return _extractSelectValue(props, propertyName);
  }

  /// Assigne une date à une tâche (Optimistic UI).
  Future<void> assignDate(
      String taskId, String databaseId, DateTime date) async {
    // Optimistic : retirer de la liste
    final prev = state.valueOrNull ?? [];
    final task = prev.firstWhere((t) => t.id == taskId);
    state = AsyncData(prev.where((t) => t.id != taskId).toList());

    try {
      final notion = ref.read(notionServiceProvider);
      await notion.updatePageDate(taskId, date);

      // Invalider les événements pour rafraîchir le calendrier
      ref.invalidate(eventsInRangeProvider);
    } catch (e) {
      // Rollback
      AppLogger.instance.error(
        'ProjectView',
        'Erreur assignDate pour $taskId',
        e,
      );
      state = AsyncData([...state.valueOrNull ?? [], task]);
    }
  }
}

final notionProjectTasksProvider =
    AsyncNotifierProvider<NotionProjectTasksNotifier, List<NotionTaskModel>>(
  NotionProjectTasksNotifier.new,
);

// ─── Screen ───────────────────────────────────────────────────

/// Vue Projet : Split-panel (SfCalendar + liste tâches Notion) — Desktop only.
class ProjectViewScreen extends ConsumerStatefulWidget {
  const ProjectViewScreen({super.key});

  @override
  ConsumerState<ProjectViewScreen> createState() => _ProjectViewScreenState();
}

class _ProjectViewScreenState extends ConsumerState<ProjectViewScreen> {
  late CalendarController _calendarController;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
    _calendarController.view = CalendarView.workWeek;
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    if (!isDesktop) {
      return const Scaffold(
        body: Center(
          child: Text('Le Time Blocking est disponible uniquement sur Desktop'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vue Projet — Time Blocking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(notionProjectTasksProvider),
            tooltip: 'Rafraîchir les tâches',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            return const Center(
              child: Text('Élargissez la fenêtre pour le Time Blocking'),
            );
          }
          return Row(
            children: [
              // Gauche : Calendrier hebdomadaire (flex 3)
              Expanded(
                flex: 3,
                child: _buildCalendar(context),
              ),
              const VerticalDivider(width: 1),
              // Droite : Tâches Notion non datées (flex 1)
              Expanded(
                flex: 1,
                child: _buildTaskPanel(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final eventsAsync = ref.watch(eventsInRangeProvider);
    final events = eventsAsync.valueOrNull ?? [];

    return DragTarget<NotionTaskModel>(
      onAcceptWithDetails: (details) {
        // Extraire la date du drop via le controller
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final localOffset = renderBox.globalToLocal(details.offset);
        final calendarDetails =
            _calendarController.getCalendarDetailsAtOffset?.call(localOffset);
        if (calendarDetails?.date != null) {
          ref.read(notionProjectTasksProvider.notifier).assignDate(
                details.data.id,
                details.data.databaseId,
                calendarDetails!.date!,
              );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDragging = candidateData.isNotEmpty;
        return Container(
          decoration: isDragging
              ? BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                    width: 2,
                  ),
                )
              : null,
          child: SfCalendar(
            controller: _calendarController,
            view: CalendarView.workWeek,
            firstDayOfWeek: 1,
            timeSlotViewSettings: const TimeSlotViewSettings(
              startHour: 7,
              endHour: 21,
              timeIntervalHeight: 60,
            ),
            dataSource: _EventDataSource(events),
          ),
        );
      },
    );
  }

  Widget _buildTaskPanel(BuildContext context) {
    final tasksAsync = ref.watch(notionProjectTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Tâches non planifiées',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (tasks) {
              if (tasks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Aucune tâche sans date.\nToutes les tâches Notion sont planifiées.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return _buildDraggableTask(task);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableTask(NotionTaskModel task) {
    return Draggable<NotionTaskModel>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: task.color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            task.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTaskCard(task),
      ),
      child: _buildTaskCard(task),
    );
  }

  Widget _buildTaskCard(NotionTaskModel task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: task.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: task.category != null
            ? Text(task.category!, style: const TextStyle(fontSize: 11))
            : null,
      ),
    );
  }
}

// ─── Calendar Data Source ──────────────────────────────────────

class _EventDataSource extends CalendarDataSource {
  _EventDataSource(List<EventModel> events) {
    appointments = events
        .map((e) => Appointment(
              startTime: e.startDate,
              endTime: e.endDate,
              subject: e.title,
              color: e.isFromInfomaniak
                  ? AppColors.sourceInfomaniak
                  : e.isFromIcs
                      ? AppColors.sourceIcs
                      : AppColors.sourceNotion,
              isAllDay: e.isAllDay,
            ))
        .toList();
  }
}
