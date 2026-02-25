import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../core/models/event_model.dart';
import '../core/utils/date_utils.dart';

/// Service de notifications locales (sans backend requis).
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationService._internal();

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

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

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Navigation vers l'événement via deeplink
    // Sera géré par le router
  }

  /// Programme un rappel pour un événement.
  Future<void> scheduleEventReminder(EventModel event) async {
    if (event.reminderMinutes == null || event.id == null) return;

    final reminderTime = event.startDate.subtract(
      Duration(minutes: event.reminderMinutes!),
    );

    if (reminderTime.isBefore(DateTime.now())) return;

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
      // zonedSchedule non supporté sur desktop Linux
    }
  }

  /// Annule le rappel d'un événement.
  Future<void> cancelEventReminder(int eventId) async {
    try {
      await _plugin.cancel(eventId);
    } catch (_) {}
  }

  /// Programme le résumé matinal quotidien.
  Future<void> scheduleDailySummary({
    int hour = 8,
    int minute = 0,
  }) async {
    const id = 999999; // ID fixe pour le résumé matinal

    try {
      await _plugin.cancel(id);
    } catch (_) {}

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
      // zonedSchedule non supporté sur desktop Linux
    }
  }

  /// Annule toutes les notifications d'une source.
  Future<void> cancelAllReminders() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Affiche une notification immédiate (ex: fin de sync).
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
