import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/tag_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../providers/tags_provider.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final EventModel? event;
  final DateTime? initialDate;

  const EventFormScreen({super.key, this.event, this.initialDate});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _startDate;
  late DateTime _endDate;
  bool _isAllDay = false;
  String _source = AppConstants.sourceInfomaniak;
  List<TagModel> _selectedTags = [];
  List<ParticipantModel> _participants = [];
  int? _reminderMinutes;
  String? _rrule;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    final event = widget.event;

    if (event != null) {
      _titleController.text = event.title;
      _locationController.text = event.location ?? '';
      _descriptionController.text = event.description ?? '';
      _startDate = event.startDate;
      _endDate = event.endDate;
      _isAllDay = event.isAllDay;
      _source = event.source;
      _selectedTags = List.from(event.tags);
      _participants = List.from(event.participants);
      _reminderMinutes = event.reminderMinutes;
      _rrule = event.rrule;
    } else {
      _startDate = DateTime(now.year, now.month, now.day, now.hour + 1);
      _endDate = _startDate.add(const Duration(hours: 1));
      _reminderMinutes = AppConstants.defaultReminderMinutes;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    final tagsAsync = ref.watch(tagsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier' : 'Nouvel événement'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                isEditing ? 'Enregistrer' : 'Créer',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Source
            _buildSourceSelector(),
            const SizedBox(height: 16),

            // Titre
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre *',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v?.trim().isEmpty == true ? 'Le titre est requis' : null,
            ),
            const SizedBox(height: 16),

            // Journée entière
            SwitchListTile(
              title: const Text('Journée entière'),
              value: _isAllDay,
              onChanged: (v) => setState(() => _isAllDay = v),
              contentPadding: EdgeInsets.zero,
            ),

            // Date et heure
            _buildDateTimeSection(),
            const SizedBox(height: 16),

            // Lieu
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Lieu',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),

            // Tags
            tagsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (tags) => _buildTagsSection(tags),
            ),
            const SizedBox(height: 16),

            // Participants (Infomaniak uniquement)
            if (_source == AppConstants.sourceInfomaniak) ...[
              _buildParticipantsSection(),
              const SizedBox(height: 16),
            ],

            // Rappel
            _buildReminderSection(),
            const SizedBox(height: 16),

            // Récurrence (Infomaniak uniquement)
            if (_source == AppConstants.sourceInfomaniak) ...[
              _buildRecurrenceSection(),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Destination',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSourceChip(
                    label: 'Infomaniak',
                    subtitle: 'Rendez-vous',
                    value: AppConstants.sourceInfomaniak,
                    icon: 'ik',
                    color: const Color(0xFF0D6EFD),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSourceChip(
                    label: 'Notion',
                    subtitle: 'Tâche / Projet',
                    value: AppConstants.sourceNotion,
                    icon: 'N',
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceChip({
    required String label,
    required String subtitle,
    required String value,
    required String icon,
    required Color color,
  }) {
    final isSelected = _source == value;
    return GestureDetector(
      onTap: () => setState(() => _source = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      children: [
        // Date de début
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: Text(
            _isAllDay
                ? CalendarDateUtils.formatDisplayDate(_startDate)
                : CalendarDateUtils.formatDisplayDateTime(_startDate),
          ),
          subtitle: const Text('Début'),
          onTap: () => _pickDateTime(isStart: true),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(
            _isAllDay
                ? CalendarDateUtils.formatDisplayDate(_endDate)
                : CalendarDateUtils.formatDisplayDateTime(_endDate),
          ),
          subtitle: const Text('Fin'),
          onTap: () => _pickDateTime(isStart: false),
        ),
      ],
    );
  }

  Widget _buildTagsSection(List<TagModel> allTags) {
    final categories = allTags.where((t) => t.isCategory).toList();
    final priorities = allTags.where((t) => t.isPriority).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Catégories',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: categories.map((tag) => _buildTagChip(tag)).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          'Priorité',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: priorities.map((tag) => _buildTagChip(tag)).toList(),
        ),
      ],
    );
  }

  Widget _buildTagChip(TagModel tag) {
    final isSelected = _selectedTags.any((t) => t.id == tag.id);
    final color = _colorFromHex(tag.colorHex);

    return FilterChip(
      label: Text(tag.name),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (tag.isPriority) {
            // Une seule priorité à la fois
            _selectedTags.removeWhere((t) => t.isPriority);
          }
          if (selected) {
            _selectedTags.add(tag);
          } else {
            _selectedTags.removeWhere((t) => t.id == tag.id);
          }
        });
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      side: BorderSide(
        color: isSelected ? color : Colors.transparent,
      ),
      labelStyle: TextStyle(
        color: isSelected ? color : null,
        fontWeight: isSelected ? FontWeight.w500 : null,
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Participants', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: _addParticipant,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        ..._participants.map(
          (p) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(p.name ?? p.email),
            subtitle: p.name != null ? Text(p.email) : null,
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() => _participants.remove(p));
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderSection() {
    return DropdownButtonFormField<int?>(
      value: _reminderMinutes,
      decoration: const InputDecoration(
        labelText: 'Rappel',
        prefixIcon: Icon(Icons.notifications_outlined),
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('Aucun')),
        DropdownMenuItem(value: 5, child: Text('5 minutes avant')),
        DropdownMenuItem(value: 10, child: Text('10 minutes avant')),
        DropdownMenuItem(value: 15, child: Text('15 minutes avant')),
        DropdownMenuItem(value: 30, child: Text('30 minutes avant')),
        DropdownMenuItem(value: 60, child: Text('1 heure avant')),
        DropdownMenuItem(value: 120, child: Text('2 heures avant')),
        DropdownMenuItem(value: 1440, child: Text('1 jour avant')),
      ],
      onChanged: (v) => setState(() => _reminderMinutes = v),
    );
  }

  Widget _buildRecurrenceSection() {
    return DropdownButtonFormField<String?>(
      value: _rrule,
      decoration: const InputDecoration(
        labelText: 'Récurrence',
        prefixIcon: Icon(Icons.repeat),
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('Aucune')),
        DropdownMenuItem(
          value: 'FREQ=DAILY',
          child: Text('Tous les jours'),
        ),
        DropdownMenuItem(
          value: 'FREQ=WEEKLY',
          child: Text('Chaque semaine'),
        ),
        DropdownMenuItem(
          value: 'FREQ=MONTHLY',
          child: Text('Chaque mois'),
        ),
        DropdownMenuItem(
          value: 'FREQ=YEARLY',
          child: Text('Chaque année'),
        ),
      ],
      onChanged: (v) => setState(() => _rrule = v),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );

    if (date == null || !mounted) return;

    if (_isAllDay) {
      setState(() {
        if (isStart) {
          _startDate = date;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = date;
        }
      });
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate),
    );

    if (time == null || !mounted) return;

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startDate = dt;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(hours: 1));
        }
      } else {
        _endDate = dt;
      }
    });
  }

  Future<void> _addParticipant() async {
    String email = '';
    String name = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un participant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Nom (optionnel)'),
              onChanged: (v) => name = v,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Email *'),
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) => email = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (confirmed == true && email.trim().isNotEmpty) {
      setState(() {
        _participants.add(ParticipantModel(
          email: email.trim(),
          name: name.trim().isEmpty ? null : name.trim(),
        ));
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isOffline = ref.read(isOfflineProvider);
    if (isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de créer/modifier en mode hors ligne'),
            backgroundColor: Color(0xFFFF6D00),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tagIds = _selectedTags
          .where((t) => t.id != null)
          .map((t) => t.id!)
          .toList();

      EventType type;
      if (_isAllDay) {
        type = _rrule != null ? EventType.recurring : EventType.allDay;
      } else if (_rrule != null) {
        type = EventType.recurring;
      } else if (_source == AppConstants.sourceNotion &&
          _endDate.difference(_startDate).inDays > 0) {
        type = EventType.multiDay;
      } else if (_source == AppConstants.sourceNotion) {
        type = EventType.task;
      } else {
        type = EventType.appointment;
      }

      final event = EventModel(
        id: widget.event?.id,
        remoteId: widget.event?.remoteId ?? const Uuid().v4(),
        source: _source,
        type: type,
        title: _titleController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        isAllDay: _isAllDay,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        participants: _participants,
        tagIds: tagIds,
        tags: _selectedTags,
        rrule: _rrule,
        calendarId: widget.event?.calendarId,
        notionPageId: widget.event?.notionPageId,
        reminderMinutes: _reminderMinutes,
        createdAt: widget.event?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        etag: widget.event?.etag,
      );

      final notifier = ref.read(eventsNotifierProvider.notifier);
      if (widget.event == null) {
        await notifier.createEvent(event);
      } else {
        await notifier.updateEvent(event);
      }

      // Push vers la source distante
      await ref.read(syncNotifierProvider.notifier).pushEvent(event);

      if (mounted) Navigator.pop(context, event);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
