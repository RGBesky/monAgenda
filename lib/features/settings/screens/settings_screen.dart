import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            icon: Icons.cloud_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
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
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
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
                leading: const Icon(Icons.integration_instructions_outlined),
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
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
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
                leading: const Icon(Icons.subscriptions_outlined),
                title: const Text('Abonnements .ics'),
                trailing: const Icon(Icons.chevron_right),
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
            icon: Icons.label_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Catégories et priorités'),
                trailing: const Icon(Icons.chevron_right),
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
            icon: Icons.notifications_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.alarm),
                title: const Text('Rappels et résumé matinal'),
                trailing: const Icon(Icons.chevron_right),
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
            icon: Icons.palette_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Thème et affichage'),
                subtitle: Text(
                  settings?.theme == 'light'
                      ? 'Mode clair'
                      : settings?.theme == 'dark'
                          ? 'Mode sombre'
                          : 'Automatique',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppearanceSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),

          // Section Import/Export
          _buildSection(
            context,
            title: 'Import / Export',
            icon: Icons.import_export,
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Importer un fichier .ics'),
                onTap: () => _importIcs(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Exporter en .ics'),
                onTap: () => _exportIcs(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Exporter en .csv'),
                onTap: () => _exportCsv(context, ref),
              ),
              if (PlatformUtils.supportsPptExport)
                ListTile(
                  leading: const Icon(Icons.slideshow_outlined),
                  title: const Text('Exporter planning PPT'),
                  onTap: () => _exportPpt(context, ref, settings),
                ),
            ],
          ),

          // Section Sauvegarde (kDrive)
          _buildSection(
            context,
            title: 'Sauvegarde',
            icon: Icons.backup_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Sauvegarde kDrive'),
                trailing: const Icon(Icons.chevron_right),
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
              icon: Icons.computer,
              children: [
                ListTile(
                  leading: const Icon(Icons.code),
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
                  : const Icon(Icons.sync),
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
          Icon(
            isError ? Icons.sync_problem : Icons.check_circle_outline,
            color: isError
                ? Theme.of(context).colorScheme.onErrorContainer
                : Theme.of(context).colorScheme.onPrimaryContainer,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isError
                ? 'Dernière sync échouée'
                : 'Synchronisé il y a peu',
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
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
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
}
