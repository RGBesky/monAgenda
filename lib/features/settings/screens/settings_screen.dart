import '../../../app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:dio/dio.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactory;
import 'dart:convert';
import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../services/ics_service.dart';
import '../../../services/sync_engine.dart';
import '../../../services/notion_service.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/magic_feedback_repository.dart';
import '../../../services/model_download_service.dart';
import '../../../services/magic_entry_service.dart';
import '../../../services/llama_service.dart';
import '../../../services/logger_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'connections_settings_screen.dart';
import 'tags_settings_screen.dart';
import 'notifications_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'backup_settings_screen.dart';
import 'import_config_screen.dart';
import 'system_logs_screen.dart';
import '../../../core/widgets/source_logos.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedSection = 0;

  static const _sectionLabels = [
    'Comptes',
    'Notifications',
    'Apparence',
    'IA & Modèle',
    'Avancé',
  ];
  static const _sectionIcons = [
    Icons.link,
    Icons.notifications_outlined,
    Icons.palette_outlined,
    Icons.smart_toy_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final syncState = ref.watch(syncNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop =
        Platform.isLinux || Platform.isMacOS || Platform.isWindows;

    if (isDesktop) {
      return _buildDesktopLayout(context, settings, syncState, isDark);
    }
    return _buildMobileLayout(context, settings, syncState, isDark);
  }

  // ── Desktop : NavigationRail + content panel ──────────────
  Widget _buildDesktopLayout(
      BuildContext context, dynamic settings, dynamic syncState, bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedSection,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => setState(() => _selectedSection = i),
            destinations: List.generate(
              _sectionLabels.length,
              (i) => NavigationRailDestination(
                icon: Icon(_sectionIcons[i]),
                selectedIcon: Icon(_sectionIcons[i]),
                label: Text(_sectionLabels[i]),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAppLogoHeader(isDark),
                ..._buildSectionContent(
                    context, _selectedSection, settings, syncState, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile : ExpansionTile ListView ───────────────────────
  Widget _buildMobileLayout(
      BuildContext context, dynamic settings, dynamic syncState, bool isDark) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          _buildAppLogoHeader(isDark),
          if (syncState.lastSyncedAt != null)
            _buildSyncBanner(context, syncState),
          for (int i = 0; i < _sectionLabels.length; i++)
            ExpansionTile(
              leading: Icon(_sectionIcons[i], size: 20),
              title: Text(_sectionLabels[i]),
              initiallyExpanded: i == 0,
              children:
                  _buildSectionContent(context, i, settings, syncState, isDark),
            ),
        ],
      ),
    );
  }

  /// Build content widgets for a given section index.
  List<Widget> _buildSectionContent(BuildContext context, int section,
      dynamic settings, dynamic syncState, bool isDark) {
    switch (section) {
      case 0: // Comptes
        return _buildAccountsContent(context, settings);
      case 1: // Notifications
        return _buildNotificationsContent(context, settings);
      case 2: // Apparence
        return _buildAppearanceContent(context, settings, isDark);
      case 3: // IA & Modèle
        return _buildAiContent(context);
      case 4: // Avancé
        return _buildAdvancedContent(context, settings, syncState, isDark);
      default:
        return [];
    }
  }

  List<Widget> _buildAccountsContent(BuildContext context, dynamic settings) {
    return [
      _buildSection(
        context,
        title: 'Connexions',
        hugeIcon: HugeIcons.strokeRoundedLink01,
        children: [
          ListTile(
            leading: SourceLogos.infomaniak(size: 24),
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
            leading: SourceLogos.notion(
              size: 24,
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
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
      // Tags section also belongs to Accounts
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
    ];
  }

  List<Widget> _buildNotificationsContent(
      BuildContext context, dynamic settings) {
    return [
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
    ];
  }

  List<Widget> _buildAppearanceContent(
      BuildContext context, dynamic settings, bool isDark) {
    return [
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
    ];
  }

  List<Widget> _buildAiContent(BuildContext context) {
    return [
      // ── Choix du modèle IA ──
      _buildSection(
        context,
        title: 'Choix du modèle',
        hugeIcon: HugeIcons.strokeRoundedAiBrain01,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final selected = ModelDownloadService.instance.selectedModel;
              return RadioGroup<MagicModelChoice>(
                groupValue: selected,
                onChanged: (val) async {
                  if (val == null) return;
                  ModelDownloadService.instance.selectedModel = val;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('magic_model_choice', val.name);
                  // Force le rechargement du modèle au prochain usage
                  await LlamaService.instance.dispose();
                  ref.invalidate(modelDownloadStatusProvider);
                },
                child: Column(
                  children: MagicModelChoice.values.map((choice) {
                    final isSelected = choice == selected;
                    return RadioListTile<MagicModelChoice>(
                      value: choice,
                      title: Text(choice.label),
                      subtitle: Text(choice.subtitle),
                      secondary: isSelected
                          ? const HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                              color: Colors.green,
                              size: 22)
                          : null,
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),

      // ── Statut du modèle IA ──
      _buildSection(
        context,
        title: 'Modèle IA local',
        hugeIcon: HugeIcons.strokeRoundedAiBrain01,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final modelStatus = ref.watch(modelDownloadStatusProvider);
              final downloadProgress = ref.watch(modelDownloadProgressProvider);

              return modelStatus.when(
                data: (status) {
                  switch (status) {
                    case ModelStatus.ready:
                      return _buildModelReady(context, ref);
                    case ModelStatus.downloading:
                      return _buildModelDownloading(context, downloadProgress);
                    case ModelStatus.error:
                      return _buildModelError(context, ref);
                    case ModelStatus.notDownloaded:
                      return _buildModelNotInstalled(context, ref);
                  }
                },
                loading: () => const ListTile(
                  leading: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  title: Text('Vérification du modèle…'),
                ),
                error: (e, _) => ListTile(
                  leading: const HugeIcon(
                      icon: HugeIcons.strokeRoundedAlert02,
                      color: Colors.red,
                      size: 22),
                  title: const Text('Erreur de vérification'),
                  subtitle: Text('$e'),
                ),
              );
            },
          ),
        ],
      ),

      // ── Corrections IA (feedback loop) ──
      _buildSection(
        context,
        title: 'Corrections IA',
        hugeIcon: HugeIcons.strokeRoundedAiChat02,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final feedbackCount =
                  ref.watch(magicFeedbackCountProvider).valueOrNull ?? 0;
              return Column(
                children: [
                  ListTile(
                    leading: const HugeIcon(
                        icon: HugeIcons.strokeRoundedAiChat02,
                        color: Color(0xFFFFBD98),
                        size: 22),
                    title: const Text('Corrections IA'),
                    subtitle: Text(
                        '$feedbackCount correction${feedbackCount > 1 ? 's' : ''} enregistrée${feedbackCount > 1 ? 's' : ''}'),
                  ),
                  ListTile(
                    leading: const HugeIcon(
                        icon: HugeIcons.strokeRoundedFileExport,
                        color: Color(0xFF34C759),
                        size: 22),
                    title: const Text('Exporter corrections'),
                    subtitle: const Text('Fichier CSV local'),
                    onTap: feedbackCount > 0
                        ? () => _exportMagicFeedback(context, ref)
                        : null,
                  ),
                  ListTile(
                    leading: const HugeIcon(
                        icon: HugeIcons.strokeRoundedDelete02,
                        color: Color(0xFFFF3B30),
                        size: 22),
                    title: const Text('Vider les corrections'),
                    onTap: feedbackCount > 0
                        ? () => _clearMagicFeedback(context, ref)
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),

      // ── Zone de danger ──
      _buildSection(
        context,
        title: 'Zone de danger',
        hugeIcon: HugeIcons.strokeRoundedAlert02,
        titleColor: const Color(0xFFFF3B30),
        children: [
          ListTile(
            leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete04,
                color: Color(0xFFFF3B30),
                size: 22),
            title: const Text('Réinitialiser l\'application',
                style: TextStyle(color: Color(0xFFFF3B30))),
            subtitle: const Text(
                'Supprime toutes les données, paramètres et fichiers locaux'),
            onTap: () => _confirmResetApp(context, ref),
          ),
        ],
      ),
    ];
  }

  // ── Modèle installé et prêt ──
  Widget _buildModelReady(BuildContext context, WidgetRef ref) {
    return FutureBuilder<double?>(
      future: ModelDownloadService.instance.modelSizeMb,
      builder: (context, snapshot) {
        final sizeMb = snapshot.data;
        final choice = ModelDownloadService.instance.selectedModel;
        return Column(
          children: [
            ListTile(
              leading: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                  color: Colors.green,
                  size: 22),
              title: Text(choice.label),
              subtitle: Text(
                'Installé${sizeMb != null ? ' · ${sizeMb.toStringAsFixed(0)} Mo' : ''}\n'
                'Inférence 100% locale · CPU · Multilingue (FR)',
              ),
            ),
            ListTile(
              leading: const HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  color: Color(0xFFFF3B30),
                  size: 22),
              title: const Text('Supprimer le modèle'),
              subtitle: const Text('Libérer l\'espace disque'),
              onTap: () => _confirmDeleteModel(context, ref),
            ),
          ],
        );
      },
    );
  }

  // ── Modèle en cours de téléchargement ──
  Widget _buildModelDownloading(
      BuildContext context, AsyncValue<double> progress) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2)),
            title: const Text('Téléchargement en cours…'),
            subtitle: Text(
                '${ModelDownloadService.instance.selectedModel.label} · ~${ModelDownloadService.instance.selectedModel.approxSizeMb} Mo'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: progress.when(
              data: (v) => Column(
                children: [
                  LinearProgressIndicator(value: v),
                  const SizedBox(height: 4),
                  Text('${(v * 100).toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) =>
                  Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Modèle pas encore installé ──
  Widget _buildModelNotInstalled(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: const HugeIcon(
              icon: HugeIcons.strokeRoundedDownload02,
              color: Color(0xFFFFBD98),
              size: 22),
          title: Text(ModelDownloadService.instance.selectedModel.label),
          subtitle: Text(
            'Non installé · ~${ModelDownloadService.instance.selectedModel.approxSizeMb} Mo\n'
            'Requis pour la saisie magique avancée.\n'
            'Sans modèle, seul le parsing basique (regex) est utilisé.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _downloadModelFromSettings(context, ref),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Télécharger depuis HuggingFace'),
            ),
          ),
        ),
      ],
    );
  }

  // ── Modèle en erreur ──
  Widget _buildModelError(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const ListTile(
          leading: HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              color: Colors.red,
              size: 22),
          title: Text('Erreur modèle IA'),
          subtitle:
              Text('Le téléchargement a échoué ou le fichier est corrompu.'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _downloadModelFromSettings(context, ref),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer le téléchargement'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadModelFromSettings(
      BuildContext context, WidgetRef ref) async {
    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.smart_toy_outlined,
            color: Color(0xFFFFBD98), size: 40),
        title: const Text('Télécharger le modèle IA ?'),
        content: Text(
          '${ModelDownloadService.instance.selectedModel.label} (Q4_K_M)\n'
          '~${ModelDownloadService.instance.selectedModel.approxSizeMb} Mo à télécharger depuis HuggingFace.\n\n'
          'Modèle Qwen2.5 multilingue (français natif) optimisé pour '
          'l\'extraction JSON structurée. Tout reste 100% local.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Télécharger'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Lancer le téléchargement
    final success = await ref.read(magicEntryProvider.notifier).downloadModel();
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Modèle IA installé avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✗ Échec du téléchargement. Vérifiez votre connexion.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteModel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le modèle IA ?'),
        content: const Text(
          'Tous les modèles IA seront supprimés du disque.\n'
          'Vous pourrez les re-télécharger à tout moment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(modelDownloadStatusProvider.notifier).deleteModel();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modèle IA supprimé.'),
          ),
        );
      }
    }
  }

  List<Widget> _buildAdvancedContent(
      BuildContext context, dynamic settings, dynamic syncState, bool isDark) {
    return [
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
            subtitle: const Text('Transférer la config (chiffré AES-256)'),
            onTap: () => _showQrExport(context, ref, settings),
          ),
          ListTile(
            leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedSmartPhone01,
                color: Color(0xFFFF9500),
                size: 22),
            title: const Text('Scanner / Importer config'),
            subtitle: const Text('Importer via QR code ou données chiffrées'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ImportConfigScreen(),
              ),
            ),
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

      // Section Logs système
      _buildSection(
        context,
        title: 'Diagnostic',
        hugeIcon: HugeIcons.strokeRoundedAlert02,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final errorCount =
                  ref.watch(unreadErrorCountProvider).valueOrNull ?? 0;
              return ListTile(
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedAlert02,
                      color: Color(0xFF8E8E93),
                      size: 22,
                    ),
                    if (errorCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            errorCount > 9 ? '9+' : '$errorCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: const Text('Logs système'),
                subtitle: Text(
                  errorCount > 0
                      ? '$errorCount erreur${errorCount > 1 ? 's' : ''} non lue${errorCount > 1 ? 's' : ''}'
                      : 'Aucune erreur',
                ),
                trailing: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: Colors.grey,
                  size: 18,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SystemLogsScreen(),
                  ),
                ),
              );
            },
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
                settings?.pythonScriptPath ?? 'Auto-détecté (bundlé)',
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: Colors.grey,
                  size: 18),
              onTap: () => _pickPythonScript(context, ref),
            ),
          ],
        ),

      // Section Mode hors-ligne & Synchronisation
      _buildSection(
        context,
        title: 'Synchronisation',
        hugeIcon: HugeIcons.strokeRoundedRefresh,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final forceOffline = ref.watch(forceOfflineProvider);
              final pendingCount =
                  ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

              return Column(
                children: [
                  SwitchListTile(
                    secondary: HugeIcon(
                      icon: HugeIcons.strokeRoundedWifiDisconnected04,
                      color: forceOffline
                          ? const Color(0xFFFF9500)
                          : const Color(0xFF8E8E93),
                      size: 22,
                    ),
                    title: const Text('Mode hors-ligne'),
                    subtitle: Text(
                      forceOffline
                          ? 'Actif — les modifications sont empilées localement'
                          : 'Désactivé — sync automatique',
                    ),
                    value: forceOffline,
                    onChanged: (_) =>
                        ref.read(forceOfflineProvider.notifier).toggle(),
                  ),
                  if (forceOffline && pendingCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Builder(
                        builder: (context) {
                          final isDarkBanner =
                              Theme.of(context).brightness == Brightness.dark;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDarkBanner
                                  ? const Color(0xFF3D2200)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedCloudUpload,
                                  color: isDarkBanner
                                      ? const Color(0xFFFFB74D)
                                      : const Color(0xFFFF9500),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$pendingCount modification${pendingCount > 1 ? 's' : ''} en attente',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDarkBanner
                                          ? const Color(0xFFFFB74D)
                                          : const Color(0xFFE65100),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (forceOffline && pendingCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: syncState.isSyncing
                              ? null
                              : () => ref
                                  .read(syncNotifierProvider.notifier)
                                  .pushAndSync(),
                          icon: syncState.isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(
                            syncState.isSyncing
                                ? 'Envoi en cours…'
                                : 'Pousser les modifications',
                          ),
                        ),
                      ),
                    ),
                  if (!forceOffline)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: OutlinedButton.icon(
                        onPressed: syncState.isSyncing
                            ? null
                            : () => ref
                                .read(syncNotifierProvider.notifier)
                                .syncAll(),
                        icon: syncState.isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const HugeIcon(
                                icon: HugeIcons.strokeRoundedRefresh,
                                color: Color(0xFF007AFF),
                                size: 18),
                        label: const Text('Synchroniser maintenant'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),

      // Section Raccourcis clavier (Desktop uniquement)
      if (PlatformUtils.isDesktop)
        _buildSection(
          context,
          title: 'Raccourcis clavier',
          hugeIcon: HugeIcons.strokeRoundedKeyboard,
          children: [
            ListTile(
              leading: const HugeIcon(
                  icon: HugeIcons.strokeRoundedKeyboard,
                  color: Color(0xFF5856D6),
                  size: 22),
              title: const Text('Voir les raccourcis'),
              subtitle: const Text('Ctrl+N, Ctrl+K, Ctrl+F…'),
              trailing: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: Colors.grey,
                  size: 18),
              onTap: () => _showKeyboardShortcutsDialog(context),
            ),
          ],
        ),

      const SizedBox(height: 32),
    ];
  }

  Widget _buildAppLogoHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.grey)
                      .withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'logo_pack/logo_color_128x128.png',
                width: 80,
                height: 80,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'monAgenda',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Calendrier personnel unifié',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
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
          Expanded(
            child: Text(
              isError ? 'Dernière sync échouée' : 'Synchronisé il y a peu',
              style: TextStyle(
                color: isError
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
    Color? titleColor,
  }) {
    final effectiveColor = titleColor ?? Theme.of(context).colorScheme.primary;
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
                color: effectiveColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: effectiveColor,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('${events.length} événement(s) importé(s)'),
        ),
      );
    }
  }

  /// Sanitise une cellule CSV pour empêcher l'injection de formule
  /// (=, +, -, @, \t, \r au début → préfixe single quote).
  static String _sanitizeCsvCell(String value) {
    if (value.isNotEmpty && RegExp(r'^[=+\-@\t\r]').hasMatch(value)) {
      return "'$value";
    }
    return value;
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
      UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
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
      ...events.map((e) {
        final title = _sanitizeCsvCell(e.title).replaceAll('"', '""');
        final location =
            _sanitizeCsvCell(e.location ?? '').replaceAll('"', '""');
        return '${e.id},"$title",${e.startDate},${e.endDate},${e.isAllDay ? 'Oui' : 'Non'},"$location",${e.source}';
      }),
    ];
    final csv = lines.join('\n');

    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/unified_calendar_export.csv');
    await file.writeAsString(csv);

    if (context.mounted) {
      UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Exporté : ${file.path}')),
      );
    }
  }

  /// Extrait la valeur textuelle d'une propriété Notion brute (depuis l'API).
  /// Supporte : select, multi_select, status, rich_text, title, formula,
  /// number, checkbox, url, email, phone_number, rollup.
  String _extractNotionPropertyValue(Map<String, dynamic> prop) {
    final type = prop['type'] as String?;
    switch (type) {
      case 'select':
        return (prop['select'] as Map<String, dynamic>?)?['name'] as String? ??
            '';
      case 'multi_select':
        final ms = (prop['multi_select'] as List?) ?? [];
        return ms.map((e) => (e as Map)['name'] as String? ?? '').join(', ');
      case 'status':
        return (prop['status'] as Map<String, dynamic>?)?['name'] as String? ??
            '';
      case 'rich_text':
      case 'title':
        final list = (prop['rich_text'] ?? prop['title']) as List?;
        if (list == null || list.isEmpty) return '';
        return list
            .map((item) => (item as Map)['plain_text'] as String? ?? '')
            .join();
      case 'formula':
        final f = prop['formula'] as Map<String, dynamic>?;
        if (f == null) return '';
        final fType = f['type'] as String?;
        if (fType == 'string') return f['string'] as String? ?? '';
        if (fType == 'number') return f['number']?.toString() ?? '';
        return '';
      case 'number':
        return prop['number']?.toString() ?? '';
      case 'checkbox':
        return prop['checkbox'] == true ? 'true' : 'false';
      case 'url':
        return prop['url'] as String? ?? '';
      case 'email':
        return prop['email'] as String? ?? '';
      case 'phone_number':
        return prop['phone_number'] as String? ?? '';
      case 'rollup':
        final r = prop['rollup'] as Map<String, dynamic>?;
        if (r == null) return '';
        if (r['type'] == 'number') return r['number']?.toString() ?? '';
        if (r['type'] == 'array') {
          return ((r['array'] as List?) ?? [])
              .map((e) => e is Map<String, dynamic>
                  ? _extractNotionPropertyValue(e)
                  : e.toString())
              .where((s) => s.isNotEmpty)
              .join(', ');
        }
        return '';
      default:
        return '';
    }
  }

  /// Résout le chemin du script Python bundlé dans le projet.
  String _resolveScriptPath() {
    // En dev : chemin relatif au workspace
    final candidates = [
      // Dev (lancé via flutter run depuis le project root)
      '${Directory.current.path}/assets/calendar_export/generate_calendar_ppt.py',
      // Installé à côté du binaire
      '${Platform.resolvedExecutable.replaceAll(RegExp(r'/[^/]+$'), '')}/data/flutter_assets/assets/calendar_export/generate_calendar_ppt.py',
      // Fallback : home dir
      '${Platform.environment['HOME']}/VSCode/monAgenda/assets/calendar_export/generate_calendar_ppt.py',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return candidates
        .first; // on retourne le premier quand même (l'erreur viendra de Python)
  }

  String _resolveAssetsDir() {
    final script = _resolveScriptPath();
    return File(script).parent.path;
  }

  /// Résout le chemin de l'interpréteur Python (venv d'abord, puis système).
  String _resolvePythonPath() {
    final assetsDir = _resolveAssetsDir();
    final venvPython = '$assetsDir/.venv/bin/python3';
    if (File(venvPython).existsSync()) return venvPython;
    return 'python3'; // fallback système
  }

  Future<void> _exportPpt(
    BuildContext context,
    WidgetRef ref,
    AppSettings? settings,
  ) async {
    final pythonPath = _resolvePythonPath();

    // 1. Vérifier que python3 est disponible
    try {
      final pythonCheck = await Process.run(pythonPath, ['--version']);
      if (pythonCheck.exitCode != 0) {
        if (context.mounted) {
          UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text(
                  'Python 3 non trouvé. Installez-le avec : sudo apt install python3'),
            ),
          );
        }
        return;
      }
    } catch (_) {
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Python 3 non trouvé'),
          ),
        );
      }
      return;
    }

    // 2. Vérifier les dépendances Python
    final depCheck = await Process.run(
      pythonPath,
      ['-c', 'import pptx, pandas'],
    );
    if (depCheck.exitCode != 0) {
      if (context.mounted) {
        final install = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Dépendances manquantes'),
            content: const Text(
              'Les packages python-pptx et pandas sont requis.\n\n'
              'Installer maintenant ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Installer'),
              ),
            ],
          ),
        );

        if (install == true) {
          if (context.mounted) {
            UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Installation en cours…'),
                duration: Duration(seconds: 10),
              ),
            );
          }
          final pipResult = await Process.run(
            pythonPath,
            ['-m', 'pip', 'install', 'python-pptx', 'pandas'],
          );
          if (pipResult.exitCode != 0) {
            if (context.mounted) {
              UnifiedCalendarApp.scaffoldMessengerKey.currentState
                  ?.hideCurrentSnackBar();
              UnifiedCalendarApp.scaffoldMessengerKey.currentState
                  ?.showSnackBar(
                const SnackBar(
                  content: Text('Échec installation des dépendances Python'),
                ),
              );
              AppLogger.instance
                  .error('Settings', 'pip install failed: ${pipResult.stderr}');
            }
            return;
          }
          if (context.mounted) {
            UnifiedCalendarApp.scaffoldMessengerKey.currentState
                ?.hideCurrentSnackBar();
          }
        } else {
          return;
        }
      }
    }

    // 3. Extraire automatiquement les événements "garde" depuis Notion (API directe)
    // Chercher la base Notion dont le nom contient "garde"
    final notionDbs = await DatabaseHelper.instance.getNotionDatabases();
    final gardeDb = notionDbs.cast<dynamic>().firstWhere(
          (db) => db.name.toLowerCase().contains('garde'),
          orElse: () => null,
        );

    String csvPath;
    if (gardeDb != null) {
      // ── Requêter l'API Notion directement pour avoir TOUTES les propriétés ──
      // (les événements locaux perdent les propriétés non-mappées comme "Parent")
      final csvLines = <String>['Date début,Parent,Type de garde'];
      bool apiSuccess = false;

      try {
        final apiKey = settings?.notionApiKey ?? '';
        if (apiKey.isNotEmpty) {
          final notion = NotionService();
          notion.setCredentials(apiKey: apiKey);

          final pages = await notion.queryDatabase(
            databaseId: gardeDb.effectiveSourceId,
            dateProperty: gardeDb.startDateProperty,
          );

          for (final page in pages) {
            final props = page['properties'] as Map<String, dynamic>? ?? {};

            // Extraire la date (chercher la propriété date configurée)
            DateTime? date;
            if (gardeDb.startDateProperty != null) {
              final dateProp = props[gardeDb.startDateProperty];
              if (dateProp != null) {
                final dateObj = dateProp['date'] as Map<String, dynamic>?;
                final startStr = dateObj?['start'] as String?;
                if (startStr != null) {
                  date = DateTime.tryParse(startStr);
                }
              }
            }
            // Fallback : chercher la première propriété date
            if (date == null) {
              for (final entry in props.entries) {
                final val = entry.value;
                if (val is Map<String, dynamic> &&
                    val['type'] == 'date' &&
                    val['date'] != null) {
                  final startStr = (val['date'] as Map)['start'] as String?;
                  if (startStr != null) date = DateTime.tryParse(startStr);
                  break;
                }
              }
            }
            if (date == null) continue;

            final dateStr = '${date.day.toString().padLeft(2, '0')}/'
                '${date.month.toString().padLeft(2, '0')}/'
                '${date.year}';

            // Extraire "Parent" : chercher une propriété nommée "Parent"
            // (select, multi_select, rich_text, formula, etc.)
            String parent = '';
            for (final key in ['Parent', 'parent', 'PARENT']) {
              final parentProp = props[key];
              if (parentProp != null && parentProp is Map<String, dynamic>) {
                parent = _extractNotionPropertyValue(parentProp);
                if (parent.isNotEmpty) break;
              }
            }

            // Extraire "Type de garde" : en priorité la propriété statusProperty,
            // sinon chercher "Type de garde", "Type", etc.
            String type = '';
            if (gardeDb.statusProperty != null) {
              final statusProp = props[gardeDb.statusProperty];
              if (statusProp != null && statusProp is Map<String, dynamic>) {
                type = _extractNotionPropertyValue(statusProp);
              }
            }
            if (type.isEmpty) {
              for (final key in [
                'Type de garde',
                'Type',
                'type de garde',
                'Garde'
              ]) {
                final typeProp = props[key];
                if (typeProp != null && typeProp is Map<String, dynamic>) {
                  type = _extractNotionPropertyValue(typeProp);
                  if (type.isNotEmpty) break;
                }
              }
            }

            final parentCsv = _sanitizeCsvCell(parent).replaceAll('"', '""');
            final typeCsv = _sanitizeCsvCell(type).replaceAll('"', '""');
            csvLines.add('$dateStr,"$parentCsv","$typeCsv"');
          }

          apiSuccess = csvLines.length > 1; // au moins 1 ligne de données
        }
      } catch (_) {
        // Si l'API échoue, on tente le fallback local
        apiSuccess = false;
      }

      // ── Fallback : extraction depuis les événements locaux ──
      if (!apiSuccess) {
        csvLines.clear();
        csvLines.add('Date début,Parent,Type de garde');

        final gardeEvents = await DatabaseHelper.instance
            .getEventsByCalendarId(gardeDb.effectiveSourceId);

        if (gardeEvents.isEmpty) {
          if (context.mounted) {
            UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content:
                    Text('Aucun événement trouvé dans le calendrier de garde'),
              ),
            );
          }
          return;
        }

        for (final e in gardeEvents) {
          final dateStr = '${e.startDate.day.toString().padLeft(2, '0')}/'
              '${e.startDate.month.toString().padLeft(2, '0')}/'
              '${e.startDate.year}';

          // 1. Chercher le parent dans les tags
          String parent = e.tags
                  .map((t) => t.name)
                  .where((n) =>
                      n.toLowerCase() == 'robert' ||
                      n.toLowerCase() == 'justine')
                  .firstOrNull ??
              '';
          // 2. Si pas dans les tags, chercher dans le titre
          if (parent.isEmpty) {
            final titleLow = e.title.toLowerCase();
            if (titleLow.contains('robert')) {
              parent = 'Robert';
            } else if (titleLow.contains('justine')) {
              parent = 'Justine';
            }
          }
          // 3. Si pas dans le titre, chercher dans la description (📎 Parent : …)
          if (parent.isEmpty && e.description != null) {
            final match =
                RegExp(r'📎\s*Parent\s*:\s*(.+)', caseSensitive: false)
                    .firstMatch(e.description!);
            if (match != null) parent = match.group(1)!.trim();
          }

          // Type de garde
          final typeFromStatus = (e.status ?? '').trim();
          final type = typeFromStatus.isNotEmpty
              ? typeFromStatus
              : (e.tags
                      .map((t) => t.name)
                      .where((n) =>
                          n.toLowerCase() != 'robert' &&
                          n.toLowerCase() != 'justine')
                      .firstOrNull ??
                  '');

          final parentCsv = _sanitizeCsvCell(parent).replaceAll('"', '""');
          final typeCsv = _sanitizeCsvCell(type).replaceAll('"', '""');
          csvLines.add('$dateStr,"$parentCsv","$typeCsv"');
        }
      }

      if (csvLines.length <= 1) {
        if (context.mounted) {
          UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Aucune donnée de garde trouvée'),
            ),
          );
        }
        return;
      }

      final tmpDir = await getApplicationCacheDirectory();
      final csvFile = File('${tmpDir.path}/garde_auto_export.csv');
      await csvFile.writeAsString(csvLines.join('\n'));
      csvPath = csvFile.path;
    } else {
      // Fallback : demander le fichier CSV manuellement
      final csvResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Choisir le fichier planning CSV',
      );
      if (csvResult == null || csvResult.files.isEmpty) return;
      csvPath = csvResult.files.first.path!;
    }

    // 4. Demander la date de début (défaut : 1er du mois courant)
    if (!context.mounted) return;
    final now = DateTime.now();
    final defaultStart =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final startDate = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: defaultStart);
        return AlertDialog(
          title: const Text('Date de début'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'AAAA-MM-JJ',
              helperText:
                  'Seuls les jours à partir de cette date seront générés',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Générer'),
            ),
          ],
        );
      },
    );

    if (startDate == null) return;

    // 5. Déterminer les chemins
    final scriptPath = settings?.pythonScriptPath ?? _resolveScriptPath();

    // Validation sécurité du chemin script
    if (!scriptPath.endsWith('.py') ||
        scriptPath.contains('..') ||
        !File(scriptPath).existsSync()) {
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Chemin du script Python invalide ou introuvable'),
          ),
        );
      }
      return;
    }

    final assetsDir = _resolveAssetsDir();
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final outputPath = '${dir.path}/Calendrier_Garde.pptx';

    // 6. Afficher le chargement
    if (context.mounted) {
      UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Génération du planning…'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    // 7. Exécuter le script
    try {
      final result = await Process.run(
        pythonPath,
        [
          scriptPath,
          '--csv',
          csvPath,
          '--output',
          outputPath,
          '--assets',
          assetsDir,
          '--start-from',
          startDate,
        ],
      );

      if (!context.mounted) return;
      UnifiedCalendarApp.scaffoldMessengerKey.currentState
          ?.hideCurrentSnackBar();

      if (result.exitCode == 0) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('✅ Planning généré : $outputPath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Ouvrir',
              textColor: Colors.white,
              onPressed: () {
                Process.run('xdg-open', [outputPath]);
              },
            ),
          ),
        );
      } else {
        final stderr = result.stderr.toString().trim();
        final stdout = result.stdout.toString().trim();
        AppLogger.instance.error('Settings',
            'Python script failed: ${stderr.isNotEmpty ? stderr : stdout}');
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur lors de la génération du planning'),
            duration: Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState
            ?.hideCurrentSnackBar();
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('❌ Erreur : $e'),
          ),
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
      } catch (e) {
        AppLogger.instance
            .warning('Settings', 'Nominatim reverse-geocoding failed: $e');
      } // Garder le nom IP si Nominatim échoue

      ref.read(settingsProvider.notifier).updateWeatherLocation(
            city: city,
            latitude: lat,
            longitude: lon,
          );

      if (context.mounted) {
        Navigator.pop(context);
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('📍 Position détectée : $city'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Impossible de détecter la position'),
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

  // ── QR Code export (chiffré AES-256) ──────────────────────────────
  void _showQrExport(
      BuildContext context, WidgetRef ref, AppSettings? settings) {
    if (settings == null) return;

    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedQrCode,
              color: Color(0xFF5856D6),
              size: 22,
            ),
            SizedBox(width: 10),
            Text('Chiffrer la configuration'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Saisissez un mot de passe pour chiffrer le QR Code.\n'
              'Vous en aurez besoin pour importer sur un autre appareil.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (passwordController.text.isEmpty) {
                UnifiedCalendarApp.scaffoldMessengerKey.currentState
                    ?.showSnackBar(
                  const SnackBar(content: Text('Le mot de passe est requis')),
                );
                return;
              }
              if (passwordController.text.length < 6) {
                UnifiedCalendarApp.scaffoldMessengerKey.currentState
                    ?.showSnackBar(
                  const SnackBar(content: Text('Minimum 6 caractères')),
                );
                return;
              }
              if (passwordController.text != confirmController.text) {
                UnifiedCalendarApp.scaffoldMessengerKey.currentState
                    ?.showSnackBar(
                  const SnackBar(
                      content: Text('Les mots de passe ne correspondent pas')),
                );
                return;
              }
              Navigator.pop(ctx);
              // ignore: unawaited_futures
              _showEncryptedQrCode(
                  context, settings, passwordController.text, ref);
            },
            child: const Text('Générer le QR'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEncryptedQrCode(BuildContext context, AppSettings settings,
      String password, WidgetRef ref) async {
    // Récupérer les tags personnalisés depuis la DB
    final tags = await DatabaseHelper.instance.getAllTags();
    // Données chiffrées AES-256 avec tags
    final encryptedStr = settings.toEncryptedExportString(password, tags: tags);

    // Limite QR code : ~2,953 octets binaires en version 40, correction L.
    // Au-delà, QrPainter lance une exception synchrone.
    const maxQrDataLength = 2900;
    if (encryptedStr.length > maxQrDataLength) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
              SizedBox(width: 10),
              Text('Données trop volumineuses'),
            ],
          ),
          content: Text(
            'La configuration chiffrée fait ${encryptedStr.length} octets, '
            'ce qui dépasse la capacité maximale d\u2019un QR code ($maxQrDataLength).\n\n'
            'Utilisez l\u2019export fichier JSON à la place, ou réduisez le nombre de tags personnalisés.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
      return;
    }

    // Génération du QR code avec gestion d'erreur
    QrPainter painter;
    try {
      painter = QrPainter(
        data: encryptedStr,
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
    } catch (e) {
      if (!context.mounted) return;
      UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Erreur QR : $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final Future<ByteData?> qrFuture = painter.toImageData(520);

    if (!context.mounted) return;
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
                  // Indicateur de sécurité
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFF34C759).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, color: Color(0xFF34C759), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Chiffré AES-256',
                          style: TextStyle(
                            color: Color(0xFF34C759),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          '3. Scannez ce QR code\n'
                          '4. Saisissez votre mot de passe',
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
                    '🔒 Données chiffrées'
                    ' (${encryptedStr.length} octets)',
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
      final tags = await DatabaseHelper.instance.getAllTags();
      final json = settings.toExportJson(tags: tags);
      // Retirer les credentials sensibles du fichier non-chiffré
      json.remove('ik_user');
      json.remove('ik_pass');
      json.remove('ik_cal');
      json.remove('notion');
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
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('✅ Configuration exportée : ${file.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Erreur export : $e'),
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

      // Vérifier la version (accepter v1 et v2)
      final version = json['v'] as int?;
      if (version == null || version < 1 || version > 2) {
        if (context.mounted) {
          UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Format de configuration non reconnu'),
            ),
          );
        }
        return;
      }

      final imported = AppSettings.fromExportJson(json);
      final exportedTags = AppSettings.parseExportedTags(json);

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
              if (exportedTags.isNotEmpty)
                Text(
                    '• Tags : ${exportedTags.length} tag${exportedTags.length > 1 ? 's' : ''} personnalisé${exportedTags.length > 1 ? 's' : ''}'),
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
        await ref
            .read(settingsProvider.notifier)
            .importSettings(imported, tags: exportedTags);
        if (context.mounted) {
          UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('✅ Configuration importée avec succès'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Erreur import : $e'),
          ),
        );
      }
    }
  }

  // ── IA Feedback ────────────────────────────────────────────

  Future<void> _exportMagicFeedback(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(magicFeedbackRepositoryProvider);
      final csv = await repo.exportToCsv();
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/magic_feedback_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Export → ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Erreur export feedback : $e')),
        );
      }
    }
  }

  Future<void> _clearMagicFeedback(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vider les corrections ?'),
        content: const Text(
            'Toutes les corrections IA seront supprimées. Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vider', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(magicFeedbackRepositoryProvider).clear();
      ref.invalidate(magicFeedbackCountProvider);
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Corrections supprimées')),
        );
      }
    }
  }

  void _showKeyboardShortcutsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedKeyboard,
              color: Color(0xFF5856D6),
              size: 22,
            ),
            SizedBox(width: 10),
            Text('Raccourcis clavier'),
          ],
        ),
        children: [
          for (final shortcut in AppShellShortcuts.all)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shortcut.$1,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      shortcut.$2,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Double confirmation avant réinitialisation complète de l'app.
  Future<void> _confirmResetApp(BuildContext context, WidgetRef ref) async {
    // ── Dialogue 1 : avertissement ──
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            color: Color(0xFFFF3B30),
            size: 32),
        title: const Text('Réinitialiser l\'application ?'),
        content: const Text(
          'Cette action supprimera définitivement :\n'
          '• Tous vos événements locaux\n'
          '• Vos paramètres et préférences\n'
          '• Vos connexions (Infomaniak, Notion, ICS)\n'
          '• Les logs et certificats\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;

    // ── Dialogue 2 : confirmation finale ──
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Êtes-vous absolument sûr ?'),
        content: const Text(
          'Tapez sur « Réinitialiser » pour confirmer.\n'
          'Toutes les données seront perdues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
    if (second != true || !context.mounted) return;

    // ── Exécution ──
    try {
      // 1. Fermer la DB
      final db = await DatabaseHelper.instance.database;
      await db.close();

      // 2. Supprimer le fichier DB
      final dbDir = await databaseFactory.getDatabasesPath();
      final dbFile = File(join(dbDir, AppConstants.dbName));
      if (dbFile.existsSync()) dbFile.deleteSync();

      // 3. Vider SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 4. Supprimer le modèle IA local (si existant)
      try {
        for (final choice in MagicModelChoice.values) {
          final path = await ModelDownloadService.instance.modelPathFor(choice);
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      } catch (_) {
        // Ignorer si pas de modèle
      }

      AppLogger.instance.info('Settings', 'Application reset completed');

      if (context.mounted) {
        // Fermer l'app (sur Desktop, exit ; sur mobile, redémarrage)
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                color: Colors.green,
                size: 32),
            title: const Text('Réinitialisation terminée'),
            content: const Text(
                'L\'application va se fermer. Relancez-la manuellement.'),
            actions: [
              FilledButton(
                onPressed: () => exit(0),
                child: const Text('Fermer l\'application'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la réinitialisation : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
