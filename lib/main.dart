import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'services/notification_service.dart';
import 'services/background_worker_service.dart';
import 'services/logger_service.dart';
import 'services/llama_service.dart';
import 'app.dart';

/// Observer global des providers Riverpod.
/// Capture les erreurs de build/listen pour les envoyer dans AppLogger.
class AppProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    AppLogger.instance.error(
      'Provider',
      'Provider ${provider.name ?? provider.runtimeType.toString()} failed: $error',
      error,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Capture des erreurs Flutter non attrapées ──
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.instance.error(
      'FlutterError',
      'Flutter error: ${details.exceptionAsString()}',
      details.exception,
    );
  };

  // ── Capture des erreurs Platform (Dart async non attrapées) ──
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.instance.error(
      'PlatformError',
      'Platform error: $error',
      error,
    );
    return true;
  };

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

  // ── V3 : Initialiser le chemin de la bibliothèque llama.cpp ──
  LlamaService.initLibraryPath();

  runApp(
    ProviderScope(
      observers: [AppProviderObserver()],
      child: const UnifiedCalendarApp(),
    ),
  );
}
