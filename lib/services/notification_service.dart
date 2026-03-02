import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app.dart';
import '../core/database/database_helper.dart';
import '../core/models/event_model.dart';
import '../core/utils/date_utils.dart';
import '../features/events/screens/event_detail_screen.dart';
import 'logger_service.dart';

/// Service de notifications locales (sans backend requis).
/// Sur Linux, utilise des Timers + show() car zonedSchedule n'est pas supporté.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Timers actifs pour les notifications Linux planifiées.
  final Map<int, Timer> _linuxTimers = {};

  NotificationService._internal();

  Future<void> initialize() async {
    if (_initialized) return;

    // Les timezones sont initialisées dans main.dart (Europe/Paris forcé)

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Ouvrir');

    const initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Sur Android 13+, demander la permission POST_NOTIFICATIONS au runtime
    if (Platform.isAndroid) {
      await _requestAndroidNotificationPermission();
    }

    _initialized = true;
  }

  /// Demande la permission POST_NOTIFICATIONS sur Android 13+ (API 33).
  Future<void> _requestAndroidNotificationPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    AppLogger.instance.info('Notification', 'Tapped payload: $payload');

    if (payload.startsWith('event:')) {
      final idStr = payload.substring('event:'.length);
      final eventId = int.tryParse(idStr);
      if (eventId == null) return;

      // Charger l'événement puis naviguer
      _navigateToEvent(eventId);
    }
    // daily_summary → rien de spécial, l'app s'ouvre juste
  }

  /// Charge un événement par ID et ouvre son écran de détail.
  Future<void> _navigateToEvent(int eventId) async {
    try {
      final event = await DatabaseHelper.instance.getEventById(eventId);
      if (event == null) {
        AppLogger.instance
            .warning('Notification', 'Event #$eventId not found in DB');
        return;
      }

      final nav = UnifiedCalendarApp.navigatorKey.currentState;
      if (nav == null) return;

      nav.push(
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        ),
      );
    } catch (e) {
      AppLogger.instance.error('Notification', 'Navigate to event failed', e);
    }
  }

  /// Programme un rappel pour un événement.
  Future<void> scheduleEventReminder(EventModel event) async {
    if (event.reminderMinutes == null || event.id == null) return;

    final reminderTime = event.startDate.subtract(
      Duration(minutes: event.reminderMinutes!),
    );

    if (reminderTime.isBefore(DateTime.now())) return;

    if (Platform.isLinux) {
      // Linux : Timer + show() car zonedSchedule non supporté
      final delay = reminderTime.difference(DateTime.now());
      _linuxTimers[event.id!]?.cancel();
      _linuxTimers[event.id!] = Timer(delay, () {
        _showLinuxNotification(
          event.id!,
          'Rappel : ${event.title}',
          _buildReminderBody(event),
          payload: 'event:${event.id}',
        );
        _linuxTimers.remove(event.id!);
      });
      return;
    }

    try {
      await _plugin.zonedSchedule(
        event.id!,
        'Rappel : ${event.title}',
        _buildReminderBody(event),
        tz.TZDateTime.from(reminderTime, tz.local),
        _buildNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'event:${event.id}',
      );
    } catch (_) {
      // zonedSchedule non supporté sur cette plateforme
    }
  }

  /// Annule le rappel d'un événement.
  Future<void> cancelEventReminder(int eventId) async {
    _linuxTimers[eventId]?.cancel();
    _linuxTimers.remove(eventId);
    try {
      await _plugin.cancel(eventId);
    } catch (e) {
      AppLogger.instance.warning('Notification', 'cancel($eventId) failed: $e');
    }
  }

  /// Programme le résumé matinal quotidien.
  Future<void> scheduleDailySummary({
    int hour = 8,
    int minute = 0,
  }) async {
    const id = 999999; // ID fixe pour le résumé matinal

    try {
      await _plugin.cancel(id);
    } catch (e) {
      AppLogger.instance
          .warning('Notification', 'cancel daily summary failed: $e');
    }

    if (Platform.isLinux) {
      // Linux : Timer récurrent via _scheduleLinuxDailySummary
      _linuxTimers[id]?.cancel();
      _scheduleLinuxDailySummary(id, hour, minute);
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        id,
        'Votre journée',
        'Appuyez pour voir vos événements du jour',
        scheduledDate,
        _buildNotificationDetails(channelId: 'daily_summary'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_summary',
      );
    } catch (_) {
      // zonedSchedule non supporté sur cette plateforme
    }
  }

  /// Planifie le résumé matinal récurrent sur Linux via Timer.
  void _scheduleLinuxDailySummary(int id, int hour, int minute) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    final delay = next.difference(now);
    _linuxTimers[id] = Timer(delay, () {
      _showLinuxNotification(
        id,
        'Votre journée',
        'Cliquez pour voir vos événements du jour',
        payload: 'daily_summary',
      );
      // Re-planifier pour demain
      _scheduleLinuxDailySummary(id, hour, minute);
    });
  }

  /// Annule toutes les notifications d'une source.
  Future<void> cancelAllReminders() async {
    // Annuler tous les timers Linux
    for (final timer in _linuxTimers.values) {
      timer.cancel();
    }
    _linuxTimers.clear();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      AppLogger.instance.warning('Notification', 'cancelAll failed: $e');
    }
  }

  /// Affiche une notification via le plugin (fonctionne sur toutes les plateformes).
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      _buildNotificationDetails(),
      payload: payload,
    );
  }

  /// Affiche une notification sur Linux via le plugin show() + fallback notify-send.
  Future<void> _showLinuxNotification(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
    try {
      await _plugin.show(id, title, body, _buildNotificationDetails(),
          payload: payload);
    } catch (_) {
      // Fallback : notify-send (disponible sur la plupart des distros Linux)
      try {
        await Process.run('notify-send', [
          '--app-name=MonAgenda',
          '--urgency=normal',
          title,
          body,
        ]);
      } catch (e) {
        AppLogger.instance
            .warning('Notification', 'notify-send fallback failed: $e');
      }
    }
  }

  String _buildReminderBody(EventModel event) {
    final timeStr = event.isAllDay
        ? 'Toute la journée'
        : CalendarDateUtils.formatDisplayTime(event.startDate);
    final locationStr = event.location != null ? '\n📍 ${event.location}' : '';
    return '$timeStr$locationStr';
  }

  NotificationDetails _buildNotificationDetails({
    String channelId = 'event_reminders',
  }) {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'event_reminders' ? 'Rappels événements' : 'Résumé matinal',
      channelDescription: channelId == 'event_reminders'
          ? 'Rappels pour vos événements du calendrier'
          : 'Résumé quotidien de votre agenda',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1565C0),
    );

    const linuxDetails = LinuxNotificationDetails(
      category: LinuxNotificationCategory.email,
    );

    return NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );
  }
}
