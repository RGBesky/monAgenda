import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/tag_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/source_logos.dart';

/// La "Unified Event Card" — l'atome de l'application.
///
/// Structure :
/// ┌── 🔴 bordure gauche (priorité) ──────────────────────────┐
/// │  TITRE DE L'ÉVÉNEMENT (Gras 16px)               🔗 source│
/// │                                                          │
/// │  [🏷️ Catégorie]  [🔄 Statut]                            │
/// │  🕒 14:00 – 15:00                                        │
/// └──────────────────────────────────────────────────────────┘
class UnifiedEventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onTaskToggle; // Checkbox tâches Notion
  final bool isCompleted;
  final String? notionDbName; // Nom de la BDD Notion

  const UnifiedEventCard({
    super.key,
    required this.event,
    this.onTap,
    this.onLongPress,
    this.onTaskToggle,
    this.isCompleted = false,
    this.notionDbName,
  });

  // ── Couleur priorité (bordure gauche) ─────────────────────
  /// Utilise la couleur du tag (colorHex) pour être cohérent avec les chips.
  Color _priorityColor() {
    final priorityTag = event.priorityTag;
    if (priorityTag == null) return AppColors.priorityNormalVivid;
    return AppColors.fromHex(priorityTag.colorHex);
  }

  // ── Couleur de fond de la carte (Stabilo ou tag) ──────────
  Color _cardBgColor(bool isDark) {
    final categoryTags = event.categoryTags;
    if (categoryTags.isNotEmpty) {
      final tagColor = AppColors.fromHex(categoryTags.first.colorHex);
      // Si la couleur est déjà "Stabilo-like" (très clair), l'utiliser directement.
      final luminance = tagColor.computeLuminance();
      if (luminance > 0.5)
        return tagColor.withValues(alpha: isDark ? 0.15 : 0.6);
      return isDark
          ? tagColor.withValues(alpha: 0.15)
          : Color.lerp(tagColor, Colors.white, 0.82)!;
    }
    // Sans tag : fond neutre
    return isDark ? AppColors.darkSurface : AppColors.lightSurface;
  }

  // ── Couleur du texte de la carte ──────────────────────────
  Color _textColor(bool isDark) {
    return isDark ? AppColors.darkText : AppColors.lightText;
  }

  Color _subColor(bool isDark) {
    return isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _priorityColor();
    final cardBg = _cardBgColor(isDark);
    final textColor = _textColor(isDark);
    final subColor = _subColor(isDark);
    final borderColor = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(
                left: BorderSide(color: priorityColor, width: 6),
                top: BorderSide(color: borderColor, width: 0.5),
                right: BorderSide(color: borderColor, width: 0.5),
                bottom: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Ligne 1 : Titre + checkbox tâche + source ──
                  _buildTitleRow(textColor, isDark),
                  // ── Ligne 2 : Chips (catégorie + statut) ───────
                  if (event.categoryTags.isNotEmpty || _hasStatus())
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildChipsRow(isDark, subColor),
                    ),
                  // ── Ligne 3 : Heure ────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: _buildTimeRow(subColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(Color textColor, bool isDark) {
    final isTask = event.isTask;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox pour les tâches Notion
        if (isTask && onTaskToggle != null) ...[
          GestureDetector(
            onTap: () => onTaskToggle!(!isCompleted),
            child: Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 8, top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? AppColors.stabiloMint
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                  width: 1.5,
                ),
                color: isCompleted
                    ? AppColors.stabiloMint.withValues(alpha: 0.8)
                    : Colors.transparent,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ),
        ],
        // Titre
        Expanded(
          child: Text(
            event.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 1.3,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: textColor.withValues(alpha: 0.5),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        // Icône source
        _buildSourceIcon(isDark),
      ],
    );
  }

  Widget _buildSourceIcon(bool isDark) {
    if (event.isFromNotion) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SourceLogos.notion(size: 16, isDark: isDark),
          if (notionDbName != null) ...[
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                notionDbName!,
                style: TextStyle(
                  fontSize: 9,
                  color: isDark
                      ? const Color(0xFF9B9A97)
                      : const Color(0xFF37352F).withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    } else if (event.isFromInfomaniak) {
      return SourceLogos.infomaniak(size: 16);
    } else {
      final color = AppColors.sourceIcs.withValues(alpha: 0.8);
      return HugeIcon(
        icon: HugeIcons.strokeRoundedCalendar01,
        color: color,
        size: 16,
      );
    }
  }

  bool _hasStatus() {
    return event.statusTag != null;
  }

  Widget _buildChipsRow(bool isDark, Color subColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              // Chips catégories
              ...event.categoryTags.take(2).map((tag) => ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                    child: _buildCategoryChip(tag, isDark),
                  )),
              // Chip statut
              if (_hasStatus())
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                  child: _buildStatusChipFromTag(event.statusTag!, isDark),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(TagModel tag, bool isDark) {
    final tagColor = AppColors.fromHex(tag.colorHex);
    // Utiliser la couleur Stabilo correspondante si le tag a une couleur vive
    final chiColor = _stabilizerColor(tagColor);
    return _EventChip(
      label: tag.name,
      bgColor: isDark
          ? chiColor.withValues(alpha: 0.2)
          : chiColor.withValues(alpha: 0.9),
      textColor: isDark ? chiColor : AppColors.textOnStabilo(chiColor),
    );
  }

  Color _stabilizerColor(Color c) {
    final luminance = c.computeLuminance();
    if (luminance > 0.4) return c; // Already pastel
    // Map vive → Stabilo
    // Simple hue mapping
    final hsl = HSLColor.fromColor(c);
    return HSLColor.fromAHSL(
      1.0,
      hsl.hue,
      (hsl.saturation * 0.5).clamp(0.2, 0.6),
      (hsl.lightness * 1.6).clamp(0.7, 0.92),
    ).toColor();
  }

  Widget _buildStatusChipFromTag(TagModel tag, bool isDark) {
    final chipColor = AppColors.fromHex(tag.colorHex);
    final stabilo = _stabilizerColor(chipColor);
    return _EventChip(
      label: tag.name,
      bgColor: isDark ? stabilo.withValues(alpha: 0.25) : stabilo,
      textColor: isDark ? stabilo : AppColors.textOnStabilo(stabilo),
    );
  }

  Widget _buildTimeRow(Color subColor) {
    if (event.isAllDay) {
      return Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar01,
            color: subColor,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            'Toute la journée',
            style: TextStyle(
              fontSize: 13,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (event.location != null && event.location!.isNotEmpty) ...[
            const SizedBox(width: 10),
            HugeIcon(
                icon: HugeIcons.strokeRoundedLocation01,
                color: subColor,
                size: 12),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                event.location!,
                style: TextStyle(fontSize: 13, color: subColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    final time = event.isTask
        ? CalendarDateUtils.formatDisplayTime(event.startDate)
        : '${CalendarDateUtils.formatDisplayTime(event.startDate)} – ${CalendarDateUtils.formatDisplayTime(event.endDate)}';

    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedTime01,
          color: subColor,
          size: 12,
        ),
        const SizedBox(width: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 13,
            color: subColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (event.location != null && event.location!.isNotEmpty) ...[
          const SizedBox(width: 10),
          HugeIcon(
              icon: HugeIcons.strokeRoundedLocation01,
              color: subColor,
              size: 12),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              event.location!,
              style: TextStyle(fontSize: 13, color: subColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// Chip interne pour catégorie / statut
class _EventChip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _EventChip({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
