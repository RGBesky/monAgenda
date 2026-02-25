import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/tag_model.dart';
import '../../../core/utils/date_utils.dart';

/// Bloc visuel d'un événement dans le calendrier.
/// Structure :
/// - Bordure gauche colorée = Priorité
/// - Fond = Catégorie principale
/// - Logo coin supérieur droit = Source (Infomaniak / Notion)
class EventBlock extends StatelessWidget {
  final EventModel event;
  final bool isCompact;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const EventBlock({
    super.key,
    required this.event,
    this.isCompact = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    final categoryColor = _getCategoryColor();
    final textColor = _getTextColor(categoryColor);

    if (event.isTask) {
      return _buildTaskBadge(context, categoryColor);
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: categoryColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(
              color: priorityColor,
              width: 4,
            ),
          ),
        ),
        child: isCompact
            ? _buildCompactContent(textColor)
            : _buildFullContent(textColor),
      ),
    );
  }

  Widget _buildCompactContent(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              event.title,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildSourceLogo(),
        ],
      ),
    );
  }

  Widget _buildFullContent(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              _buildSourceLogo(),
            ],
          ),
          if (!event.isAllDay) ...[
            const SizedBox(height: 2),
            Text(
              '${CalendarDateUtils.formatDisplayTime(event.startDate)} – '
              '${CalendarDateUtils.formatDisplayTime(event.endDate)}',
              style: TextStyle(
                color: textColor.withOpacity(0.85),
                fontSize: 10,
              ),
            ),
          ],
          if (event.categoryTags.isNotEmpty) ...[
            const SizedBox(height: 2),
            Wrap(
              spacing: 2,
              children: event.categoryTags
                  .take(2)
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        tag.name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceLogo() {
    if (event.isFromIcs) return const SizedBox.shrink();

    return SizedBox(
      width: AppConstants.sourceLogoSize,
      height: AppConstants.sourceLogoSize,
      child: event.isFromInfomaniak
          ? _buildInfomaniakLogo()
          : _buildNotionLogo(),
    );
  }

  Widget _buildInfomaniakLogo() {
    // Logo Infomaniak : cercle bleu avec "ik"
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'ik',
          style: TextStyle(
            color: Color(0xFF0D6EFD),
            fontSize: 7,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildNotionLogo() {
    // Logo Notion : carré blanc avec "N"
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Center(
        child: Text(
          'N',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskBadge(BuildContext context, Color categoryColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: categoryColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 1,
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor() {
    final priority = event.priorityTag;
    if (priority == null) return AppColors.priorityNormal;
    return AppColors.fromHex(priority.colorHex);
  }

  Color _getCategoryColor() {
    final firstCategory = event.categoryTags.firstOrNull;
    if (firstCategory != null) {
      return AppColors.fromHex(firstCategory.colorHex);
    }
    // Couleur selon la source si pas de catégorie
    if (event.isFromIcs && event.icsSubscriptionId != null) {
      return AppColors.categoryAdmin; // Sera remplacé par la couleur de l'abonnement
    }
    return AppColors.categoryWork;
  }

  Color _getTextColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

/// Barre horizontale pour les événements multi-jours.
class MultiDayEventBar extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const MultiDayEventBar({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    final categoryColor = _getCategoryColor();
    final textColor = categoryColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 22,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: categoryColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(3),
          border: Border(
            left: BorderSide(color: priorityColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.isFromNotion)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Center(
                      child: Text(
                        'N',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor() {
    final priority = event.priorityTag;
    if (priority == null) return AppColors.priorityNormal;
    return AppColors.fromHex(priority.colorHex);
  }

  Color _getCategoryColor() {
    final firstCategory = event.categoryTags.firstOrNull;
    if (firstCategory != null) {
      return AppColors.fromHex(firstCategory.colorHex);
    }
    return AppColors.categoryWork;
  }
}
