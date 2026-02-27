import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'services/notification_service.dart';
import 'services/background_worker_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sur desktop (Linux, macOS, Windows), utiliser sqflite_common_ffi
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ── V2 : Forcer la locale et la timezone (usage perso Marseille) ──
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR', null);

  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Paris'));

  // Initialiser les notifications
  await NotificationService.instance.initialize();

  // ── V2 : WorkManager pour notifications fiables en background ──
  await BackgroundWorkerService.initialize();

  runApp(
    const ProviderScope(
      child: UnifiedCalendarApp(),
    ),
  );
}
