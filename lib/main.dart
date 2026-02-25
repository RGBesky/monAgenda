import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:syncfusion_flutter_core/core.dart';
import 'services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Licence Syncfusion Community (gratuite pour usage personnel).
  // Obtenez votre clé sur : https://www.syncfusion.com/products/communitylicense
  // Sans clé valide, un filigrane s'affiche mais l'appli fonctionne.
  SyncfusionLicense.registerLicense(
    const String.fromEnvironment(
      'SYNCFUSION_LICENSE_KEY',
      defaultValue: '',
    ),
  );

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
