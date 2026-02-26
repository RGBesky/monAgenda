import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../providers/tags_provider.dart';
import '../../../services/weather_service.dart';
import '../../events/screens/event_detail_screen.dart';
import '../../events/screens/event_form_screen.dart';
import '../widgets/unified_event_card.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  final ScrollController _scrollController = ScrollController();
  List<WeatherModel> _forecasts = [];
  bool _loadingWeather = false;

  // Ticker pour mettre à jour "Maintenant"
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadWeather();
    // Met à jour l'heure courante toutes les minutes
    _scheduleNowUpdate();
    // Auto-sync au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Invalide le cache des events pour forcer un rechargement depuis la DB
      ref.invalidate(eventsInRangeProvider);
      // Lance la sync si des credentials sont configurés
      final syncState = ref.read(syncNotifierProvider);
      if (!syncState.isSyncing) {
        ref.read(syncNotifierProvider.notifier).syncAll();
      }
    });
  }

  void _scheduleNowUpdate() {
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        setState(() => _now = DateTime.now());
        _scheduleNowUpdate();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    if (_loadingWeather) return;
    _loadingWeather = true;
    try {
      final settings = ref.read(settingsProvider).valueOrNull;
      final lat = settings?.weatherLatitude ?? 46.2044;
      final lon = settings?.weatherLongitude ?? 6.1432;
      final weatherService = WeatherService();
      weatherService.setLocation(latitude: lat, longitude: lon);
      final forecasts = await weatherService.fetchWeekForecast();
      if (mounted) setState(() => _forecasts = forecasts);
    } catch (_) {}
    _loadingWeather = false;
  }

  WeatherModel? _weatherForDay(DateTime day) {
    return _forecasts.firstWhereOrNull(
      (f) => CalendarDateUtils.isSameDay(f.date, day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsInRangeProvider);
    final syncState = ref.watch(syncNotifierProvider);

    return Scaffold(
      appBar: _buildAppBar(context, syncState),
      body: Column(
        children: [
          // Bandeau de sync en cours
          if (syncState.isSyncing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Synchronisation en cours…',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          // Bandeau d'erreur sync
          if (!syncState.isSyncing && syncState.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    color: Color(0xFFFF3B30),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      syncState.errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF3B30),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(syncNotifierProvider.notifier).syncAll(),
                    child:
                        const Text('Réessayer', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Erreur DB : $e',
                    style: const TextStyle(color: Colors.red)),
              ),
              data: (events) => _buildAgendaList(context, events, syncState),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, SyncState syncState) {
    final now = _now;
    final dayFormatter = DateFormat('EEEE d MMMM', 'fr_FR');
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'To Do',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            _capitalize(dayFormatter.format(now)),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        // Bouton recherche
        IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: Theme.of(context).colorScheme.onSurface,
            size: 22,
          ),
          onPressed: () {},
          tooltip: 'Rechercher',
        ),
        // Bouton sync
        IconButton(
          icon: syncState.isSyncing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 22,
                ),
          onPressed: syncState.isSyncing
              ? null
              : () => ref.read(syncNotifierProvider.notifier).syncAll(),
          tooltip: 'Synchroniser',
        ),
      ],
    );
  }

  Widget _buildAgendaList(
      BuildContext context, List<EventModel> events, SyncState syncState) {
    // Grouper événements par jour et trier
    final grouped = _groupEventsByDay(events);
    if (grouped.isEmpty) {
      return _buildEmptyState(context, syncState, events.length);
    }

    final days = grouped.keys.toList()..sort();

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: days
          .map((day) => _buildDaySliver(context, day, grouped[day]!))
          .expand((s) => s)
          .toList(),
    );
  }

  /// Regroupe les événements par jour sur une fenêtre de 7 jours.
  /// Les événements multi-jours apparaissent sur chaque jour qu'ils couvrent.
  Map<DateTime, List<EventModel>> _groupEventsByDay(List<EventModel> events) {
    final map = <DateTime, List<EventModel>>{};
    final today = CalendarDateUtils.startOfDay(_now);
    final windowEnd = today.add(const Duration(days: 7));

    for (final event in events) {
      if (event.isDeleted) continue;

      final eventStart = CalendarDateUtils.startOfDay(event.startDate);
      final eventEnd = CalendarDateUtils.startOfDay(event.endDate);

      // Clamp to 7-day window
      final displayStart = eventStart.isBefore(today) ? today : eventStart;
      final displayEnd = eventEnd.isBefore(windowEnd)
          ? eventEnd
          : windowEnd.subtract(const Duration(days: 1));

      // Skip events entirely outside the window
      if (displayStart.isAfter(windowEnd) || displayEnd.isBefore(today))
        continue;

      // Add event to each day it spans within the window
      var day = displayStart;
      while (!day.isAfter(displayEnd)) {
        map.putIfAbsent(day, () => []).add(event);
        day = day.add(const Duration(days: 1));
      }
    }
    // Trier chaque jour : toute la journée en premier, puis par heure
    for (final key in map.keys) {
      map[key]!.sort((a, b) {
        if (a.isAllDay && !b.isAllDay) return -1;
        if (!a.isAllDay && b.isAllDay) return 1;
        return a.startDate.compareTo(b.startDate);
      });
    }
    return map;
  }

  List<Widget> _buildDaySliver(
    BuildContext context,
    DateTime day,
    List<EventModel> events,
  ) {
    final weather = _weatherForDay(day);
    final isToday = CalendarDateUtils.isToday(day);
    final isTomorrow =
        CalendarDateUtils.isSameDay(day, _now.add(const Duration(days: 1)));

    return [
      // ── En-tête de jour sticky ──────────────────────────
      SliverPersistentHeader(
        pinned: true,
        delegate: _DayHeaderDelegate(
          day: day,
          weather: weather,
          isToday: isToday,
          isTomorrow: isTomorrow,
        ),
      ),
      // ── Événements du jour ──────────────────────────────
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Insérer l'indicateur "Maintenant" au bon endroit
            if (isToday) {
              final nowIndicatorIndex = _nowIndicatorIndex(events);
              if (index == nowIndicatorIndex) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNowIndicator(context),
                    _buildEventCard(context, events[index]),
                  ],
                );
              }
              // Indicateur en fin de liste si tous les événements sont passés
              if (index == events.length - 1 &&
                  nowIndicatorIndex == events.length) {
                return Column(
                  children: [
                    _buildEventCard(context, events[index]),
                    _buildNowIndicator(context),
                  ],
                );
              }
            }
            return _buildEventCard(context, events[index]);
          },
          childCount: events.length,
        ),
      ),
    ];
  }

  /// Retourne l'index où insérer l'indicateur "Maintenant"
  int _nowIndicatorIndex(List<EventModel> events) {
    for (int i = 0; i < events.length; i++) {
      if (!events[i].isAllDay && events[i].startDate.isAfter(_now)) {
        return i;
      }
    }
    return events.length; // Fin de liste
  }

  Widget _buildNowIndicator(BuildContext context) {
    final timeStr = DateFormat('HH:mm', 'fr_FR').format(_now);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 13),
          // Pastille rouge
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF3B30),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, EventModel event) {
    return UnifiedEventCard(
      event: event,
      isCompleted: event.statusTag?.name.toLowerCase() == 'done' ||
          event.statusTag?.name.toLowerCase() == 'fait' ||
          event.statusTag?.name.toLowerCase() == 'terminé',
      onTaskToggle:
          event.isTask ? (done) => _toggleTaskDone(event, done) : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        ),
      ),
      onLongPress: () => _showQuickActions(context, event),
    );
  }

  Future<void> _toggleTaskDone(EventModel event, bool done) async {
    // Trouver le tag de statut cible
    final allTags = ref.read(tagsNotifierProvider).value ?? [];
    final statusTags = allTags.where((t) => t.isStatus).toList();
    final targetName = done ? 'Fait' : 'À faire';
    final targetTag = statusTags.firstWhere(
      (t) => t.name == targetName,
      orElse: () => statusTags.first,
    );

    // Remplacer le tag de statut dans la liste des tagIds
    final newTagIds = event.tagIds.where((id) {
      final tag = allTags.where((t) => t.id == id).firstOrNull;
      return tag == null || !tag.isStatus;
    }).toList()
      ..add(targetTag.id!);

    final newTags = event.tags.where((t) => !t.isStatus).toList()
      ..add(targetTag);

    final updated = event.copyWith(
      status: targetName,
      tagIds: newTagIds,
      tags: newTags,
      updatedAt: DateTime.now(),
    );
    await ref.read(eventsNotifierProvider.notifier).updateEvent(updated);
  }

  void _showQuickActions(BuildContext context, EventModel event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkText : AppColors.lightText)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventFormScreen(event: event),
                  ),
                );
              },
            ),
            if (!event.isFromIcs)
              ListTile(
                leading: const HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete01,
                  color: Color(0xFFFF3B30),
                  size: 20,
                ),
                title: const Text('Supprimer',
                    style: TextStyle(color: Color(0xFFFF3B30))),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, event);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, EventModel event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer « ${event.title} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (event.id != null) {
                ref
                    .read(eventsNotifierProvider.notifier)
                    .deleteEvent(event.id!);
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, SyncState syncState, int rawCount) {
    final subColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar03,
            color: subColor.withValues(alpha: 0.4),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun événement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: subColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          // Diagnostic : combien d'events bruts sont dans la DB
          if (rawCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '$rawCount événement(s) dans la DB mais aucun dans la plage de dates.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
            )
          else
            Text(
              'Synchronisez vos calendriers\nou créez un événement.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: subColor.withValues(alpha: 0.5)),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: syncState.isSyncing
                ? null
                : () => ref.read(syncNotifierProvider.notifier).syncAll(),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              color: Colors.white,
              size: 16,
            ),
            label:
                Text(syncState.isSyncing ? 'Sync…' : 'Synchroniser maintenant'),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Delegate pour l'en-tête de jour sticky ─────────────────────────────────
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime day;
  final WeatherModel? weather;
  final bool isToday;
  final bool isTomorrow;

  const _DayHeaderDelegate({
    required this.day,
    required this.weather,
    required this.isToday,
    required this.isTomorrow,
  });

  @override
  double get minExtent => isToday || isTomorrow ? 60 : 52;
  @override
  double get maxExtent => isToday || isTomorrow ? 60 : 52;

  String get _dayLabel {
    if (isToday) return "Aujourd'hui";
    if (isTomorrow) return 'Demain';
    // "Mardi 28 Fév"
    final df = DateFormat('EEEE d MMM', 'fr_FR');
    final s = df.format(day);
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Label du jour
              Text(
                _dayLabel,
                style: TextStyle(
                  fontSize: isToday ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  color: isToday
                      ? Theme.of(context).colorScheme.primary
                      : textColor,
                  letterSpacing: -0.3,
                ),
              ),
              // Pastille numéro du jour si aujourd'hui
              if (isToday) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Widget météo
              if (weather != null) ...[
                Text(
                  weather!.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${weather!.temperatureMax.round()}°/${weather!.temperatureMin.round()}°',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: subColor,
                  ),
                ),
              ],
            ],
          ),
          // Divider sous l'en-tête
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate old) =>
      old.day != day ||
      old.isToday != isToday ||
      old.isTomorrow != isTomorrow ||
      old.weather != weather;
}
