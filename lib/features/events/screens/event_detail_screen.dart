import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/event_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/sync_provider.dart';
import 'event_form_screen.dart';

class EventDetailScreen extends ConsumerWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = _getPriorityColor();
    final categoryColor = _getCategoryColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail'),
        actions: [
          if (!event.isFromIcs) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventFormScreen(event: event),
                  ),
                );
              },
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
              tooltip: 'Supprimer',
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête coloré
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: priorityColor, width: 5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      _buildSourceBadge(context),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDateRow(context),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tags
            if (event.tags.isNotEmpty) ...[
              _buildTagsSection(context),
              const SizedBox(height: 16),
            ],

            // Lieu
            if (event.location != null) ...[
              _buildDetailRow(
                context,
                icon: Icons.location_on_outlined,
                text: event.location!,
              ),
              const SizedBox(height: 12),
            ],

            // Description
            if (event.description != null) ...[
              _buildDetailRow(
                context,
                icon: Icons.notes_outlined,
                text: event.description!,
                isMultiline: true,
              ),
              const SizedBox(height: 12),
            ],

            // Participants
            if (event.participants.isNotEmpty) ...[
              _buildParticipantsSection(context),
              const SizedBox(height: 12),
            ],

            // Rappel
            if (event.reminderMinutes != null) ...[
              _buildDetailRow(
                context,
                icon: Icons.notifications_outlined,
                text: 'Rappel ${event.reminderMinutes} minute${event.reminderMinutes! > 1 ? 's' : ''} avant',
              ),
              const SizedBox(height: 12),
            ],

            // Récurrence
            if (event.rrule != null) ...[
              _buildDetailRow(
                context,
                icon: Icons.repeat,
                text: _formatRRule(event.rrule!),
              ),
              const SizedBox(height: 12),
            ],

            // Métadonnées
            const Divider(height: 32),
            _buildMetadata(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    if (event.isAllDay) {
      final same = CalendarDateUtils.isSameDay(event.startDate, event.endDate);
      return Text(
        same
            ? CalendarDateUtils.formatDisplayDate(event.startDate)
            : '${CalendarDateUtils.formatDisplayDate(event.startDate)} → '
                '${CalendarDateUtils.formatDisplayDate(event.endDate)}',
        style: style,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(CalendarDateUtils.formatDisplayDate(event.startDate), style: style),
        Text(
          '${CalendarDateUtils.formatDisplayTime(event.startDate)} – '
          '${CalendarDateUtils.formatDisplayTime(event.endDate)} '
          '(${CalendarDateUtils.formatDuration(event.startDate, event.endDate)})',
          style: style,
        ),
      ],
    );
  }

  Widget _buildSourceBadge(BuildContext context) {
    String label;
    Color color;
    if (event.isFromInfomaniak) {
      label = 'Infomaniak';
      color = const Color(0xFF0D6EFD);
    } else if (event.isFromNotion) {
      label = 'Notion';
      color = Colors.black87;
    } else {
      label = '.ics';
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: event.tags.map((tag) {
        final color = AppColors.fromHex(tag.colorHex);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                tag.name,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (tag.isPriority) ...[
                const SizedBox(width: 4),
                Text(
                  '• ${tag.isPriority ? 'Priorité' : 'Catégorie'}',
                  style: TextStyle(
                    color: color.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String text,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment:
          isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.people_outline,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              '${event.participants.length} participant${event.participants.length > 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...event.participants.map(
          (p) => Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    (p.name?.isNotEmpty == true ? p.name! : p.email)
                        .substring(0, 1)
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.name?.isNotEmpty == true)
                        Text(
                          p.name!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      Text(
                        p.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildParticipantStatusIcon(p.status),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return const Icon(Icons.check_circle_outline,
            size: 16, color: Colors.green);
      case 'declined':
        return const Icon(Icons.cancel_outlined, size: 16, color: Colors.red);
      default:
        return const Icon(Icons.help_outline, size: 16, color: Colors.orange);
    }
  }

  Widget _buildMetadata(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.createdAt != null)
          Text(
            'Créé le ${CalendarDateUtils.formatDisplayDateTime(event.createdAt!)}',
            style: style,
          ),
        if (event.syncedAt != null)
          Text(
            'Synchronisé le ${CalendarDateUtils.formatDisplayDateTime(event.syncedAt!)}',
            style: style,
          ),
      ],
    );
  }

  Color _getPriorityColor() {
    final priority = event.priorityTag;
    if (priority == null) return AppColors.priorityNormal;
    return AppColors.fromHex(priority.colorHex);
  }

  Color _getCategoryColor() {
    final firstCategory = event.categoryTags.firstOrNull;
    if (firstCategory != null) return AppColors.fromHex(firstCategory.colorHex);
    return AppColors.categoryWork;
  }

  String _formatRRule(String rrule) {
    if (rrule.contains('FREQ=DAILY')) return 'Tous les jours';
    if (rrule.contains('FREQ=WEEKLY')) return 'Chaque semaine';
    if (rrule.contains('FREQ=MONTHLY')) return 'Chaque mois';
    if (rrule.contains('FREQ=YEARLY')) return 'Chaque année';
    return 'Récurrent';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'événement ?'),
        content: Text(
          'Supprimer "${event.title}" ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(syncNotifierProvider.notifier).deleteEvent(event);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
