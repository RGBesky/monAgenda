import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/database/database_helper.dart';

/// Noms des tâches WorkManager.
class WorkManagerTasks {
  static const String rescheduleNotifications = 'rescheduleNotifications';
  static const String dailySummary = 'dailySummary';
  static const String periodicReschedule = 'periodicReschedule';
}

/// Callback top-level requis par WorkManager (doit être top-level ou static).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      // Initialiser l'environnement minimal pour les tâches en background
      WidgetsFlutterBinding.ensureInitialized();

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      Intl.defaultLocale = 'fr_FR';
      await initializeDateFormatting('fr_FR', null);
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));

      switch (taskName) {
        case WorkManagerTasks.rescheduleNotifications:
        case WorkManagerTasks.periodicReschedule:
          await _rescheduleAllNotifications();
          break;
        case WorkManagerTasks.dailySummary:
          await _showDailySummary();
          break;
        default:
          return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  });
}

/// Reprogramme toutes les notifications pour les événements à venir.
Future<void> _rescheduleAllNotifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const linuxSettings =
      LinuxInitializationSettings(defaultActionName: 'Ouvrir');
  const initSettings = InitializationSettings(
    android: androidSettings,
    linux: linuxSettings,
  );
  await plugin.initialize(initSettings);

  // Annuler les anciennes notifications (sauf 999999 = résumé matinal)
  final pending = await plugin.pendingNotificationRequests();
  for (final p in pending) {
    if (p.id != 999999) {
      await plugin.cancel(p.id);
    }
  }

  // Récupérer les événements des 7 prochains jours
  final now = DateTime.now();
  final end = now.add(const Duration(days: 7));
  final events = await DatabaseHelper.instance.getEventsByDateRange(now, end);

  for (final event in events) {
    if (event.reminderMinutes == null || event.id == null) continue;

    final reminderTime = event.startDate.subtract(
      Duration(minutes: event.reminderMinutes!),
    );
    if (reminderTime.isBefore(now)) continue;

    try {
      final timeStr = event.isAllDay
          ? 'Toute la journée'
          : DateFormat.Hm('fr_FR').format(event.startDate);
      final locationStr =
          event.location != null ? '\n📍 ${event.location}' : '';

      await plugin.zonedSchedule(
        event.id!,
        'Rappel : ${event.title}',
        '$timeStr$locationStr',
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'event_reminders',
            'Rappels événements',
            channelDescription: 'Rappels pour vos événements du calendrier',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF1565C0),
          ),
          linux: LinuxNotificationDetails(
            category: LinuxNotificationCategory.email,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'event:${event.id}',
      );
    } catch (_) {
      // Silently fail for unsupported platforms
    }
  }
}

/// Affiche un résumé matinal des événements du jour.
Future<void> _showDailySummary() async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const linuxSettings =
      LinuxInitializationSettings(defaultActionName: 'Ouvrir');
  const initSettings = InitializationSettings(
    android: androidSettings,
    linux: linuxSettings,
  );
  await plugin.initialize(initSettings);

  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);
  final dayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final events =
      await DatabaseHelper.instance.getEventsByDateRange(dayStart, dayEnd);

  if (events.isEmpty) return;

  final body = events.length == 1
      ? '1 événement aujourd\'hui : ${events.first.title}'
      : '${events.length} événements aujourd\'hui';

  await plugin.show(
    999999,
    '📅 Votre journée',
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_summary',
        'Résumé matinal',
        channelDescription: 'Résumé quotidien de votre agenda',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF1565C0),
      ),
      linux: LinuxNotificationDetails(
        category: LinuxNotificationCategory.email,
      ),
    ),
    payload: 'daily_summary',
  );
}

/// Service d'initialisation WorkManager.
class BackgroundWorkerService {
  BackgroundWorkerService._();

  /// Initialise WorkManager et programme les tâches périodiques.
  /// À appeler dans main() après le binding Flutter.
  static Future<void> initialize() async {
    // WorkManager ne fonctionne que sur Android/iOS
    if (!Platform.isAndroid && !Platform.isIOS) return;

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // Tâche périodique : reprogrammer les notifications toutes les 6h
    // Garantit que les notifications survivent au reboot et au kill
    await Workmanager().registerPeriodicTask(
      'periodic-reschedule',
      WorkManagerTasks.periodicReschedule,
      frequency: const Duration(hours: 6),
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      initialDelay: const Duration(minutes: 5),
    );
  }

  /// Reprogramme immédiatement les notifications (après création/modif event).
  static Future<void> rescheduleNow() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    await Workmanager().registerOneOffTask(
      'immediate-reschedule-${DateTime.now().millisecondsSinceEpoch}',
      WorkManagerTasks.rescheduleNotifications,
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
  }
}
