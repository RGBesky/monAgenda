import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/event_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/source_logos.dart';
import '../../../providers/sync_provider.dart';
import '../../../providers/events_provider.dart';
import '../../../services/notion_meeting_service.dart';
import 'event_form_screen.dart';

// ---------------------------------------------------------------------------
// Description parser — sépare texte libre des propriétés enrichies
// ---------------------------------------------------------------------------

class _DescriptionProperty {
  final String emoji;
  final String label;
  final String value;
  const _DescriptionProperty({
    required this.emoji,
    required this.label,
    required this.value,
  });
}

class _ParsedDescription {
  final String cleanText;
  final List<_DescriptionProperty> properties;
  const _ParsedDescription({required this.cleanText, required this.properties});
}

class _PropertyRow {
  final dynamic icon;
  final String? emoji;
  final String label;
  final String value;
  const _PropertyRow({
    this.icon,
    this.emoji,
    required this.label,
    required this.value,
  });
}

// ---------------------------------------------------------------------------
// EventDetailScreen — Notion-like read-only event detail
// ---------------------------------------------------------------------------

class EventDetailScreen extends ConsumerWidget {
  final EventModel event;
  final bool asDialogBody;
  final VoidCallback? onNavigatedToEdit;
  final VoidCallback? onEditInPlace;
  final String? notionDbName;

  const EventDetailScreen({
    super.key,
    required this.event,
    this.asDialogBody = false,
    this.onNavigatedToEdit,
    this.onEditInPlace,
    this.notionDbName,
  });

  // -- Notion design tokens -------------------------------------------------

  static const _notionSecondary = Color(0xFF787774);
  static const _notionSecondaryDark = Color(0xFF7F7F7F);
  static const _notionBorder = Color(0xFFE9E9E7);
  static const _notionBorderDark = Color(0xFF2F2F2F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _getCategoryColor();
    final titleColor = isDark ? Colors.white : const Color(0xFF191919);
    final textColor =
        isDark ? const Color(0xFFCFCFCF) : const Color(0xFF37352F);
    final subColor = isDark ? _notionSecondaryDark : _notionSecondary;
    final borderColor = isDark ? _notionBorderDark : _notionBorder;

    final parsed = _parseDescription(event.description);

    final body = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: asDialogBody ? 28 : 20,
        vertical: asDialogBody ? 24 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Title --------------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 28,
                margin: const EdgeInsets.only(top: 4, right: 14),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: -0.3,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // -- Source + Date -------------------------------------------------
          Row(
            children: [
              _buildSourceBadge(context, isDark, ref),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(width: 1, height: 14, color: borderColor),
              ),
              Expanded(child: _buildDateChip(subColor)),
            ],
          ),

          if (event.statusTag != null) ...[
            const SizedBox(height: 10),
            _buildStatusBadge(isDark),
          ],

          const SizedBox(height: 24),

          // -- Property table -----------------------------------------------
          _buildPropertyTable(
              parsed.properties, subColor, textColor, borderColor),

          // -- Description libre --------------------------------------------
          if (parsed.cleanText.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionLabel('Description', subColor, borderColor),
            const SizedBox(height: 10),
            SelectableText(
              parsed.cleanText,
              style: TextStyle(fontSize: 14, color: textColor, height: 1.65),
            ),
          ],

          // -- Tags ---------------------------------------------------------
          if (event.tags.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionLabel('Tags', subColor, borderColor),
            const SizedBox(height: 10),
            _buildTagsSection(context, isDark),
          ],

          // -- Participants -------------------------------------------------
          if (event.participants.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionLabel(
              'Participants (${event.participants.length})',
              subColor,
              borderColor,
            ),
            const SizedBox(height: 10),
            _buildParticipantsList(context, subColor, textColor),
          ],

          // -- Pièces jointes -----------------------------------------------
          if (event.smartAttachments.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionLabel(
              'Pièces jointes (${event.smartAttachments.length})',
              subColor,
              borderColor,
            ),
            const SizedBox(height: 10),
            _buildAttachmentsList(context, subColor, textColor),
          ],

          const SizedBox(height: 24),

          // -- Actions ------------------------------------------------------
          if (Platform.isLinux || Platform.isMacOS || Platform.isWindows)
            _buildMeetingNoteButton(
                context, ref, isDark, borderColor, textColor),

          if (event.isFromNotion && event.notionPageId != null) ...[
            const SizedBox(height: 10),
            _buildOpenInSourceButton(
              context,
              logo: SourceLogos.notion(size: 18, isDark: isDark),
              label: 'Ouvrir dans Notion',
              url:
                  'https://www.notion.so/${event.notionPageId!.replaceAll('-', '')}',
              isDark: isDark,
              borderColor: borderColor,
              textColor: textColor,
            ),
          ],

          if (event.isFromInfomaniak) ...[
            const SizedBox(height: 10),
            _buildOpenInSourceButton(
              context,
              logo: SourceLogos.infomaniak(size: 18),
              label: 'Ouvrir dans Infomaniak',
              url: 'https://mail.infomaniak.com/',
              isDark: isDark,
              borderColor: borderColor,
              textColor: textColor,
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 10),
          _buildMetadata(subColor),

          // -- Dialog action buttons ----------------------------------------
          if (asDialogBody && !event.isFromIcs) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFEB5757)),
                  label: const Text('Supprimer',
                      style: TextStyle(color: Color(0xFFEB5757), fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
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
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
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
                color: Color(0xFFEB5757),
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

  // =========================================================================
  // DESCRIPTION PARSER
  // =========================================================================

  static _ParsedDescription _parseDescription(String? description) {
    if (description == null || description.trim().isEmpty) {
      return const _ParsedDescription(cleanText: '', properties: []);
    }

    final lines = description.split('\n');
    final freeLines = <String>[];
    final props = <_DescriptionProperty>[];
    final propRegex = RegExp(r'^(📎|📍|🎯|🧰)\s+(.+?)\s*:\s+(.+)$');
    bool hitSeparator = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '---') {
        hitSeparator = true;
        continue;
      }
      if (hitSeparator) continue;

      if (trimmed.isEmpty) {
        freeLines.add('');
        continue;
      }

      final match = propRegex.firstMatch(trimmed);
      if (match != null) {
        props.add(_DescriptionProperty(
          emoji: match.group(1)!,
          label: match.group(2)!,
          value: match.group(3)!,
        ));
      } else {
        freeLines.add(line);
      }
    }

    return _ParsedDescription(
      cleanText: freeLines.join('\n').trim(),
      properties: props,
    );
  }

  // =========================================================================
  // PROPERTY TABLE (Notion-like key/value rows)
  // =========================================================================

  Widget _buildPropertyTable(
    List<_DescriptionProperty> descProps,
    Color labelColor,
    Color valueColor,
    Color borderColor,
  ) {
    final rows = <_PropertyRow>[];

    if (event.location != null && event.location!.isNotEmpty) {
      rows.add(_PropertyRow(
        icon: HugeIcons.strokeRoundedLocation01,
        label: 'Lieu',
        value: event.location!,
      ));
    }

    if (event.reminderMinutes != null) {
      final min = event.reminderMinutes!;
      rows.add(_PropertyRow(
        icon: HugeIcons.strokeRoundedNotification01,
        label: 'Rappel',
        value: min >= 60
            ? '${min ~/ 60}h${min % 60 > 0 ? ' ${min % 60}min' : ''} avant'
            : '$min min avant',
      ));
    }

    if (event.rrule != null) {
      rows.add(_PropertyRow(
        icon: HugeIcons.strokeRoundedRepeat,
        label: 'Récurrence',
        value: _formatRRule(event.rrule!),
      ));
    }

    for (final p in descProps) {
      rows.add(_PropertyRow(emoji: p.emoji, label: p.label, value: p.value));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          final isLast = idx == rows.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: borderColor, width: 0.5),
                    ),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (row.icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 1),
                    child:
                        HugeIcon(icon: row.icon, size: 14, color: labelColor),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(row.emoji ?? '📎',
                        style: const TextStyle(fontSize: 13)),
                  ),
                SizedBox(
                  width: 100,
                  child: Text(
                    row.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    style:
                        TextStyle(fontSize: 13, color: valueColor, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================================================
  // SECTION LABEL
  // =========================================================================

  Widget _buildSectionLabel(String label, Color subColor, Color borderColor) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: subColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: borderColor, height: 1)),
      ],
    );
  }

  // =========================================================================
  // DATE CHIP
  // =========================================================================

  Widget _buildDateChip(Color subColor) {
    String text;
    dynamic icon;

    if (event.isAllDay) {
      icon = HugeIcons.strokeRoundedCalendar01;
      final same = CalendarDateUtils.isSameDay(event.startDate, event.endDate);
      text = same
          ? CalendarDateUtils.formatDisplayDate(event.startDate)
          : '${CalendarDateUtils.formatDisplayDate(event.startDate)} → '
              '${CalendarDateUtils.formatDisplayDate(event.endDate)}';
    } else {
      icon = HugeIcons.strokeRoundedTime01;
      text = '${CalendarDateUtils.formatDisplayDate(event.startDate)}  ·  '
          '${CalendarDateUtils.formatDisplayTime(event.startDate)} – '
          '${CalendarDateUtils.formatDisplayTime(event.endDate)} '
          '(${CalendarDateUtils.formatDuration(event.startDate, event.endDate)})';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 13, color: subColor),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // SOURCE BADGE
  // =========================================================================

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

  // =========================================================================
  // STATUS BADGE
  // =========================================================================

  Widget _buildStatusBadge(bool isDark) {
    final stTag = event.statusTag!;
    final statusColor = AppColors.fromHex(stTag.colorHex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            stTag.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAGS SECTION
  // =========================================================================

  Widget _buildTagsSection(BuildContext context, bool isDark) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: event.tags.map((tag) {
        final rawColor = AppColors.fromHex(tag.colorHex);
        final color = isDark && rawColor.computeLuminance() < 0.3
            ? Color.lerp(rawColor, Colors.white, 0.4)!
            : rawColor;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    tag.name,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '  ${tag.isPriority ? 'Priorité' : 'Catégorie'}',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // =========================================================================
  // PARTICIPANTS LIST
  // =========================================================================

  Widget _buildParticipantsList(
      BuildContext context, Color subColor, Color textColor) {
    return Column(
      children: event.participants
          .map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
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
          )
          .toList(),
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

  // =========================================================================
  // ATTACHMENTS LIST
  // =========================================================================

  Widget _buildAttachmentsList(
      BuildContext context, Color subColor, Color textColor) {
    final urls = event.smartAttachments
        .where((a) => a.startsWith('http://') || a.startsWith('https://'))
        .toList();
    final localFiles = event.smartAttachments
        .where((a) => !a.startsWith('http://') && !a.startsWith('https://'))
        .toList();

    return Column(
      children: [
        ...urls.map((url) {
          final displayName = _extractUrlDisplayName(url);
          final isKDrive = url.contains('kdrive') || url.contains('infomaniak');
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isKDrive ? Icons.cloud_outlined : Icons.link,
                      size: 18,
                      color: const Color(0xFF0098FF),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0098FF),
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF0098FF),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.open_in_new, size: 12, color: subColor),
                  ],
                ),
              ),
            ),
          );
        }),
        ...localFiles.map((path) {
          final fileName = path.split('/').last;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                if (await File(path).exists()) {
                  await OpenFilex.open(path);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fichier introuvable : $fileName'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file_outlined,
                        size: 18, color: subColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: TextStyle(fontSize: 13, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // =========================================================================
  // METADATA FOOTER
  // =========================================================================

  Widget _buildMetadata(Color subColor) {
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

  // =========================================================================
  // ACTION BUTTONS
  // =========================================================================

  Widget _buildOpenInSourceButton(
    BuildContext context, {
    required Widget logo,
    required String label,
    required String url,
    required bool isDark,
    required Color borderColor,
    required Color textColor,
  }) {
    return OutlinedButton(
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 40),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          logo,
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.open_in_new,
              size: 12,
              color: isDark ? Colors.white38 : const Color(0xFF999999)),
        ],
      ),
    );
  }

  Widget _buildMeetingNoteButton(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    Color borderColor,
    Color textColor,
  ) {
    final meetingService = ref.watch(notionMeetingServiceProvider);
    if (meetingService == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _MeetingNoteButton(
        event: event,
        service: meetingService,
        isDark: isDark,
        borderColor: borderColor,
        textColor: textColor,
      ),
    );
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  Color _getCategoryColor() {
    final firstCategory = event.categoryTags.firstOrNull;
    if (firstCategory != null) {
      return AppColors.fromHex(firstCategory.colorHex);
    }
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

  static String _extractUrlDisplayName(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('kdrive') || uri.host.contains('infomaniak')) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        final shareIdx = segments.indexOf('share');
        if (shareIdx >= 0 && shareIdx + 1 < segments.length) {
          final uuid = segments[shareIdx + 1];
          return 'kDrive: ${uuid.length > 8 ? uuid.substring(0, 8) : uuid}…';
        }
        return 'Lien kDrive';
      }
      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last;
        if (last.isNotEmpty && last.contains('.')) return last;
      }
      return uri.host;
    } catch (_) {
      return url.length > 40 ? '${url.substring(0, 40)}…' : url;
    }
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

// ---------------------------------------------------------------------------
// Meeting Note Button (stateful)
// ---------------------------------------------------------------------------

class _MeetingNoteButton extends StatefulWidget {
  final EventModel event;
  final NotionMeetingService service;
  final bool isDark;
  final Color borderColor;
  final Color textColor;

  const _MeetingNoteButton({
    required this.event,
    required this.service,
    required this.isDark,
    required this.borderColor,
    required this.textColor,
  });

  @override
  State<_MeetingNoteButton> createState() => _MeetingNoteButtonState();
}

class _MeetingNoteButtonState extends State<_MeetingNoteButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _openOrCreate,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.note_alt_outlined, size: 16, color: widget.textColor),
      label: Text(
        _loading ? 'Création...' : 'Compte-rendu de réunion',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: widget.textColor,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 40),
        side: BorderSide(color: widget.borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Future<void> _openOrCreate() async {
    setState(() => _loading = true);
    try {
      final url = await widget.service.createOrOpen(widget.event);
      if (mounted) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur Meeting Note : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
