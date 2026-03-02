import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/tag_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../providers/tags_provider.dart';
import '../../../services/logger_service.dart';
import '../../../app.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final EventModel? event;
  final DateTime? initialDate;
  final String? initialSource;

  /// Si true, n'affiche pas le Scaffold/AppBar (pour usage intégré dans un Dialog).
  final bool asDialogBody;

  /// Callback appelé avec l'événement sauvegardé (en mode dialog).
  final ValueChanged<EventModel>? onSaved;

  /// Callback pour revenir à la vue détail (en mode dialog).
  final VoidCallback? onCancel;

  const EventFormScreen({
    super.key,
    this.event,
    this.initialDate,
    this.initialSource,
    this.asDialogBody = false,
    this.onSaved,
    this.onCancel,
  });

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
  String? _selectedNotionDbId; // effectiveSourceId de la BDD Notion cible

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
      _selectedNotionDbId = event.calendarId;
    } else {
      _startDate = DateTime(now.year, now.month, now.day, now.hour + 1);
      _endDate = _startDate.add(const Duration(hours: 1));
      _reminderMinutes = AppConstants.defaultReminderMinutes;
      if (widget.initialSource != null) {
        _source = widget.initialSource!;
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryIconColor =
        isDark ? const Color(0xFF9B9A97) : const Color(0xFF787774);

    // ── Contenu du formulaire (partagé entre Scaffold et Dialog) ──
    final formBody = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Source
          _buildSourceSelector(),
          // Sélecteur BDD Notion (visible uniquement si source = Notion)
          if (_source == AppConstants.sourceNotion) _buildNotionDbSelector(),
          const SizedBox(height: 16),

          // Titre
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Titre *',
              prefixIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedTask01,
                  color: secondaryIconColor,
                  size: 18),
              border: const OutlineInputBorder(),
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
            decoration: InputDecoration(
              labelText: 'Lieu',
              prefixIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedLocation01,
                  color: secondaryIconColor,
                  size: 18),
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              prefixIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedNote01,
                  color: secondaryIconColor,
                  size: 18),
              border: const OutlineInputBorder(),
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
    );

    // ── Mode Dialog : header intégré + formulaire, sans Scaffold ──
    if (widget.asDialogBody) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  onPressed: () => widget.onCancel?.call(),
                  splashRadius: 18,
                  tooltip: 'Retour',
                ),
                Text(
                  isEditing ? 'Modifier' : 'Nouvel événement',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(14),
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
                      'Enregistrer',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: formBody),
        ],
      );
    }

    // ── Mode plein écran : Scaffold classique ──
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
      body: formBody,
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF9B9A97)
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotionDbSelector() {
    final notionDbsAsync = ref.watch(notionDatabasesProvider);
    return notionDbsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Erreur chargement BDD Notion: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (dbs) {
        final enabledDbs = dbs.where((d) => d.isEnabled).toList();
        if (enabledDbs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aucune base Notion configurée. Allez dans Paramètres.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        // Auto-sélectionner "Agenda des tâches" par défaut, sinon la première BDD
        if (_selectedNotionDbId == null ||
            !enabledDbs
                .any((d) => d.effectiveSourceId == _selectedNotionDbId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                final agendaTaches = enabledDbs
                    .where(
                      (d) =>
                          d.name.toLowerCase().contains('agenda des tâches') ||
                          d.name.toLowerCase().contains('agenda des taches'),
                    )
                    .firstOrNull;
                _selectedNotionDbId =
                    (agendaTaches ?? enabledDbs.first).effectiveSourceId;
              });
            }
          });
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Base de données Notion',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...enabledDbs.map((db) => RadioListTile<String>(
                        title: Text(db.name),
                        subtitle: Text(db.effectiveSourceId.substring(0, 8)),
                        value: db.effectiveSourceId,
                        groupValue: _selectedNotionDbId,
                        onChanged: (v) =>
                            setState(() => _selectedNotionDbId = v),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                ],
              ),
            ),
          ),
        );
      },
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
              ? color.withValues(alpha: 0.1)
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
                  style: TextStyle(
                    color: color.computeLuminance() > 0.4
                        ? Colors.black87
                        : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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
          leading: const HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              color: Color(0xFF007AFF),
              size: 20),
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
          leading: HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar02,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF9B9A97)
                  : const Color(0xFF787774),
              size: 20),
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
    final statuses = allTags.where((t) => t.isStatus).toList();

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
        if (statuses.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'État',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: statuses.map((tag) => _buildTagChip(tag)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTagChip(TagModel tag) {
    final isSelected = _selectedTags.any((t) => t.id == tag.id);
    final color = AppColors.fromHex(tag.colorHex);

    return FilterChip(
      label: Text(tag.name),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (tag.isPriority) {
            // Une seule priorité à la fois
            _selectedTags.removeWhere((t) => t.isPriority);
          }
          if (tag.isStatus) {
            // Un seul statut à la fois
            _selectedTags.removeWhere((t) => t.isStatus);
          }
          if (selected) {
            _selectedTags.add(tag);
          } else {
            _selectedTags.removeWhere((t) => t.id == tag.id);
          }
        });
      },
      selectedColor: color.withValues(alpha: 0.2),
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
              icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedUserAdd01,
                  color: Color(0xFF007AFF),
                  size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        ..._participants.map(
          (p) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: HugeIcon(
                icon: HugeIcons.strokeRoundedUser,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF9B9A97)
                    : const Color(0xFF787774),
                size: 20),
            title: Text(p.name ?? p.email),
            subtitle: p.name != null ? Text(p.email) : null,
            trailing: IconButton(
              icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  color: Colors.grey,
                  size: 18),
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
      initialValue: _reminderMinutes,
      decoration: InputDecoration(
        labelText: 'Rappel',
        prefixIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedNotification01,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF9B9A97)
                : const Color(0xFF787774),
            size: 18),
        border: const OutlineInputBorder(),
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
      initialValue: _rrule,
      decoration: InputDecoration(
        labelText: 'Récurrence',
        prefixIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedRepeat,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF9B9A97)
                : const Color(0xFF787774),
            size: 18),
        border: const OutlineInputBorder(),
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

    setState(() => _isLoading = true);

    try {
      final tagIds =
          _selectedTags.where((t) => t.id != null).map((t) => t.id!).toList();

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
        calendarId: _source == AppConstants.sourceNotion
            ? (_selectedNotionDbId ?? widget.event?.calendarId)
            : widget.event?.calendarId,
        notionPageId: widget.event?.notionPageId,
        reminderMinutes: _reminderMinutes,
        createdAt: widget.event?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        etag: widget.event?.etag,
      );

      final notifier = ref.read(eventsNotifierProvider.notifier);
      EventModel savedEvent;
      if (event.id == null) {
        // Nouvel événement (création classique OU depuis Saisie Magique)
        final newId = await notifier.createEvent(event);
        savedEvent = event.copyWith(id: newId);
      } else {
        await notifier.updateEvent(event);
        savedEvent = event;
      }

      // Push vers la source distante (best-effort, ne bloque pas la sauvegarde)
      String? pushError;
      try {
        await ref.read(syncNotifierProvider.notifier).pushEvent(savedEvent);
      } catch (e) {
        // Le push sera retenté via la sync_queue au prochain sync
        pushError = e.toString();
        AppLogger.instance.warning('EventForm', 'Push distant échoué (sera retenté) : $e');
      }

      if (mounted) {
        if (pushError != null) {
          UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Sauvegardé localement — sync échouée : $pushError',
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        if (widget.onSaved != null) {
          widget.onSaved!(savedEvent);
        } else {
          Navigator.pop(context, event);
        }
      }
    } catch (e) {
      if (mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
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
}
