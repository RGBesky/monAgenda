import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/weather_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/sync_provider.dart';
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
              : () => ref.read(syncNotifierProvider.notifier).syncAll(),
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
    final firstDayOfWeek = settings?.firstDayOfWeek == AppConstants.firstDaySunday
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
      timeSlotViewSettings: const TimeSlotViewSettings(
        startHour: 7,
        endHour: 22,
        timeInterval: Duration(minutes: 30),
        timeIntervalHeight: 40,
      ),
      monthViewSettings: const MonthViewSettings(
        appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
        showAgenda: true,
        agendaItemHeight: 50,
      ),
      scheduleViewSettings: ScheduleViewSettings(
        monthHeaderSettings: MonthHeaderSettings(
          monthFormat: 'MMMM yyyy',
          height: 60,
          textAlign: TextAlign.start,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          monthTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      appointmentBuilder: _buildAppointment,
      onTap: _onCalendarTap,
      onLongPress: _onCalendarLongPress,
      onViewChanged: (details) {
        if (details.visibleDates.isEmpty) return;
        final start = details.visibleDates.first;
        final end = details.visibleDates.last;
        ref.read(displayedDateRangeProvider.notifier).state = DateRange(
          start: start.subtract(const Duration(days: 7)),
          end: end.add(const Duration(days: 7)),
        );
      },
    );
  }

  Widget _buildAppointment(
    BuildContext context,
    CalendarAppointmentDetails details,
  ) {
    final event = (details.appointments.first as _CalendarAppointment).event;
    final priorityColor = _getPriorityColor(event);
    final categoryColor = _getCategoryColor(event);
    final textColor = categoryColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: priorityColor, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                maxLines: details.bounds.height > 40 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (details.bounds.width > 50) _buildSourceLogo(event, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceLogo(EventModel event, Color textColor) {
    if (event.isFromIcs) return const SizedBox.shrink();

    return SizedBox(
      width: 14,
      height: 14,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: event.isFromInfomaniak
              ? BorderRadius.circular(7)
              : BorderRadius.circular(2),
        ),
        child: Center(
          child: Text(
            event.isFromInfomaniak ? 'ik' : 'N',
            style: TextStyle(
              color: event.isFromInfomaniak
                  ? const Color(0xFF0D6EFD)
                  : Colors.black87,
              fontSize: event.isFromInfomaniak ? 6 : 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _onCalendarTap(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.appointment) {
      final appointment = details.appointments?.first as _CalendarAppointment?;
      if (appointment != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: appointment.event),
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
    final isOffline = ref.read(isOfflineProvider);
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

  Color _getPriorityColor(EventModel event) {
    final priority = event.priorityTag;
    if (priority == null) return const Color(0xFF43A047);
    return _colorFromHex(priority.colorHex);
  }

  Color _getCategoryColor(EventModel event) {
    final firstCategory = event.categoryTags.firstOrNull;
    if (firstCategory != null) return _colorFromHex(firstCategory.colorHex);
    return const Color(0xFF1E88E5);
  }

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showCreateEventSheet(DateTime.now()),
      icon: const Icon(Icons.add),
      label: const Text('Nouveau'),
    );
  }
}

// ============================================================
// Adaptateur de données Syncfusion
// ============================================================

class _CalendarAppointment extends Appointment {
  final EventModel event;

  _CalendarAppointment({required this.event})
      : super(
          startTime: event.startDate,
          endTime: event.endDate,
          subject: event.title,
          isAllDay: event.isAllDay,
          color: Colors.blue, // Remplacé dans appointmentBuilder
        );
}

class _CalendarDataSource extends CalendarDataSource {
  final List<EventModel> events;

  _CalendarDataSource(this.events) {
    appointments = events
        .map((e) => _CalendarAppointment(event: e))
        .toList();
  }
}
