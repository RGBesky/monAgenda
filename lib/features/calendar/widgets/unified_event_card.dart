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
class UnifiedEventCard extends StatefulWidget {
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

  @override
  State<UnifiedEventCard> createState() => _UnifiedEventCardState();
}

class _UnifiedEventCardState extends State<UnifiedEventCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    final disableAnimations = WidgetsBinding.instance.disableAnimations;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration:
          disableAnimations ? Duration.zero : const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  EventModel get event => widget.event;
  bool get isCompleted => widget.isCompleted;

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
      final luminance = tagColor.computeLuminance();
      if (luminance > 0.5) {
        // Déjà pastel → alpha très léger pour fond blanc lisible
        return tagColor.withValues(alpha: isDark ? 0.15 : 0.18);
      }
      return isDark
          ? tagColor.withValues(alpha: 0.15)
          : Color.lerp(tagColor, Colors.white, 0.92)!; // Quasi-blanc teinté
    }
    // Sans tag : fond blanc pur
    return isDark ? AppColors.darkSurface : Colors.white;
  }

  // ── Couleur du texte de la carte ──────────────────────────
  Color _textColor(bool isDark) {
    return isDark
        ? AppColors.darkText
        : const Color(0xFF191919); // Noir profond pour max lisibilité
  }

  Color _subColor(bool isDark) {
    return isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF6B6B6B); // Gris Notion secondaire
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _priorityColor();
    final cardBg = _cardBgColor(isDark);
    final textColor = _textColor(isDark);
    final subColor = _subColor(isDark);
    final borderColor = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3), // Radius Notion
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(
                  left: BorderSide(
                      color: priorityColor, width: 4), // Bordure gauche fine
                  top: BorderSide(
                      color: isDark ? borderColor : const Color(0xFFEBEBE9),
                      width: 0.5),
                  right: BorderSide(
                      color: isDark ? borderColor : const Color(0xFFEBEBE9),
                      width: 0.5),
                  bottom: BorderSide(
                      color: isDark ? borderColor : const Color(0xFFEBEBE9),
                      width: 0.5),
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
      ),
    );
  }

  Widget _buildTitleRow(Color textColor, bool isDark) {
    final isTask = event.isTask;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox pour les tâches Notion
        if (isTask && widget.onTaskToggle != null) ...[
          GestureDetector(
            onTap: () => widget.onTaskToggle!(!isCompleted),
            child: Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 8, top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? AppColors.cyanPastel
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                  width: 1.5,
                ),
                color: isCompleted
                    ? AppColors.cyanPastel.withValues(alpha: 0.8)
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
              fontWeight: isDark
                  ? FontWeight.w600
                  : FontWeight.w700, // Plus gras en clair
              color: textColor,
              height: 1.4,
              letterSpacing: -0.1,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: textColor.withValues(alpha: 0.5),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        // Icône source (constrainte pour éviter overflow)
        Flexible(
          flex: 0,
          child: _buildSourceIcon(isDark),
        ),
      ],
    );
  }

  Widget _buildSourceIcon(bool isDark) {
    if (event.isFromNotion) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 100),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SourceLogos.notion(size: 18, isDark: isDark),
            if (widget.notionDbName != null) ...[
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  widget.notionDbName!,
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
        ),
      );
    } else if (event.isFromInfomaniak) {
      return SourceLogos.infomaniak(size: 18);
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
    final chiColor = _stabilizerColor(tagColor);
    return _EventChip(
      label: tag.name,
      bgColor: isDark
          ? chiColor.withValues(alpha: 0.2)
          : chiColor.withValues(alpha: 0.55), // Plus doux, lisible
      textColor: isDark
          ? chiColor
          : const Color(0xFF37352F), // Texte toujours noir Notion
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
      bgColor: isDark
          ? stabilo.withValues(alpha: 0.25)
          : stabilo.withValues(alpha: 0.55),
      textColor: isDark ? stabilo : const Color(0xFF37352F),
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
        borderRadius: BorderRadius.circular(3), // Radius Notion
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
