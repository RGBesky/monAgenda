import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/event_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/source_logos.dart';
import '../../../providers/sync_provider.dart';
import 'event_form_screen.dart';

import '../../../providers/events_provider.dart';

class EventDetailScreen extends ConsumerWidget {
  final EventModel event;

  /// Si true, n'affiche pas le Scaffold/AppBar (pour usage dans un Dialog).
  final bool asDialogBody;

  /// Callback appelé quand l'utilisateur navigue vers l'éditeur.
  final VoidCallback? onNavigatedToEdit;

  /// Callback pour éditer l'événement en place (dans la popup), au lieu de
  /// naviguer vers un plein écran.
  final VoidCallback? onEditInPlace;

  /// Nom de la base Notion (affiché dans le badge source).
  final String? notionDbName;

  const EventDetailScreen({
    super.key,
    required this.event,
    this.asDialogBody = false,
    this.onNavigatedToEdit,
    this.onEditInPlace,
    this.notionDbName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _getCategoryColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.pastelBg(accent, isDark: isDark);
    final textColor = AppColors.textOnPastel(accent, isDark: isDark);
    final subColor = textColor.withValues(alpha: 0.7);

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header card ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(color: accent, width: 6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.3,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildSourceBadge(context, isDark, ref),
                  ],
                ),
                const SizedBox(height: 10),
                _buildDateRow(context, subColor),
                if (event.statusTag != null) ...[
                  const SizedBox(height: 10),
                  _buildStatusBadge(context, isDark),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (event.tags.isNotEmpty) ...[
            _buildTagsSection(context),
            const SizedBox(height: 20),
          ],

          if (event.location != null) ...[
            _buildInfoRow(context,
                hugeIcon: HugeIcons.strokeRoundedLocation01,
                label: 'Lieu',
                text: event.location!,
                subColor: subColor,
                textColor: textColor),
            const SizedBox(height: 14),
          ],

          if (event.description != null) ...[
            _buildInfoRow(context,
                hugeIcon: HugeIcons.strokeRoundedNote01,
                label: 'Description',
                text: event.description!,
                subColor: subColor,
                textColor: textColor,
                isMultiline: true),
            const SizedBox(height: 14),
          ],

          if (event.participants.isNotEmpty) ...[
            _buildParticipantsSection(context, subColor, textColor),
            const SizedBox(height: 14),
          ],

          if (event.reminderMinutes != null) ...[
            _buildInfoRow(context,
                hugeIcon: HugeIcons.strokeRoundedNotification01,
                label: 'Rappel',
                text:
                    '${event.reminderMinutes} minute${event.reminderMinutes! > 1 ? 's' : ''} avant',
                subColor: subColor,
                textColor: textColor),
            const SizedBox(height: 14),
          ],

          if (event.rrule != null) ...[
            _buildInfoRow(context,
                hugeIcon: HugeIcons.strokeRoundedRepeat,
                label: 'Récurrence',
                text: _formatRRule(event.rrule!),
                subColor: subColor,
                textColor: textColor),
            const SizedBox(height: 14),
          ],

          Divider(color: Theme.of(context).colorScheme.outline, height: 32),
          _buildMetadata(context, subColor),

          // En mode dialog : boutons d'action en bas
          if (asDialogBody && !event.isFromIcs) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFFFF3B30)),
                  label: const Text('Supprimer',
                      style: TextStyle(color: Color(0xFFFF3B30))),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    if (onEditInPlace != null) {
                      onEditInPlace!();
                    } else {
                      onNavigatedToEdit?.call();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventFormScreen(event: event),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Modifier'),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (asDialogBody) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail'),
        actions: [
          if (!event.isFromIcs) ...[
            IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                color: Theme.of(context).colorScheme.onSurface,
                size: 22,
              ),
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
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete01,
                color: Color(0xFFFF3B30),
                size: 22,
              ),
              onPressed: () => _confirmDelete(context, ref),
              tooltip: 'Supprimer',
            ),
          ],
        ],
      ),
      body: body,
    );
  }

  Widget _buildDateRow(BuildContext context, Color subColor) {
    if (event.isAllDay) {
      final same = CalendarDateUtils.isSameDay(event.startDate, event.endDate);
      return Row(
        children: [
          HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              size: 14,
              color: subColor),
          const SizedBox(width: 6),
          Text(
            same
                ? CalendarDateUtils.formatDisplayDate(event.startDate)
                : '${CalendarDateUtils.formatDisplayDate(event.startDate)} → '
                    '${CalendarDateUtils.formatDisplayDate(event.endDate)}',
            style: TextStyle(
                fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    return Row(
      children: [
        HugeIcon(
            icon: HugeIcons.strokeRoundedTime01, size: 14, color: subColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${CalendarDateUtils.formatDisplayDate(event.startDate)}  ·  '
            '${CalendarDateUtils.formatDisplayTime(event.startDate)} – '
            '${CalendarDateUtils.formatDisplayTime(event.endDate)} '
            '(${CalendarDateUtils.formatDuration(event.startDate, event.endDate)})',
            style: TextStyle(
                fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBadge(BuildContext context, bool isDark, WidgetRef ref) {
    String? dbName = notionDbName;
    if (dbName == null && event.isFromNotion) {
      final dbNames = ref.watch(notionDbNamesMapProvider).value ?? {};
      dbName = dbNames[event.calendarId];
    }
    return SourceLogos.badge(
      source: event.source,
      isDark: isDark,
      subtitle: dbName,
    );
  }

  Widget _buildStatusBadge(BuildContext context, bool isDark) {
    final stTag = event.statusTag!;
    final statusColor = AppColors.fromHex(stTag.colorHex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            stTag.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: event.tags.map((tag) {
        final rawColor = AppColors.fromHex(tag.colorHex);
        // En dark mode, assurer un contraste minimal pour les couleurs sombres
        final color = isDark && rawColor.computeLuminance() < 0.3
            ? Color.lerp(rawColor, Colors.white, 0.4)!
            : rawColor;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                tag.name,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '  ${tag.isPriority ? 'Priorité' : 'Catégorie'}',
                style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required dynamic hugeIcon,
    required String label,
    required String text,
    required Color subColor,
    required Color textColor,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment:
          isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        HugeIcon(icon: hugeIcon, size: 18, color: subColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsSection(
      BuildContext context, Color subColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HugeIcon(
                icon: HugeIcons.strokeRoundedUserGroup,
                size: 18,
                color: subColor),
            const SizedBox(width: 10),
            Text(
              'Participants',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: subColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${event.participants.length})',
              style: TextStyle(fontSize: 11, color: subColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...event.participants.map(
          (p) => Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    (p.name?.isNotEmpty == true ? p.name! : p.email)
                        .substring(0, 1)
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
                        Text(p.name!,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textColor)),
                      Text(p.email,
                          style: TextStyle(fontSize: 12, color: subColor)),
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
        return const HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
            size: 16,
            color: Colors.green);
      case 'declined':
        return const HugeIcon(
            icon: HugeIcons.strokeRoundedCancelCircle,
            size: 16,
            color: Colors.red);
      default:
        return const HugeIcon(
            icon: HugeIcons.strokeRoundedQuestion,
            size: 16,
            color: Colors.orange);
    }
  }

  Widget _buildMetadata(BuildContext context, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.createdAt != null)
          Text(
            'Créé le ${CalendarDateUtils.formatDisplayDateTime(event.createdAt!)}',
            style: TextStyle(fontSize: 11, color: subColor),
          ),
        if (event.syncedAt != null)
          Text(
            'Synchronisé le ${CalendarDateUtils.formatDisplayDateTime(event.syncedAt!)}',
            style: TextStyle(fontSize: 11, color: subColor),
          ),
      ],
    );
  }

  Color _getCategoryColor() {
    final firstCategory = event.categoryTags.firstOrNull;
    if (firstCategory != null) return AppColors.fromHex(firstCategory.colorHex);
    if (event.isFromNotion) return const Color(0xFF5856D6);
    if (event.isFromInfomaniak) return const Color(0xFF0098FF);
    return const Color(0xFF007AFF);
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
