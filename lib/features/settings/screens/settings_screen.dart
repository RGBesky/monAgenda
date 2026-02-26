import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:dio/dio.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../core/utils/platform_utils.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../services/ics_service.dart';
import '../../../services/sync_engine.dart';
import '../../../core/database/database_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'connections_settings_screen.dart';
import 'tags_settings_screen.dart';
import 'notifications_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'backup_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final syncState = ref.watch(syncNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          // État de synchronisation
          if (syncState.lastSyncedAt != null)
            _buildSyncBanner(context, syncState),

          // Section Connexions
          _buildSection(
            context,
            title: 'Connexions',
            hugeIcon: HugeIcons.strokeRoundedCloudServer,
            children: [
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedUserCircle02,
                    color: Color(0xFF0098FF),
                    size: 22),
                title: const Text('Infomaniak'),
                subtitle: Text(
                  settings?.isInfomaniakConfigured == true
                      ? 'Connecté'
                      : 'Non configuré',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (settings?.isInfomaniakConfigured == true)
                      const HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                          color: Colors.green,
                          size: 16),
                    const SizedBox(width: 4),
                    const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        color: Colors.grey,
                        size: 18),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConnectionsSettingsScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedTask01,
                    color: Color(0xFF37352F),
                    size: 22),
                title: const Text('Notion'),
                subtitle: Text(
                  settings?.isNotionConfigured == true
                      ? 'Connecté'
                      : 'Non configuré',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (settings?.isNotionConfigured == true)
                      const HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                          color: Colors.green,
                          size: 16),
                    const SizedBox(width: 4),
                    const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        color: Colors.grey,
                        size: 18),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConnectionsSettingsScreen(
                      initialTab: 1,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar01,
                    color: Color(0xFF8E8E93),
                    size: 22),
                title: const Text('Abonnements .ics'),
                trailing: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: Colors.grey,
                    size: 18),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConnectionsSettingsScreen(
                      initialTab: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Section Tags
          _buildSection(
            context,
            title: 'Tags',
            hugeIcon: HugeIcons.strokeRoundedTag01,
            children: [
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSortByDown01,
                    color: Color(0xFF007AFF),
                    size: 22),
                title: const Text('Catégories et priorités'),
                trailing: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: Colors.grey,
                    size: 18),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TagsSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),

          // Section Notifications
          _buildSection(
            context,
            title: 'Notifications',
            hugeIcon: HugeIcons.strokeRoundedNotification01,
            children: [
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    color: Color(0xFFFF9500),
                    size: 22),
                title: const Text('Rappels et résumé matinal'),
                trailing: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: Colors.grey,
                    size: 18),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),

          // Section Apparence
          _buildSection(
            context,
            title: 'Apparence',
            hugeIcon: HugeIcons.strokeRoundedColorPicker,
            children: [
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMoon02,
                    color: Color(0xFF5856D6),
                    size: 22),
                title: const Text('Thème et affichage'),
                subtitle: Text(
                  settings?.theme == 'light'
                      ? 'Mode clair'
                      : settings?.theme == 'dark'
                          ? 'Mode sombre'
                          : 'Automatique',
                ),
                trailing: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: Colors.grey,
                    size: 18),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppearanceSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),

          // Section Météo
          _buildSection(
            context,
            title: 'Météo',
            hugeIcon: HugeIcons.strokeRoundedSun01,
            children: [
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedLocation01,
                    color: Color(0xFF42A5F5),
                    size: 22),
                title: const Text('Ville'),
                subtitle: Text(settings?.weatherCity ?? 'Genève'),
                trailing: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: Colors.grey,
                    size: 18),
                onTap: () => _editWeatherCity(context, ref, settings),
              ),
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedGps01,
                    color: Color(0xFF66BB6A),
                    size: 22),
                title: const Text('Détecter ma position'),
                subtitle: const Text('Géolocalisation automatique'),
                onTap: () => _detectLocation(context, ref),
              ),
            ],
          ),

          // Section Import/Export
          _buildSection(
            context,
            title: 'Import / Export',
            hugeIcon: HugeIcons.strokeRoundedExchange01,
            children: [
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedFileUpload,
                    color: Color(0xFF34C759),
                    size: 22),
                title: const Text('Importer un fichier .ics'),
                onTap: () => _importIcs(context, ref),
              ),
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDownload02,
                    color: Color(0xFF007AFF),
                    size: 22),
                title: const Text('Exporter en .ics'),
                onTap: () => _exportIcs(context, ref),
              ),
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedFile01,
                    color: Color(0xFF30B0C7),
                    size: 22),
                title: const Text('Exporter en .csv'),
                onTap: () => _exportCsv(context, ref),
              ),
              if (PlatformUtils.supportsPptExport)
                ListTile(
                  leading: const HugeIcon(
                      icon: HugeIcons.strokeRoundedPresentation01,
                      color: Color(0xFFFF9500),
                      size: 22),
                  title: const Text('Exporter planning PPT'),
                  onTap: () => _exportPpt(context, ref, settings),
                ),
            ],
          ),

          // Section Transfert & Sauvegarde config
          _buildSection(
            context,
            title: 'Transfert config',
            hugeIcon: HugeIcons.strokeRoundedQrCode,
            children: [
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedQrCode,
                    color: Color(0xFF5856D6),
                    size: 22),
                title: const Text('QR Code → Téléphone'),
                subtitle: const Text('Transférer la config vers l\'app mobile'),
                onTap: () => _showQrExport(context, ref, settings),
              ),
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedFileExport,
                    color: Color(0xFF007AFF),
                    size: 22),
                title: const Text('Exporter la configuration'),
                subtitle: const Text('Sauvegarder dans un fichier .json'),
                onTap: () => _exportConfig(context, ref, settings),
              ),
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedFileImport,
                    color: Color(0xFF34C759),
                    size: 22),
                title: const Text('Importer une configuration'),
                subtitle: const Text('Restaurer depuis un fichier .json'),
                onTap: () => _importConfig(context, ref),
              ),
            ],
          ),

          // Section Sauvegarde (kDrive)
          _buildSection(
            context,
            title: 'Sauvegarde',
            hugeIcon: HugeIcons.strokeRoundedCloudUpload,
            children: [
              ListTile(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCloudUpload,
                    color: Color(0xFF0098FF),
                    size: 22),
                title: const Text('Sauvegarde kDrive'),
                trailing: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: Colors.grey,
                    size: 18),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BackupSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),

          // Section Linux
          if (PlatformUtils.isLinux)
            _buildSection(
              context,
              title: 'Linux',
              hugeIcon: HugeIcons.strokeRoundedComputerDesk01,
              children: [
                ListTile(
                  leading: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCode,
                      color: Color(0xFF5856D6),
                      size: 22),
                  title: const Text('Script Python PPT'),
                  subtitle: Text(
                    settings?.pythonScriptPath ?? 'Non configuré',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _pickPythonScript(context, ref),
                ),
              ],
            ),

          // Synchronisation manuelle
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: syncState.isSyncing
                  ? null
                  : () => ref.read(syncNotifierProvider.notifier).syncAll(),
              icon: syncState.isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const HugeIcon(
                      icon: HugeIcons.strokeRoundedRefresh,
                      color: Color(0xFF007AFF),
                      size: 18),
              label: const Text('Synchroniser maintenant'),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSyncBanner(BuildContext context, SyncState syncState) {
    final isError = syncState.lastResult == SyncResult.failure;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: isError
                ? HugeIcons.strokeRoundedAlertCircle
                : HugeIcons.strokeRoundedCheckmarkCircle01,
            color: isError
                ? Theme.of(context).colorScheme.onErrorContainer
                : Theme.of(context).colorScheme.onPrimaryContainer,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isError ? 'Dernière sync échouée' : 'Synchronisé il y a peu',
            style: TextStyle(
              color: isError
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required dynamic hugeIcon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              HugeIcon(
                icon: hugeIcon,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _importIcs(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    final content = await file.readAsString();
    final events = IcsService.parseIcsFile(content);

    for (final event in events) {
      await DatabaseHelper.instance.insertEvent(event);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${events.length} événement(s) importé(s)'),
        ),
      );
    }
  }

  Future<void> _exportIcs(BuildContext context, WidgetRef ref) async {
    final events = await DatabaseHelper.instance.getEventsByDateRange(
      DateTime.now().subtract(const Duration(days: 30)),
      DateTime.now().add(const Duration(days: 365)),
    );

    final icsContent = IcsService.exportToIcs(events);

    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/unified_calendar_export.ics');
    await file.writeAsString(icsContent);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exporté : ${file.path}'),
        ),
      );
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final events = await DatabaseHelper.instance.getEventsByDateRange(
      DateTime.now().subtract(const Duration(days: 30)),
      DateTime.now().add(const Duration(days: 365)),
    );

    // Générer le CSV manuellement
    final lines = [
      'ID,Titre,Début,Fin,Journée entière,Lieu,Source',
      ...events.map((e) =>
          '${e.id},"${e.title.replaceAll('"', '""')}",${e.startDate},${e.endDate},${e.isAllDay ? 'Oui' : 'Non'},"${(e.location ?? '').replaceAll('"', '""')}",${e.source}'),
    ];
    final csv = lines.join('\n');

    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/unified_calendar_export.csv');
    await file.writeAsString(csv);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exporté : ${file.path}')),
      );
    }
  }

  Future<void> _exportPpt(
    BuildContext context,
    WidgetRef ref,
    AppSettings? settings,
  ) async {
    if (settings?.pythonScriptPath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Configurez le chemin du script Python dans les paramètres Linux',
            ),
          ),
        );
      }
      return;
    }

    try {
      final result = await Process.run(
        'python3',
        [settings!.pythonScriptPath!],
        runInShell: true,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.exitCode == 0
                  ? 'Planning PPT généré'
                  : 'Erreur : ${result.stderr}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _pickPythonScript(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['py'],
    );

    if (result != null && result.files.isNotEmpty) {
      await ref.read(settingsProvider.notifier).updatePreference(
            'python_script_path',
            result.files.first.path!,
          );
    }
  }

  /// Pré-sélections de villes suisses romandes & proches
  static const _cities = [
    {'name': 'Genève', 'lat': 46.2044, 'lon': 6.1432},
    {'name': 'Lausanne', 'lat': 46.5197, 'lon': 6.6323},
    {'name': 'Fribourg', 'lat': 46.8065, 'lon': 7.1620},
    {'name': 'Neuchâtel', 'lat': 46.9920, 'lon': 6.9319},
    {'name': 'Sion', 'lat': 46.2333, 'lon': 7.3667},
    {'name': 'Berne', 'lat': 46.9480, 'lon': 7.4474},
    {'name': 'Bâle', 'lat': 47.5596, 'lon': 7.5886},
    {'name': 'Zurich', 'lat': 47.3769, 'lon': 8.5417},
  ];

  Future<void> _detectLocation(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final dio = Dio();

      // Étape 1 : coordonnées via IP
      final ipResp = await dio.get(
        'https://ipapi.co/json/',
        options: Options(headers: {'User-Agent': 'MonAgenda/1.0'}),
      );
      if (ipResp.statusCode != 200 || ipResp.data is! Map) {
        throw Exception('Service indisponible');
      }
      final data = ipResp.data as Map;
      final lat = (data['latitude'] as num).toDouble();
      final lon = (data['longitude'] as num).toDouble();
      String city = data['city'] as String? ?? 'Ma position';

      // Étape 2 : nom français via Nominatim
      try {
        final nomResp = await dio.get(
          'https://nominatim.openstreetmap.org/reverse',
          queryParameters: {
            'lat': lat,
            'lon': lon,
            'format': 'json',
            'accept-language': 'fr',
            'zoom': 10,
          },
          options: Options(headers: {'User-Agent': 'MonAgenda/1.0'}),
        );
        if (nomResp.statusCode == 200 && nomResp.data is Map) {
          final addr = (nomResp.data as Map)['address'] as Map?;
          city = (addr?['city'] ?? addr?['town'] ?? addr?['village'] ?? city)
              as String;
        }
      } catch (_) {} // Garder le nom IP si Nominatim échoue

      ref.read(settingsProvider.notifier).updateWeatherLocation(
            city: city,
            latitude: lat,
            longitude: lon,
          );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Position détectée : $city'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de détecter la position'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _editWeatherCity(
      BuildContext context, WidgetRef ref, AppSettings? settings) {
    final cityCtrl =
        TextEditingController(text: settings?.weatherCity ?? 'Genève');
    final latCtrl = TextEditingController(
        text: (settings?.weatherLatitude ?? 46.2044).toString());
    final lonCtrl = TextEditingController(
        text: (settings?.weatherLongitude ?? 6.1432).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Localisation météo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bouton géolocalisation
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedGps01,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text('📍 Détecter ma position'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _detectLocation(context, ref);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ou choisir manuellement',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              // Sélections rapides
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _cities.map((c) {
                  final isSelected = cityCtrl.text == c['name'] as String;
                  return ActionChip(
                    label: Text(
                      c['name'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    onPressed: () {
                      cityCtrl.text = c['name'] as String;
                      latCtrl.text = (c['lat'] as double).toString();
                      lonCtrl.text = (c['lon'] as double).toString();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom de la ville',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lonCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latCtrl.text);
              final lon = double.tryParse(lonCtrl.text);
              if (lat != null && lon != null && cityCtrl.text.isNotEmpty) {
                ref.read(settingsProvider.notifier).updateWeatherLocation(
                      city: cityCtrl.text,
                      latitude: lat,
                      longitude: lon,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // ── QR Code export ────────────────────────────────────────────────
  void _showQrExport(
      BuildContext context, WidgetRef ref, AppSettings? settings) {
    if (settings == null) return;

    // Données JSON compactes directement
    final exportJson = settings.toExportJson();
    final exportStr = jsonEncode(exportJson);

    // Générer le QR comme image PNG en mémoire (évite les problèmes de
    // rendu CustomPaint sur Linux Desktop)
    final painter = QrPainter(
      data: exportStr,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF37352F),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF37352F),
      ),
      errorCorrectionLevel: QrErrorCorrectLevel.L,
      gapless: true,
    );
    final Future<ByteData?> qrFuture = painter.toImageData(520);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return AlertDialog(
          title: const Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedQrCode,
                color: Color(0xFF5856D6),
                size: 22,
              ),
              SizedBox(width: 10),
              Text('QR Code Configuration'),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 292,
                    height: 292,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FutureBuilder<ByteData?>(
                      future: qrFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError || snapshot.data == null) {
                          return Center(
                            child: Text(
                              'Erreur QR : ${snapshot.error ?? "données vides"}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        final pngBytes = snapshot.data!.buffer.asUint8List();
                        return Image.memory(
                          pngBytes,
                          width: 260,
                          height: 260,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFFF1F0ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📱 Sur votre téléphone :',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF37352F),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '1. Ouvrez MonAgenda\n'
                          '2. Paramètres → Importer config\n'
                          '3. Scannez ce QR code',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF9B9A97)
                                : const Color(0xFF787774),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Contient : identifiants, préférences, météo'
                    ' (${exportStr.length} octets)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF6B6B6B)
                          : const Color(0xFF9B9A97),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  // ── Export config en fichier JSON ────────────────────────────────
  Future<void> _exportConfig(
      BuildContext context, WidgetRef ref, AppSettings? settings) async {
    if (settings == null) return;

    try {
      final json = settings.toExportJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(json);

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/monagenda_config_$timestamp.json');
      await file.writeAsString(jsonStr);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Configuration exportée : ${file.path}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export : $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Import config depuis fichier JSON ───────────────────────────
  Future<void> _importConfig(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Importer une configuration',
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      final content = await File(path).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // Vérifier la version
      if (json['v'] != 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Format de configuration non reconnu'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final imported = AppSettings.fromExportJson(json);

      // Confirmation
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importer cette configuration ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imported.infomaniakUsername != null)
                Text('• Infomaniak : ${imported.infomaniakUsername}'),
              if (imported.notionApiKey != null) const Text('• Notion : ✓'),
              Text('• Thème : ${imported.theme}'),
              Text('• Vue par défaut : ${imported.defaultView}'),
              Text('• Météo : ${imported.weatherCity}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importer'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await ref.read(settingsProvider.notifier).importSettings(imported);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Configuration importée avec succès'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur import : $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
