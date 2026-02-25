import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sur desktop (Linux, macOS, Windows), utiliser sqflite_common_ffi
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialiser les locales françaises
  await initializeDateFormatting('fr_FR', null);

  // Initialiser les notifications
  await NotificationService.instance.initialize();

  runApp(
    const ProviderScope(
      child: UnifiedCalendarApp(),
    ),
  );
}
