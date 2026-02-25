import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../services/sync_engine.dart';
import '../../../services/weather_service.dart';
import '../../events/screens/event_detail_screen.dart';
import '../../events/screens/event_form_screen.dart';
import '../widgets/weather_header.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late CalendarController _calendarController;
  List<WeatherModel> _forecasts = [];
  bool _loadingWeather = false;

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
      final weatherService = WeatherService();
      // TODO : récupérer la géolocalisation réelle
      weatherService.setLocation(latitude: 46.2044, longitude: 6.1432);
      final forecasts = await weatherService.fetchWeekForecast();
      if (mounted) setState(() => _forecasts = forecasts);
    } catch (_) {}
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

    return Scaffold(
      appBar: _buildAppBar(context, syncState),
      body: Column(
        children: [
          if (_forecasts.isNotEmpty)
            WeatherHeader(
              forecasts: _forecasts,
              displayedDate: DateTime.now(),
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
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  AppBar _buildAppBar(BuildContext context, SyncState syncState) {
    return AppBar(
      title: const Text(
        'Calendrier',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        // Bouton aujourd'hui
        TextButton(
          onPressed: () {
            _calendarController.displayDate = DateTime.now();
          },
          child: const Text("Aujourd'hui"),
        ),
        // Sélecteur de vue
        PopupMenuButton<String>(
          icon: const Icon(Icons.view_comfy_outlined),
          onSelected: (view) {
            _calendarController.view = _getCalendarView(view);
            ref.read(settingsProvider.notifier).setDefaultView(view);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: AppConstants.viewMonth,
              child: ListTile(
                leading: Icon(Icons.calendar_view_month),
                title: Text('Mois'),
              ),
            ),
            const PopupMenuItem(
              value: AppConstants.viewWeek,
              child: ListTile(
                leading: Icon(Icons.calendar_view_week),
                title: Text('Semaine'),
              ),
            ),
            const PopupMenuItem(
              value: AppConstants.viewDay,
              child: ListTile(
                leading: Icon(Icons.calendar_view_day),
                title: Text('Jour'),
              ),
            ),
            const PopupMenuItem(
              value: AppConstants.viewAgenda,
              child: ListTile(
                leading: Icon(Icons.view_agenda),
                title: Text('Agenda'),
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
              : const Icon(Icons.sync),
          onPressed: syncState.isSyncing
              ? null
              : () async {
                  await ref.read(syncNotifierProvider.notifier).syncAll();
                  if (!mounted) return;
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

  Widget _buildCalendarWithEvents(
    BuildContext context,
    List<EventModel> events,
    String currentView,
    AppSettings? settings,
  ) {
    final dataSource = _CalendarDataSource(events);
    final firstDayOfWeek =
        settings?.firstDayOfWeek == AppConstants.firstDaySunday
            ? 0
            : 1; // 1 = lundi, 0 = dimanche

    return SfCalendar(
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
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        dateTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      headerStyle: CalendarHeaderStyle(
        textAlign: TextAlign.start,
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      timeSlotViewSettings: TimeSlotViewSettings(
        startHour: 6,
        endHour: 23,
        timeInterval: const Duration(minutes: 30),
        timeIntervalHeight: 52,
        timelineAppointmentHeight: 60,
        timeTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        timeRulerSize: 52,
      ),
      monthCellBuilder: _buildMonthCell,
      monthViewSettings: MonthViewSettings(
        appointmentDisplayMode: MonthAppointmentDisplayMode.none,
        showAgenda: true,
        agendaItemHeight: 68,
        numberOfWeeksInView: 6,
        appointmentDisplayCount: 4,
        monthCellStyle: MonthCellStyle(
          textStyle: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          trailingDatesTextStyle: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          leadingDatesTextStyle: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        agendaStyle: AgendaStyle(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appointmentTextStyle: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          dateTextStyle: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          dayTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      scheduleViewSettings: ScheduleViewSettings(
        hideEmptyScheduleWeek: true,
        appointmentItemHeight: 76,
        dayHeaderSettings: DayHeaderSettings(
          dayFormat: 'EEE',
          width: 56,
          dayTextStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          dateTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        weekHeaderSettings: WeekHeaderSettings(
          startDateFormat: 'd MMM',
          endDateFormat: 'd MMM yyyy',
          height: 40,
          textAlign: TextAlign.start,
          weekTextStyle: TextStyle(
            fontSize: 13,
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
            fontSize: 17,
            fontWeight: FontWeight.w800,
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
          ref.read(displayedDateRangeProvider.notifier).state = DateRange(
            start: start.subtract(const Duration(days: 7)),
            end: end.add(const Duration(days: 7)),
          );
        });
      },
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
                    final icon = _categoryIcon(event);
                    return HugeIcon(
                      icon: icon,
                      color: isDark ? color.withValues(alpha: 0.9) : color,
                      size: 13,
                    );
                  }
                  // Fallback pour Appointment brut
                  return Icon(Icons.circle,
                      size: 6, color: Theme.of(context).colorScheme.primary);
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
    final accent = _getCategoryColor(event);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h = details.bounds.height;
    final w = details.bounds.width;

    // ── Style Apple Calendar — pastel/filled ──
    final bool isFilled = h > 40;
    final bg = isFilled
        ? AppColors.filledBg(accent, isDark: isDark)
        : AppColors.pastelBg(accent, isDark: isDark);
    final titleColor = isFilled
        ? AppColors.textOnFilled(accent, isDark: isDark)
        : AppColors.textOnPastel(accent, isDark: isDark);
    final iconColor = titleColor.withValues(alpha: 0.85);

    // Couleur du liseré priorité (côté droit)
    final priorityColor = _getPriorityColor(event);

    // Largeurs des liserés (proportionnel à la hauteur, capé par la largeur)
    final stripeW = (h * 0.25).clamp(4.0, (w * 0.15).clamp(4.0, 20.0));
    final prioW = priorityColor != null
        ? (h * 0.15).clamp(3.0, (w * 0.10).clamp(3.0, 12.0))
        : 0.0;
    // Largeur restante pour le contenu
    final contentW = (w - stripeW - prioW - 10).clamp(0.0, double.infinity);

    // SizedBox force les contraintes exactes, ClipRRect clip visuellement,
    // SingleChildScrollView élimine l'assertion RenderFlex overflow.
    return SizedBox(
      height: h,
      width: w,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: ColoredBox(
          color: bg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Liseré gauche — couleur catégorie
              Container(width: stripeW, color: accent),
              // Contenu principal
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w > 30 ? 5 : 2,
                      vertical: h < 22 ? 1 : 2,
                    ),
                    child: _buildAppointmentContent(
                        event, titleColor, iconColor, h, contentW, isDark),
                  ),
                ),
              ),
              // Liseré droit — priorité
              if (priorityColor != null)
                Container(width: prioW, color: priorityColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentContent(
    EventModel event,
    Color titleColor,
    Color iconColor,
    double h,
    double w,
    bool isDark,
  ) {
    // Info multi-jours
    final multiDayInfo = _multiDayInfo(event);

    // ── Tiny (< 22px) : titre seul ──
    if (h < 22) {
      return Text(
        multiDayInfo != null ? '${event.title} $multiDayInfo' : event.title,
        style: TextStyle(
          color: titleColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // ── Compact (< 36px) : icône + titre + source + heure ──
    if (h < 36) {
      return Row(
        children: [
          if (w > 30)
            HugeIcon(icon: _categoryIcon(event), color: iconColor, size: 13),
          if (w > 30) const SizedBox(width: 4),
          Expanded(
            child: Text(
              multiDayInfo != null
                  ? '${event.title} $multiDayInfo'
                  : event.title,
              style: TextStyle(
                color: titleColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!event.isAllDay && w > 120) ...[
            const SizedBox(width: 4),
            Text(
              CalendarDateUtils.formatDisplayTime(event.startDate),
              style: TextStyle(
                  color: iconColor, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      );
    }

    // ── Normal (< 62px) : titre + meta ──
    if (h < 62) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (w > 30)
                HugeIcon(
                    icon: _categoryIcon(event), color: titleColor, size: 15),
              if (w > 30) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _metaRow(event, iconColor, isDark, multiDayInfo),
        ],
      );
    }

    // ── Grand (>= 62px) : titre + meta + status ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (w > 30)
              HugeIcon(icon: _categoryIcon(event), color: titleColor, size: 16),
            if (w > 30) const SizedBox(width: 5),
            Expanded(
              child: Text(
                event.title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.1,
                ),
                maxLines: h > 80 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        _metaRow(event, iconColor, isDark, multiDayInfo),
      ],
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

  /// Couleur du liseré priorité (côté droit). null si pas de priorité notable.
  Color? _getPriorityColor(EventModel event) {
    final pri = event.priorityTag;
    if (pri == null) return null;
    final n = pri.name.toLowerCase();
    if (n.contains('normale') || n.contains('normal'))
      return null; // pas de liseré pour "Normale"
    return AppColors.fromHex(pri.colorHex);
  }

  // ── Icône de catégorie HugeIcons ─────────────────────────────────
  List<List<dynamic>> _categoryIcon(EventModel event) {
    final cat = event.categoryTags.firstOrNull;
    if (cat != null) return _tagNameToIcon(cat.name);
    if (event.isFromNotion) return HugeIcons.strokeRoundedListView;
    if (event.isFromInfomaniak) return HugeIcons.strokeRoundedCalendar01;
    return HugeIcons.strokeRoundedCalendarCheckIn01;
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

  // ── Ligne méta : heure + tag chips + multi-day info ──────────────
  Widget _metaRow(EventModel event, Color fallbackColor, bool isDark,
      [String? multiDayInfo]) {
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

    // Catégorie(s) — chips fond blanc, texte coloré
    for (final cat in event.categoryTags.take(2)) {
      final catColor = AppColors.fromHex(cat.colorHex);
      items.add(_tagChip(
        icon: _tagNameToIcon(cat.name),
        text: cat.name,
        color: catColor,
        isDark: isDark,
      ));
    }

    // Priorité — chip avec nom + couleur (seulement si non "Normale")
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

    // Status d'avancement — chip dans le même Wrap
    if (event.status != null && event.status!.isNotEmpty) {
      final statusColor = _statusColor(event.status!, isDark);
      items.add(_tagChip(
        icon: _statusIcon(event.status!),
        text: event.status!,
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
    return Wrap(spacing: 5, runSpacing: 2, children: items);
  }

  /// Couleur sémantique pour un status
  Color _statusColor(String status, bool isDark) {
    final s = status.toLowerCase();
    if (s.contains('terminé') || s.contains('done') || s.contains('fini')) {
      return const Color(0xFF34C759); // vert
    }
    if (s.contains('cours') || s.contains('progress')) {
      return const Color(0xFF007AFF); // bleu
    }
    if (s.contains('attente') || s.contains('wait') || s.contains('pause')) {
      return const Color(0xFFFF9500); // orange
    }
    if (s.contains('annulé') || s.contains('cancel')) {
      return const Color(0xFFFF3B30); // rouge
    }
    return const Color(0xFF8E8E93); // gris
  }

  /// Icône de status selon le texte
  static List<List<dynamic>> _statusIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('terminé') || s.contains('done') || s.contains('fini')) {
      return HugeIcons.strokeRoundedCheckmarkCircle01;
    }
    if (s.contains('cours') || s.contains('progress')) {
      return HugeIcons.strokeRoundedLoading03;
    }
    if (s.contains('attente') || s.contains('wait') || s.contains('pause')) {
      return HugeIcons.strokeRoundedPauseCircle;
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
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
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
        debugPrint('Erreur sync drag&drop: $e');
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: event),
          ),
        );
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
    final isOffline = ref.read(isOfflineProvider).value ?? false;
    if (isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Création impossible en mode hors ligne'),
          backgroundColor: Color(0xFFFF6D00),
        ),
      );
      return;
    }

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
      onPressed: () => _showCreateEventSheet(DateTime.now()),
      tooltip: 'Nouvel événement',
      child: const Icon(Icons.add_rounded, size: 26),
    );
  }
}

// ============================================================
// Adaptateur de données Syncfusion
// ============================================================

class _CalendarDataSource extends CalendarDataSource<EventModel> {
  _CalendarDataSource(List<EventModel> events) {
    appointments = events;
  }

  @override
  DateTime getStartTime(int index) =>
      (appointments![index] as EventModel).startDate;

  @override
  DateTime getEndTime(int index) =>
      (appointments![index] as EventModel).endDate;

  @override
  String getSubject(int index) => (appointments![index] as EventModel).title;

  @override
  bool isAllDay(int index) => (appointments![index] as EventModel).isAllDay;

  @override
  Color getColor(int index) => Colors.blue; // Remplacé par appointmentBuilder

  @override
  EventModel convertAppointmentToObject(
      EventModel customData, Appointment appointment) {
    return customData;
  }
}
