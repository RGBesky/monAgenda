import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/notion_database_model.dart';
import '../../../core/models/tag_model.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../services/sync_engine.dart';
import '../../../services/weather_service.dart';
import '../../../services/logger_service.dart';
import '../../events/screens/event_form_screen.dart';
import '../../events/widgets/event_detail_popup.dart';
import '../../project/project_view_screen.dart';
import '../widgets/weather_header.dart';
import '../../../core/widgets/source_logos.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late CalendarController _calendarController;
  final GlobalKey _calendarKey = GlobalKey();
  List<WeatherModel> _forecasts = [];
  bool _loadingWeather = false;
  bool _showTodoPanel = false;
  String? _todoFilterDb; // null = toutes les BDD
  String? _todoFilterStatus; // null = tous les statuts

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
    _loadWeather();
  }

  @override
  void dispose() {
    _calendarController.dispose();
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
    } catch (e) {
      AppLogger.instance.warning('CalendarScreen', 'Weather fetch failed: $e');
    }
    _loadingWeather = false;
  }

  CalendarView _getCalendarView(String settingsView) {
    switch (settingsView) {
      case AppConstants.viewMonth:
        return CalendarView.month;
      case AppConstants.viewDay:
        return CalendarView.day;
      case AppConstants.viewAgenda:
        return CalendarView.schedule;
      default:
        return CalendarView.week;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final eventsAsync = ref.watch(eventsInRangeProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final currentView = settings?.defaultView ?? AppConstants.viewWeek;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    Widget calendarBody = Column(
      children: [
        if (_forecasts.isNotEmpty)
          WeatherHeader(
            forecasts: _forecasts,
            displayedDate: DateTime.now(),
            cityName: settings?.weatherCity ?? 'Genève',
          ),
        Expanded(
          child: eventsAsync.when(
            loading: () => _buildCalendarWithEvents(
              context,
              [],
              currentView,
              settings,
            ),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (events) => _buildCalendarWithEvents(
              context,
              events,
              currentView,
              settings,
            ),
          ),
        ),
      ],
    );

    // Desktop : panneau latéral tâches non planifiées + DragTarget
    if (isDesktop && _showTodoPanel) {
      calendarBody = Row(
        children: [
          Expanded(
            flex: 3,
            child: _wrapWithDragTarget(calendarBody),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 280,
            child: _buildTodoPanel(context),
          ),
        ],
      );
    } else if (isDesktop) {
      calendarBody = _wrapWithDragTarget(calendarBody);
    }

    return Scaffold(
      appBar: _buildAppBar(context, syncState),
      body: calendarBody,
      floatingActionButton: _buildFab(context),
    );
  }

  AppBar _buildAppBar(BuildContext context, SyncState syncState) {
    final now = DateTime.now();
    final dayFormatter = DateFormat('EEEE d MMMM', 'fr_FR');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Calendrier',
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
        // Bouton aujourd'hui
        IconButton(
          onPressed: () {
            _calendarController.displayDate = DateTime.now();
          },
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar04,
            color: Theme.of(context).colorScheme.primary,
            size: 22,
          ),
          tooltip: "Aujourd'hui",
        ),
        // Panneau tâches non planifiées (desktop only)
        if (MediaQuery.of(context).size.width >= 800)
          IconButton(
            onPressed: () => setState(() => _showTodoPanel = !_showTodoPanel),
            icon: HugeIcon(
              icon: _showTodoPanel
                  ? HugeIcons.strokeRoundedRightToLeftListBullet
                  : HugeIcons.strokeRoundedTaskDaily02,
              color: _showTodoPanel
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              size: 22,
            ),
            tooltip: 'Tâches à planifier',
          ),
        // Filtre des bases Notion
        _buildFilterButton(context),
        // Sélecteur de vue
        PopupMenuButton<String>(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedDashboardSquare01,
            color: Theme.of(context).colorScheme.onSurface,
            size: 22,
          ),
          onSelected: (view) {
            _calendarController.view = _getCalendarView(view);
            ref.read(settingsProvider.notifier).setDefaultView(view);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: AppConstants.viewMonth,
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar01,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Mois',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            PopupMenuItem(
              value: AppConstants.viewWeek,
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Semaine',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            PopupMenuItem(
              value: AppConstants.viewDay,
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar02,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Jour',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            PopupMenuItem(
              value: AppConstants.viewAgenda,
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedMenu01,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Agenda',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        // Bouton sync
        IconButton(
          icon: syncState.isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 22,
                ),
          onPressed: syncState.isSyncing
              ? null
              : () async {
                  await ref.read(syncNotifierProvider.notifier).syncAll();
                  if (!context.mounted) return;
                  final state = ref.read(syncNotifierProvider);
                  if (state.sourceErrors.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Erreurs de sync :\n${state.sourceErrors.entries.map((e) => '• ${e.key}: ${e.value}').join('\n')}',
                        ),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 6),
                      ),
                    );
                  } else if (state.lastResult == SyncResult.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Synchronisation réussie'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
          tooltip: 'Synchroniser',
        ),
      ],
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    final notionDbsAsync = ref.watch(notionDatabasesProvider);
    final hidden = ref.watch(hiddenSourcesProvider);

    return notionDbsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (dbs) {
        if (dbs.isEmpty) return const SizedBox.shrink();
        final hasHidden = hidden.isNotEmpty;
        return IconButton(
          icon: HugeIcon(
            icon: hasHidden
                ? HugeIcons.strokeRoundedFilterHorizontal
                : HugeIcons.strokeRoundedFilter,
            color: hasHidden
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
            size: 22,
          ),
          tooltip: 'Filtrer les calendriers',
          onPressed: () => _showFilterPanel(context, dbs, hidden),
        );
      },
    );
  }

  void _showFilterPanel(
    BuildContext context,
    List<NotionDatabaseModel> dbs,
    Set<String> hidden,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedFilter,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text('Calendriers'),
                ],
              ),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Infomaniak (toujours visible, non masquable) ──
                    _buildSourceRow(
                      logo: SourceLogos.infomaniak(size: 20),
                      icon: HugeIcons.strokeRoundedCloud,
                      color: AppColors.sourceInfomaniak,
                      label: 'Infomaniak',
                      isVisible: true,
                      enabled: false,
                      onChanged: null,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 4),
                    // ── Notion databases ──
                    ...dbs.map((db) {
                      final sourceId = db.effectiveSourceId;
                      final isVisible = !hidden.contains(sourceId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _buildSourceRow(
                          logo: SourceLogos.notion(size: 20, isDark: isDark),
                          icon: HugeIcons.strokeRoundedDatabase,
                          color: AppColors.sourceNotion,
                          label: db.name,
                          isVisible: isVisible,
                          enabled: true,
                          onChanged: (visible) {
                            final newHidden = Set<String>.from(
                                ref.read(hiddenSourcesProvider));
                            if (visible) {
                              newHidden.remove(sourceId);
                            } else {
                              newHidden.add(sourceId);
                            }
                            ref.read(hiddenSourcesProvider.notifier).state =
                                newHidden;
                            setDialogState(() {});
                          },
                          isDark: isDark,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                if (hidden.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(hiddenSourcesProvider.notifier).state = {};
                      setDialogState(() {});
                    },
                    child: const Text('Tout afficher'),
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSourceRow({
    required List<List<dynamic>> icon,
    required Color color,
    required String label,
    required bool isVisible,
    required bool enabled,
    required ValueChanged<bool>? onChanged,
    required bool isDark,
    Widget? logo,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap:
            enabled && onChanged != null ? () => onChanged(!isVisible) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isVisible ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color,
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (logo != null)
                SizedBox(width: 18, height: 18, child: logo)
              else
                HugeIcon(icon: icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isVisible
                        ? (isDark ? AppColors.darkText : AppColors.lightText)
                        : (isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary),
                    decoration: isVisible ? null : TextDecoration.lineThrough,
                  ),
                ),
              ),
              Switch(
                value: isVisible,
                onChanged: enabled ? onChanged : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarWithEvents(
    BuildContext context,
    List<EventModel> events,
    String currentView,
    AppSettings? settings,
  ) {
    // Appliquer le tri secondaire par calendrier (comme dans l'agenda)
    final sortMode = settings?.eventSortMode ?? AppConstants.sortChronological;
    final calendarOrder = settings?.calendarOrder ?? [];
    final sorted = List<EventModel>.from(events);
    sorted.sort((a, b) {
      // All-day en premier (incl. évènements > 23 h)
      final aAllDay =
          a.isAllDay || a.endDate.difference(a.startDate).inHours > 23;
      final bAllDay =
          b.isAllDay || b.endDate.difference(b.startDate).inHours > 23;
      if (aAllDay && !bAllDay) return -1;
      if (!aAllDay && bAllDay) return 1;
      // Si tri par calendrier : calendrier d'abord
      if (sortMode == AppConstants.sortByCalendar) {
        final calDiff =
            _calendarIndex(a, calendarOrder) - _calendarIndex(b, calendarOrder);
        if (calDiff != 0) return calDiff;
      }
      // Puis chronologique
      return a.startDate.compareTo(b.startDate);
    });
    // On passe useSortOffset pour que SfCalendar respecte notre ordre :
    // il re-trie par getStartTime(), donc on injecte un micro-décalage.
    final dataSource = _CalendarDataSource(
      sorted,
      useSortOffset: sortMode == AppConstants.sortByCalendar,
    );
    final firstDayOfWeek =
        settings?.firstDayOfWeek == AppConstants.firstDaySunday
            ? DateTime.sunday
            : DateTime.monday; // DateTime.monday = 1, DateTime.sunday = 7

    final isScheduleView = currentView == AppConstants.viewAgenda;
    final calendar = SfCalendar(
      key: _calendarKey,
      controller: _calendarController,
      view: _getCalendarView(currentView),
      dataSource: dataSource,
      firstDayOfWeek: firstDayOfWeek,
      showNavigationArrow: true,
      showDatePickerButton: true,
      showTodayButton: true,
      todayHighlightColor: Theme.of(context).colorScheme.primary,
      cellBorderColor: Theme.of(context).colorScheme.outlineVariant,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      viewHeaderStyle: ViewHeaderStyle(
        dayTextStyle: TextStyle(
          fontSize: 11, // Tiny: 11px (Design System)
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        dateTextStyle: TextStyle(
          fontSize: 15, // Body: 15px (Design System)
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      headerStyle: CalendarHeaderStyle(
        textAlign: TextAlign.start,
        textStyle: TextStyle(
          fontSize: 18, // H2: 18px SemiBold (Design System)
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      timeSlotViewSettings: TimeSlotViewSettings(
        startHour: 6,
        endHour: 23,
        timeInterval: const Duration(minutes: 30),
        timeIntervalHeight: 60,
        timelineAppointmentHeight: 88,
        minimumAppointmentDuration: const Duration(minutes: 30),
        timeFormat: 'HH:mm',
        timeTextStyle: TextStyle(
          fontSize: 11, // Tiny: 11px (Design System)
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        timeRulerSize: 52,
      ),
      monthCellBuilder: _buildMonthCell,
      monthViewSettings: MonthViewSettings(
        appointmentDisplayMode: MonthAppointmentDisplayMode.none,
        showAgenda: true,
        agendaItemHeight: 88,
        numberOfWeeksInView: 6,
        appointmentDisplayCount: 4,
        monthCellStyle: MonthCellStyle(
          textStyle: TextStyle(
            fontSize: 13, // Caption: 13px (Design System)
            color: Theme.of(context).colorScheme.onSurface,
          ),
          trailingDatesTextStyle: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          leadingDatesTextStyle: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        agendaStyle: AgendaStyle(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appointmentTextStyle: TextStyle(
            fontSize: 15, // Body: 15px (Design System)
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          dateTextStyle: TextStyle(
            fontSize: 13, // Caption: 13px (Design System)
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          dayTextStyle: TextStyle(
            fontSize: 24, // Display: 24px Bold (Design System)
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      scheduleViewSettings: ScheduleViewSettings(
        hideEmptyScheduleWeek: true,
        appointmentItemHeight: 88,
        dayHeaderSettings: DayHeaderSettings(
          dayFormat: 'EEE',
          width: 56,
          dayTextStyle: TextStyle(
            fontSize: 13, // Caption: 13px (Design System)
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          dateTextStyle: TextStyle(
            fontSize: 24, // Display: 24px Bold (Design System)
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        weekHeaderSettings: WeekHeaderSettings(
          startDateFormat: 'd MMM',
          endDateFormat: 'd MMM yyyy',
          height: 40,
          textAlign: TextAlign.start,
          weekTextStyle: TextStyle(
            fontSize: 13, // Caption: 13px (Design System)
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        monthHeaderSettings: MonthHeaderSettings(
          monthFormat: 'MMMM yyyy',
          height: 56,
          textAlign: TextAlign.start,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          monthTextStyle: TextStyle(
            fontSize: 18, // H2: 18px SemiBold (Design System)
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      appointmentBuilder: _buildAppointment,
      allowDragAndDrop: true,
      allowAppointmentResize: true,
      dragAndDropSettings: DragAndDropSettings(
        allowNavigation: true,
        allowScroll: true,
        showTimeIndicator: true,
        indicatorTimeFormat: 'HH:mm',
        autoNavigateDelay: const Duration(milliseconds: 600),
        timeIndicatorStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      onDragEnd: _onDragEnd,
      onAppointmentResizeEnd: _onAppointmentResizeEnd,
      onTap: _onCalendarTap,
      onLongPress: _onCalendarLongPress,
      onViewChanged: (details) {
        if (details.visibleDates.isEmpty) return;
        final start = details.visibleDates.first;
        final end = details.visibleDates.last;
        Future(() {
          if (!mounted) return;
          final newRange = DateRange(
            start: start.subtract(const Duration(days: 7)),
            end: end.add(const Duration(days: 7)),
          );
          // Guard : ne pas muter si même plage → évite boucle infinie
          // (StateProvider notifie même si valeur ==)
          final current = ref.read(displayedDateRangeProvider);
          if (current == newRange) return;
          ref.read(displayedDateRangeProvider.notifier).state = newRange;
        });
      },
    );

    // ── Empty state overlay ──
    if (events.isEmpty) {
      if (isScheduleView) {
        // Schedule view vide = écran blanc → empty state plein écran
        return _buildCalendarEmptyState(context);
      }
      // Week/month/day : grille visible + bandeau subtil
      return Stack(
        children: [
          calendar,
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCalendarRemove02,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.6),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Aucun événement visible',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return calendar;
  }

  /// Empty state complet pour la vue planning (schedule) vide.
  Widget _buildCalendarEmptyState(BuildContext context) {
    final subColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar03,
            color: subColor.withValues(alpha: 0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun événement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: subColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Synchronisez vos calendriers\nou créez un événement.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: subColor.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Month cell builder : numéro du jour + icônes colorées des événements ──
  Widget _buildMonthCell(BuildContext context, MonthCellDetails details) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isToday = DateUtils.isSameDay(details.date, DateTime.now());
    final isCurrentMonth = details.visibleDates.length > 15 &&
        details.date.month == details.visibleDates[15].month;
    final textColor = isCurrentMonth
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.3),
          width: 0.5,
        ),
        color: isToday
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.25)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 2),
          // Numéro du jour
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  )
                : null,
            child: Text(
              '${details.date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday
                    ? Theme.of(context).colorScheme.onPrimary
                    : textColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Icônes des événements (max 4)
          if (details.appointments.isNotEmpty)
            Expanded(
              child: Wrap(
                spacing: 2,
                runSpacing: 1,
                alignment: WrapAlignment.center,
                children: details.appointments.take(4).map<Widget>((apt) {
                  if (apt is EventModel) {
                    final event = apt;
                    final color = _getCategoryColor(event);
                    // Vrais logos source en vue mois (13px)
                    if (event.isFromNotion) {
                      return SourceLogos.notion(size: 14, isDark: isDark);
                    } else if (event.isFromInfomaniak) {
                      return SourceLogos.infomaniak(size: 14);
                    }
                    // Fallback : dot coloré catégorie pour .ics
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark ? color.withValues(alpha: 0.9) : color,
                        shape: BoxShape.circle,
                      ),
                    );
                  }
                  // Fallback pour Appointment brut
                  return Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            ),
          // Indicateur "+N" si plus de 4 événements
          if (details.appointments.length > 4)
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(
                '+${details.appointments.length - 4}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppointment(
    BuildContext context,
    CalendarAppointmentDetails details,
  ) {
    final event = details.appointments.first as EventModel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h = details.bounds.height;
    final w = details.bounds.width;

    // ── Couleurs conformes au Design System ──
    // Effet "surlignage au feutre Stabilo" : fond neutre, bordure tout
    // autour en couleur catégorie semi-transparente (comme un surligneur
    // sur du papier). Épaisseur 2.5px, coins arrondis, fond blanc/surface.
    final accent = _getCategoryColor(event);
    // Fond neutre — le surligneur est sur la BORDURE, pas sur le fond
    final bg = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : Colors.white;
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF191919);
    final subColor =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF6B6B6B);

    // Bordure surligneur : couleur catégorie avec transparence feutre
    final highlighterColor = isDark
        ? accent.withValues(alpha: 0.55)
        : accent.withValues(alpha: 0.45);
    // Épaisseur "trait de feutre" : 2.5px standard, 2px pour les tiny
    final borderW = h < 22 ? 2.0 : 2.5;
    final contentW = w - borderW * 2;

    final radius = h < 16 ? 3.0 : (h < 28 ? 5.0 : 8.0);

    // Padding vertical = 2 px (sauf tiny = 1 px)
    final vPad = h < 22 ? 1.0 : 2.0;
    // Hauteur utile réellement disponible pour le contenu
    final usableH = h - vPad * 2 - borderW * 2;

    return SizedBox(
      height: h,
      width: w,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          // Bordure surligneur TOUT AUTOUR — effet "encadré au Stabilo"
          border: Border.all(color: highlighterColor, width: borderW),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: contentW > 30 ? 6 : 3,
          vertical: vPad,
        ),
        // SingleChildScrollView absorbe le surplus vertical
        // (pas de yellow overflow stripe) ; NeverScrollable empêche
        // le scroll utilisateur. La largeur reste contrainte → pas
        // de débordement horizontal.
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: _buildAppointmentContent(
              event, titleColor, subColor, usableH, contentW, isDark),
        ),
      ),
    );
  }

  /// Petit dot coloré pour la catégorie (layout compact all-day)
  Widget _compactCategoryDot(EventModel event, bool isDark) {
    final cat = event.categoryTags.first;
    final color = AppColors.fromHex(cat.colorHex);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  /// Petit dot coloré pour le statut (layout compact all-day)
  Widget _compactStatusDot(EventModel event, bool isDark) {
    final color = AppColors.fromHex(event.statusTag!.colorHex);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildAppointmentContent(
    EventModel event,
    Color titleColor,
    Color subColor,
    double h,
    double w,
    bool isDark,
  ) {
    // Info multi-jours
    final multiDayInfo = _multiDayInfo(event);

    // ── All-day / multi-day events dans le panneau all-day ──
    // SfCalendar reporte h = hauteur totale du jour (ex: 1192px)
    // mais n'affiche qu'une bande de ~25px dans le panneau all-day.
    // → Forcer le layout compact single-line pour ces événements.
    final isEffectiveAllDay = event.isAllDay ||
        event.endDate.difference(event.startDate).inHours > 23;
    if (isEffectiveAllDay) {
      return Row(
        children: [
          Expanded(
            child: Text(
              multiDayInfo != null
                  ? '${event.title} $multiDayInfo'
                  : event.title,
              style: TextStyle(
                color: titleColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          _sourceIcon(event, isDark, 14),
          if (event.categoryTags.isNotEmpty) ...[
            const SizedBox(width: 4),
            _compactCategoryDot(event, isDark),
          ],
          if (event.statusTag != null) ...[
            const SizedBox(width: 4),
            _compactStatusDot(event, isDark),
          ],
        ],
      );
    }

    // ── Tiny (< 18px) : titre seul, texte minimal ──
    if (h < 18) {
      return Text(
        multiDayInfo != null ? '${event.title} $multiDayInfo' : event.title,
        style: TextStyle(
          color: titleColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // ── Compact single-line (< 28px) : titre + source icon + heure ──
    if (h < 28) {
      return Row(
        children: [
          Expanded(
            child: Text(
              multiDayInfo != null
                  ? '${event.title} $multiDayInfo'
                  : event.title,
              style: TextStyle(
                color: titleColor,
                fontSize: h < 22 ? 11 : 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          _sourceIcon(event, isDark, 14),
          if (!event.isAllDay && w > 100) ...[
            const SizedBox(width: 4),
            Text(
              CalendarDateUtils.formatDisplayTime(event.startDate),
              style: TextStyle(
                color: subColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      );
    }

    // ── Medium (< 44px) : titre + source, en dessous meta compacte ──
    // SfCalendar all-day = 40px → doit rester dans ce tier
    if (h < 44) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne 1 : Titre + source icon
          Row(
            children: [
              Expanded(
                child: Text(
                  multiDayInfo != null
                      ? '${event.title} $multiDayInfo'
                      : event.title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              _sourceIcon(event, isDark, 14),
            ],
          ),
          const SizedBox(height: 1),
          // Ligne 2 : mini meta (heure + catégorie, pas de source chip)
          _metaRowCompact(event, subColor, isDark, multiDayInfo),
        ],
      );
    }

    // ── Normal (< 66px) : titre + source + meta chips ──
    if (h < 66) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne 1 : Titre + source icon
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              _sourceIcon(event, isDark, 14),
            ],
          ),
          const SizedBox(height: 2),
          // Ligne 2 : heure + chips catégorie
          Flexible(
              child: _metaRow(event, subColor, isDark,
                  multiDayInfo: multiDayInfo)),
        ],
      );
    }

    // ── Grand (>= 66px) : titre + source + chips + heure ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ligne 1 : Titre + source icon
        Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -0.1,
                ),
                maxLines: h > 80 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _sourceIcon(event, isDark, 16),
          ],
        ),
        // Ligne 2 : Chips catégorie + statut
        if (h >= 76 &&
            (event.categoryTags.isNotEmpty || event.statusTag != null)) ...[
          const SizedBox(height: 4),
          _chipRow(event, isDark),
        ],
        // Ligne 3 : Heure (sans re-afficher catégories/statut déjà dans _chipRow)
        const SizedBox(height: 3),
        Flexible(
            child: _metaRow(event, subColor, isDark,
                multiDayInfo: multiDayInfo, skipCategoryAndStatus: h >= 76)),
      ],
    );
  }

  /// Icône source (Design System §4.1 : toujours visible, vrais logos PNG)
  Widget _sourceIcon(EventModel event, bool isDark, double size) {
    if (event.isFromNotion) {
      return SourceLogos.notion(size: size, isDark: isDark);
    } else if (event.isFromInfomaniak) {
      return SourceLogos.infomaniak(size: size);
    } else {
      final color = AppColors.sourceIcs.withValues(alpha: 0.8);
      return HugeIcon(
        icon: HugeIcons.strokeRoundedCalendar01,
        color: color,
        size: size,
      );
    }
  }

  /// Chips catégorie + statut (Design System §4.1)
  Widget _chipRow(EventModel event, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              // Catégorie chips
              ...event.categoryTags.take(2).map((tag) {
                final tagColor = AppColors.fromHex(tag.colorHex);
                final hsl = HSLColor.fromColor(tagColor);
                final stabilo = hsl.lightness > 0.4
                    ? tagColor
                    : HSLColor.fromAHSL(1.0, hsl.hue,
                            (hsl.saturation * 0.5).clamp(0.2, 0.6), 0.85)
                        .toColor();
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? stabilo.withValues(alpha: 0.2)
                          : stabilo.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      tag.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? stabilo : AppColors.textOnStabilo(stabilo),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }),
              // Statut chip
              if (event.statusTag != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.fromHex(event.statusTag!.colorHex)
                          .withValues(alpha: isDark ? 0.2 : 0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      event.statusTag!.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.fromHex(event.statusTag!.colorHex)
                            : AppColors.textOnStabilo(
                                AppColors.fromHex(event.statusTag!.colorHex)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Retourne "J3/40" pour un événement multi-jours, null sinon.
  String? _multiDayInfo(EventModel event) {
    final days = event.endDate.difference(event.startDate).inDays;
    if (days < 2) return null;
    final today = DateTime.now();
    final dayNum = today
            .difference(DateTime(event.startDate.year, event.startDate.month,
                event.startDate.day))
            .inDays +
        1;
    if (dayNum < 1 || dayNum > days) return null;
    return 'J$dayNum/$days';
  }

  /// Mappe un nom de catégorie à une icône HugeIcons stylée.
  static List<List<dynamic>> _tagNameToIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('travail') ||
        n.contains('work') ||
        n.contains('bureau') ||
        n.contains('boulot')) {
      return HugeIcons.strokeRoundedBriefcase01;
    }
    if (n.contains('perso') || n.contains('personal')) {
      return HugeIcons.strokeRoundedUser;
    }
    if (n.contains('santé') ||
        n.contains('sante') ||
        n.contains('health') ||
        n.contains('médecin') ||
        n.contains('medecin')) {
      return HugeIcons.strokeRoundedStethoscope;
    }
    if (n.contains('famille') || n.contains('family')) {
      return HugeIcons.strokeRoundedHome01;
    }
    if (n.contains('sport') || n.contains('fitness') || n.contains('gym')) {
      return HugeIcons.strokeRoundedDumbbell01;
    }
    if (n.contains('social') || n.contains('amis') || n.contains('friend')) {
      return HugeIcons.strokeRoundedUserGroup;
    }
    if (n.contains('formation') ||
        n.contains('étude') ||
        n.contains('etude') ||
        n.contains('school') ||
        n.contains('cours')) {
      return HugeIcons.strokeRoundedUniversity;
    }
    if (n.contains('admin') || n.contains('papier') || n.contains('impôt')) {
      return HugeIcons.strokeRoundedFileValidation;
    }
    if (n.contains('réunion') ||
        n.contains('reunion') ||
        n.contains('meeting')) {
      return HugeIcons.strokeRoundedPresentation01;
    }
    if (n.contains('voyage') || n.contains('travel') || n.contains('vacance')) {
      return HugeIcons.strokeRoundedAirplane01;
    }
    if (n.contains('course') || n.contains('shopping')) {
      return HugeIcons.strokeRoundedShoppingCart01;
    }
    if (n.contains('loisir') || n.contains('hobby')) {
      return HugeIcons.strokeRoundedGameController01;
    }
    if (n.contains('anniv') || n.contains('birth')) {
      return HugeIcons.strokeRoundedBirthdayCake;
    }
    if (n.contains('projet') || n.contains('project')) {
      return HugeIcons.strokeRoundedRocket01;
    }
    if (n.contains('repas') ||
        n.contains('restaurant') ||
        n.contains('dîner') ||
        n.contains('déjeuner')) {
      return HugeIcons.strokeRoundedRestaurant01;
    }
    if (n.contains('musique') || n.contains('music') || n.contains('concert')) {
      return HugeIcons.strokeRoundedMusicNote01;
    }
    if (n.contains('carême') ||
        n.contains('careme') ||
        n.contains('église') ||
        n.contains('prière')) {
      return HugeIcons.strokeRoundedSparkles;
    }
    return HugeIcons.strokeRoundedTag01;
  }

  // ── Ligne méta compacte (pour barre all-day ~30px) : heure + 1 catégorie + statut ──
  Widget _metaRowCompact(
    EventModel event,
    Color fallbackColor,
    bool isDark, [
    String? multiDayInfo,
  ]) {
    final items = <Widget>[];

    if (multiDayInfo != null) {
      items.add(Text(
        multiDayInfo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fallbackColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ));
    }

    if (!event.isAllDay) {
      items.add(Text(
        CalendarDateUtils.formatDisplayTime(event.startDate),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fallbackColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ));
    }

    final cat = event.categoryTags.firstOrNull;
    if (cat != null) {
      items.add(Text(
        cat.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.fromHex(cat.colorHex),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ));
    }

    if (event.statusTag != null) {
      items.add(Text(
        event.statusTag!.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.fromHex(event.statusTag!.colorHex),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return ClipRect(
      child: Row(
        children: items
            .expand((w) => [Flexible(child: w), const SizedBox(width: 6)])
            .toList()
          ..removeLast(),
      ),
    );
  }

  // ── Ligne méta : heure + tag chips + multi-day info ──────────────
  Widget _metaRow(EventModel event, Color fallbackColor, bool isDark,
      {String? multiDayInfo, bool skipCategoryAndStatus = false}) {
    final items = <Widget>[];

    // Multi-day badge — petit chip coloré "J3/40"
    if (multiDayInfo != null) {
      items.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: fallbackColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          multiDayInfo,
          style: TextStyle(
            color: fallbackColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ));
    }

    // Heure — icône horloge + texte (pas de chip, juste inline)
    if (!event.isAllDay) {
      items.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedClock01,
            color: fallbackColor,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            CalendarDateUtils.formatDisplayTime(event.startDate),
            style: TextStyle(
              color: fallbackColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ));
    }

    // Catégorie(s) — chips fond blanc, texte coloré (sauf si déjà dans _chipRow)
    if (!skipCategoryAndStatus) {
      for (final cat in event.categoryTags.take(2)) {
        final catColor = AppColors.fromHex(cat.colorHex);
        items.add(_tagChip(
          icon: _tagNameToIcon(cat.name),
          text: cat.name,
          color: catColor,
          isDark: isDark,
        ));
      }
    }

    // Priorité — chip avec nom + couleur (seulement si non "Normale")
    if (!skipCategoryAndStatus) {
      final pri = event.priorityTag;
      if (pri != null) {
        final pn = pri.name.toLowerCase();
        if (!pn.contains('normale') && !pn.contains('normal')) {
          final priColor = AppColors.fromHex(pri.colorHex);
          items.add(_tagChip(
            icon: HugeIcons.strokeRoundedAlert02,
            text: pri.name,
            color: priColor,
            isDark: isDark,
          ));
        }
      }
    }

    // Status d'avancement — chip dans le même Wrap
    if (!skipCategoryAndStatus && event.statusTag != null) {
      final stTag = event.statusTag!;
      final statusColor = AppColors.fromHex(stTag.colorHex);
      items.add(_tagChip(
        icon: _statusIconFromTag(stTag),
        text: stTag.name,
        color: statusColor,
        isDark: isDark,
      ));
    }

    // Source — chip Infomaniak / Notion avec couleur officielle
    if (event.isFromInfomaniak) {
      items.add(_tagChip(
        icon: HugeIcons.strokeRoundedCloud,
        text: 'Infomaniak',
        color: AppColors.sourceInfomaniak,
        isDark: isDark,
      ));
    } else if (event.isFromNotion) {
      items.add(_tagChip(
        icon: HugeIcons.strokeRoundedDatabase,
        text: 'Notion',
        color: isDark ? Colors.white : AppColors.sourceNotion,
        isDark: isDark,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Wrap(
            spacing: 5,
            runSpacing: 2,
            children: items
                .map((item) => ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth),
                      child: item,
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  /// Icône de status à partir d'un TagModel
  static List<List<dynamic>> _statusIconFromTag(TagModel tag) {
    final s = tag.name.toLowerCase();
    if (s.contains('fait') || s.contains('terminé') || s.contains('done')) {
      return HugeIcons.strokeRoundedCheckmarkCircle01;
    }
    if (s.contains('cours') || s.contains('progress')) {
      return HugeIcons.strokeRoundedLoading03;
    }
    if (s.contains('faire') || s.contains('todo')) {
      return HugeIcons.strokeRoundedStopCircle;
    }
    if (s.contains('annulé') || s.contains('cancel')) {
      return HugeIcons.strokeRoundedCancelCircle;
    }
    return HugeIcons.strokeRoundedStopCircle;
  }

  /// Chip universel : fond blanc semi-transparent, icône + texte coloré
  Widget _tagChip({
    required List<List<dynamic>> icon,
    required String text,
    required Color color,
    required bool isDark,
  }) {
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.88);
    final borderColor = color.withValues(alpha: isDark ? 0.35 : 0.25);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: color, size: 11),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tri secondaire par calendrier source ──────────────────────
  /// Index de tri d'un événement dans l'ordre des calendriers configuré.
  static int _calendarIndex(EventModel event, List<String> order) {
    if (order.isNotEmpty) {
      if (event.source == AppConstants.sourceInfomaniak) {
        final idx = order.indexOf('infomaniak:');
        if (idx != -1) return idx;
      }
      if (event.source == AppConstants.sourceNotion) {
        final cid = event.calendarId ?? '';
        if (cid.isNotEmpty) {
          final idx = order.indexOf('notion:$cid');
          if (idx != -1) return idx;
        }
        final notionEntries = order.where((k) => k.startsWith('notion:'));
        if (notionEntries.length == 1) {
          return order.indexOf(notionEntries.first);
        }
      }
      if (event.source == AppConstants.sourceIcs) {
        final subId = event.icsSubscriptionId ?? '';
        if (subId.isNotEmpty) {
          final idx = order.indexOf('ics:$subId');
          if (idx != -1) return idx;
        }
      }
    }
    return 100 + _sourceOrder(event.source);
  }

  /// Ordre par défaut : Infomaniak → Notion → ICS → local
  static int _sourceOrder(String source) {
    switch (source) {
      case AppConstants.sourceInfomaniak:
        return 0;
      case AppConstants.sourceNotion:
        return 1;
      case AppConstants.sourceIcs:
        return 2;
      default:
        return 3;
    }
  }

  void _onDragEnd(AppointmentDragEndDetails details) {
    final event = details.appointment is EventModel
        ? details.appointment as EventModel
        : null;
    if (event == null || details.droppingTime == null) return;

    if (event.isFromIcs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les abonnements .ics sont en lecture seule'),
          backgroundColor: Color(0xFFFF9500),
        ),
      );
      return;
    }

    final duration = event.endDate.difference(event.startDate);
    DateTime newStart = details.droppingTime!;

    // Pour les all-day, garder uniquement la date (pas d'heure)
    if (event.isAllDay) {
      newStart = DateTime(newStart.year, newStart.month, newStart.day);
    } else {
      // Snap aux 15 minutes les plus proches pour la précision
      newStart = _snapTo15Min(newStart);
    }

    final newEnd = newStart.add(duration);

    // Ignorer si les dates n'ont pas changé (drag annulé ou même position)
    if (newStart == event.startDate && newEnd == event.endDate) return;

    _updateEventDates(event, newStart, newEnd);
  }

  void _onAppointmentResizeEnd(AppointmentResizeEndDetails details) {
    final event = details.appointment is EventModel
        ? details.appointment as EventModel
        : null;
    if (event == null) return;

    if (event.isFromIcs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les abonnements .ics sont en lecture seule'),
          backgroundColor: Color(0xFFFF9500),
        ),
      );
      return;
    }

    final newStart = details.startTime ?? event.startDate;
    final newEnd = details.endTime ?? event.endDate;

    // Snap aux 15 minutes
    final snappedStart = event.isAllDay ? newStart : _snapTo15Min(newStart);
    final snappedEnd = event.isAllDay ? newEnd : _snapTo15Min(newEnd);

    // Ignorer si rien n'a changé
    if (snappedStart == event.startDate && snappedEnd == event.endDate) return;

    // Vérifier que la durée minimum est de 15 min
    if (snappedEnd.difference(snappedStart).inMinutes < 15) return;

    _updateEventDates(event, snappedStart, snappedEnd);
  }

  /// Arrondit au quart d'heure le plus proche
  DateTime _snapTo15Min(DateTime dt) {
    final min = dt.minute;
    final snapped = (min / 15).round() * 15;
    return DateTime(
        dt.year, dt.month, dt.day, dt.hour + (snapped ~/ 60), snapped % 60);
  }

  Future<void> _updateEventDates(
    EventModel event,
    DateTime newStart,
    DateTime newEnd,
  ) async {
    // Confirmation si changement de jour (protection drag accidentel)
    final dayChanged = newStart.year != event.startDate.year ||
        newStart.month != event.startDate.month ||
        newStart.day != event.startDate.day;

    if (dayChanged && !event.isAllDay) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Déplacer l\'événement ?'),
          content: Text(
            '${event.title}\n→ ${CalendarDateUtils.formatDisplayDateTime(newStart)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Déplacer'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        // Rafraîchir pour restaurer la position visuelle
        ref.read(eventsNotifierProvider.notifier).refresh();
        return;
      }
    }

    final updatedEvent = event.copyWith(
      startDate: newStart,
      endDate: newEnd,
      updatedAt: DateTime.now(),
    );

    try {
      final notifier = ref.read(eventsNotifierProvider.notifier);
      await notifier.updateEvent(updatedEvent);

      if (mounted) {
        final timeOnly = !dayChanged;
        final msg = timeOnly
            ? '${event.title} → ${CalendarDateUtils.formatDisplayTime(newStart)} - ${CalendarDateUtils.formatDisplayTime(newEnd)}'
            : '${event.title} déplacé au ${CalendarDateUtils.formatDisplayDateTime(newStart)}';

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 4),
              showCloseIcon: true,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Annuler',
                onPressed: () async {
                  final restored = event.copyWith(updatedAt: DateTime.now());
                  await notifier.updateEvent(restored);
                },
              ),
            ),
          );
      }

      // Pousser vers la source distante en arrière-plan
      ref
          .read(syncNotifierProvider.notifier)
          .pushEvent(updatedEvent)
          .catchError((e) {
        AppLogger.instance
            .warning('CalendarScreen', 'Erreur sync drag&drop: $e');
      });
    } catch (e) {
      ref.read(eventsNotifierProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du déplacement : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onCalendarTap(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.appointment) {
      final apt = details.appointments?.first;
      final event = apt is EventModel ? apt : null;
      if (event != null) {
        openEventDetail(context, event);
      }
    } else if (details.targetElement == CalendarElement.calendarCell &&
        details.date != null) {
      ref.read(selectedDateProvider.notifier).state = details.date!;
    }
  }

  void _onCalendarLongPress(CalendarLongPressDetails details) {
    if (details.targetElement == CalendarElement.calendarCell &&
        details.date != null) {
      _showCreateEventSheet(details.date!);
    }
  }

  void _showCreateEventSheet(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventFormScreen(initialDate: date),
      ),
    );
  }

  Color _getCategoryColor(EventModel event) {
    final firstCategory = event.categoryTags.firstOrNull;
    if (firstCategory != null) return AppColors.fromHex(firstCategory.colorHex);
    if (event.isFromNotion) return const Color(0xFF5856D6);
    if (event.isFromInfomaniak) return AppColors.sourceInfomaniak;
    return const Color(0xFF007AFF);
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'calendar_fab',
      onPressed: () => _showCreateEventSheet(DateTime.now()),
      tooltip: 'Nouvel événement',
      child: const HugeIcon(
        icon: HugeIcons.strokeRoundedAdd01,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ================================================================
  // Panneau latéral : Tâches Notion non planifiées + drag & drop
  // ================================================================

  /// Enveloppe le calendrier dans un DragTarget pour recevoir des tâches.
  /// Résout la date directement depuis la position de drop sur le calendrier.
  Widget _wrapWithDragTarget(Widget calendar) {
    return DragTarget<NotionTaskModel>(
      onAcceptWithDetails: (details) {
        // Résoudre la date depuis la position de drop via le SfCalendar
        DateTime? resolvedDate;
        final renderObject = _calendarKey.currentContext?.findRenderObject();
        if (renderObject is RenderBox) {
          final localOffset = renderObject.globalToLocal(details.offset);
          final calendarDetails = _calendarController
              .getCalendarDetailsAtOffset
              ?.call(localOffset);
          resolvedDate = calendarDetails?.date;
        }

        if (resolvedDate != null) {
          // Drop direct — date résolue depuis la position
          _assignTaskDirect(details.data, resolvedDate);
        } else {
          // Fallback dialog si la position ne peut pas être résolue
          // (ex: zone header, hors grille)
          _onTaskTapped(details.data);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDragging = candidateData.isNotEmpty;
        if (isDragging) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: calendar,
          );
        }
        return calendar;
      },
    );
  }

  /// Assigne directement une tâche à la date résolue par le drop.
  void _assignTaskDirect(NotionTaskModel task, DateTime date) async {
    try {
      await ref.read(notionProjectTasksProvider.notifier).assignDate(
            task.id,
            task.databaseId,
            date,
          );

      // ── Insertion locale provisoire pour affichage immédiat ──
      // Le prochain syncAll() écrasera avec les données complètes
      // (ConflictAlgorithm.replace sur UNIQUE(remote_id, source)).
      final isAllDay = date.hour == 0 && date.minute == 0;
      final endDate = isAllDay ? date : date.add(const Duration(hours: 1));
      final provisionalEvent = EventModel(
        remoteId: task.id,
        source: AppConstants.sourceNotion,
        calendarId: task.databaseId,
        type: EventType.task,
        title: task.title,
        startDate: date,
        endDate: endDate,
        isAllDay: isAllDay,
        notionPageId: task.id,
        status: task.status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await DatabaseHelper.instance.insertEvent(provisionalEvent);

      // Rafraîchir le calendrier immédiatement (lecture DB locale)
      ref.read(eventsNotifierProvider.notifier).refresh();

      // Sync complète en arrière-plan (écrasera l'event provisoire
      // avec les données enrichies : description, tags, etc.)
      ref.read(syncNotifierProvider.notifier).syncAll().catchError((e) {
        AppLogger.instance
            .warning('CalendarScreen', 'Sync post-assignDate: $e');
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '«${task.title}» planifié le ${DateFormat('EEEE d MMMM à HH:mm', 'fr_FR').format(date)}',
              ),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Tap sur une tâche (sans drag) — dialog date/heure en fallback.
  void _onTaskTapped(NotionTaskModel task) async {
    final displayDate = _calendarController.displayDate ?? DateTime.now();
    final selectedDate = ref.read(selectedDateProvider);
    final initialDate =
        selectedDate.difference(DateTime.now()).inDays.abs() < 60
            ? selectedDate
            : displayDate;

    // Étape 1 : choisir la date
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Planifier «${task.title}»',
      locale: const Locale('fr', 'FR'),
    );
    if (date == null || !mounted) return;

    // Étape 2 : choisir l'heure
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Heure de début',
    );
    if (time == null || !mounted) return;

    final result = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    _assignTaskDirect(task, result);
  }

  /// Panneau latéral affichant les tâches Notion sans date.
  Widget _buildTodoPanel(BuildContext context) {
    final tasksAsync = ref.watch(notionProjectTasksProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTaskDaily02,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'À planifier',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  onPressed: () =>
                      ref.invalidate(notionProjectTasksProvider),
                  tooltip: 'Rafraîchir',
                  iconSize: 18,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _showTodoPanel = false),
                  tooltip: 'Fermer',
                  iconSize: 18,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Filtres ──
          _buildTodoFilters(context, tasksAsync.valueOrNull ?? []),
          const Divider(height: 1),
          // ── Info drag & drop ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Glissez une tâche vers le calendrier',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          // ── Liste des tâches ──
          Expanded(
            child: tasksAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedAlert02,
                      color: Theme.of(context).colorScheme.error,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Erreur chargement Notion',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              data: (tasks) {
                // Appliquer les filtres
                var filtered = tasks;
                if (_todoFilterDb != null) {
                  filtered = filtered
                      .where((t) => t.databaseName == _todoFilterDb)
                      .toList();
                }
                if (_todoFilterStatus != null) {
                  filtered = filtered
                      .where((t) => t.status == _todoFilterStatus)
                      .toList();
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.3),
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tout est planifié !',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (_todoFilterDb != null || _todoFilterStatus != null)
                                ? 'Aucune tâche pour ce filtre.'
                                : 'Aucune tâche Notion sans date.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildDraggableTask(filtered[index], isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Carte tâche draggable pour le panneau latéral.
  Widget _buildDraggableTask(NotionTaskModel task, bool isDark) {
    return Draggable<NotionTaskModel>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedTaskDaily02,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTaskCard(task, isDark),
      ),
      child: GestureDetector(
        onTap: () => _onTaskTapped(task),
        child: _buildTaskCard(task, isDark),
      ),
    );
  }

  /// Carte Notion-like pour une tâche non planifiée.
  Widget _buildTaskCard(NotionTaskModel task, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Barre latérale colorée Notion
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: task.color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                // Badges : BDD + status + priority
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    if (task.databaseName.isNotEmpty)
                      _buildMiniChip(
                        task.databaseName,
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    if (task.status != null)
                      _buildMiniChip(
                        task.status!,
                        _statusColor(task.status!).withValues(alpha: 0.15),
                        _statusColor(task.status!),
                      ),
                    if (task.category != null)
                      _buildMiniChip(
                        task.category!,
                        Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    if (task.priority != null)
                      _buildMiniChip(
                        task.priority!,
                        Theme.of(context)
                            .colorScheme
                            .tertiaryContainer,
                        Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Icône grip pour indiquer le drag
          HugeIcon(
            icon: HugeIcons.strokeRoundedDragDropVertical,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.3),
            size: 16,
          ),
        ],
      ),
    );
  }

  /// Mini chip pour afficher une info sur la carte tâche.
  Widget _buildMiniChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Couleur selon le statut Notion.
  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('done') || s.contains('terminé') || s.contains('fait')) {
      return const Color(0xFF34C759);
    }
    if (s.contains('progress') || s.contains('cours') || s.contains('doing')) {
      return const Color(0xFFFF9500);
    }
    if (s.contains('blocked') || s.contains('bloqué')) {
      return const Color(0xFFFF3B30);
    }
    return const Color(0xFF8E8E93); // gris par défaut
  }

  /// Construit les chips de filtre (BDD + statut).
  Widget _buildTodoFilters(
      BuildContext context, List<NotionTaskModel> allTasks) {
    // Extraire les valeurs uniques
    final dbNames = allTasks
        .map((t) => t.databaseName)
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    final statuses = allTasks
        .map((t) => t.status)
        .where((s) => s != null)
        .cast<String>()
        .toSet()
        .toList();

    if (dbNames.isEmpty && statuses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          // Filtre par BDD
          if (dbNames.length > 1)
            ...dbNames.map((db) => _buildFilterChip(
                  label: db,
                  selected: _todoFilterDb == db,
                  onTap: () => setState(() {
                    _todoFilterDb =
                        _todoFilterDb == db ? null : db;
                  }),
                )),
          // Séparateur visuel
          if (dbNames.length > 1 && statuses.isNotEmpty)
            SizedBox(
              height: 24,
              child: VerticalDivider(
                width: 8,
                thickness: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
              ),
            ),
          // Filtre par statut
          if (statuses.isNotEmpty)
            ...statuses.map((s) => _buildFilterChip(
                  label: s,
                  selected: _todoFilterStatus == s,
                  color: _statusColor(s),
                  onTap: () => setState(() {
                    _todoFilterStatus =
                        _todoFilterStatus == s ? null : s;
                  }),
                )),
        ],
      ),
    );
  }

  /// Chip de filtre cliquable.
  Widget _buildFilterChip({
    required String label,
    required bool selected,
    Color? color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? theme.colorScheme.primary).withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(
                  color:
                      (color ?? theme.colorScheme.primary).withValues(alpha: 0.5),
                  width: 1,
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? (color ?? theme.colorScheme.primary)
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Adaptateur de données Syncfusion
// ============================================================

class _CalendarDataSource extends CalendarDataSource<EventModel> {
  /// Si [useSortOffset] est true, un micro-décalage est ajouté aux start/end
  /// pour que SfCalendar (qui re-trie par startTime) respecte l'ordre de
  /// notre liste pré-triée (tri secondaire par calendrier source).
  final bool useSortOffset;

  _CalendarDataSource(List<EventModel> events, {this.useSortOffset = false}) {
    appointments = events;
  }

  @override
  DateTime getStartTime(int index) {
    final event = appointments![index] as EventModel;
    if (!useSortOffset) return event.startDate;
    // Ajoute index microsecondes pour préserver l'ordre de tri.
    // 1000 µs = 1 ms → invisible pour l'utilisateur.
    return event.startDate.add(Duration(microseconds: index));
  }

  @override
  DateTime getEndTime(int index) {
    final event = appointments![index] as EventModel;
    if (!useSortOffset) return event.endDate;
    return event.endDate.add(Duration(microseconds: index));
  }

  @override
  String getSubject(int index) => (appointments![index] as EventModel).title;

  @override
  bool isAllDay(int index) {
    final event = appointments![index] as EventModel;
    // Safety net : un événement > 23 h est traité comme all-day
    if (!event.isAllDay &&
        event.endDate.difference(event.startDate).inHours > 23) {
      return true;
    }
    return event.isAllDay;
  }

  @override
  Color getColor(int index) => Colors.blue; // Remplacé par appointmentBuilder

  @override
  EventModel convertAppointmentToObject(
      EventModel customData, Appointment appointment) {
    return customData;
  }
}
