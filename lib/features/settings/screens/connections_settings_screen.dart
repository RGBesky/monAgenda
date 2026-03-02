import '../../../app.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/ics_subscription_model.dart';
import '../../../core/models/notion_database_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/events_provider.dart';
import '../../../services/ics_service.dart';
import '../../../services/infomaniak_service.dart';
import '../../../services/notion_service.dart';
import '../../../core/widgets/settings_logo_header.dart';

class ConnectionsSettingsScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const ConnectionsSettingsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<ConnectionsSettingsScreen> createState() =>
      _ConnectionsSettingsScreenState();
}

class _ConnectionsSettingsScreenState
    extends ConsumerState<ConnectionsSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _infomaniakLoading = false;
  bool _notionLoading = false;
  final _infomaniakUsernameController = TextEditingController();
  final _infomaniakPasswordController = TextEditingController();
  final _infomaniakCalendarUrlController = TextEditingController();
  final _notionApiKeyController = TextEditingController();
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _infomaniakUsernameController.dispose();
    _infomaniakPasswordController.dispose();
    _infomaniakCalendarUrlController.dispose();
    _notionApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Infomaniak'),
            Tab(text: 'Notion'),
            Tab(text: '.ics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfomaniakTab(),
          _buildNotionTab(),
          _buildIcsTab(),
        ],
      ),
    );
  }

  Widget _buildInfomaniakTab() {
    final settings = ref.watch(settingsProvider).valueOrNull;
    if (!_controllersInitialized && settings != null) {
      _infomaniakUsernameController.text = settings.infomaniakUsername ?? '';
      _infomaniakPasswordController.text = settings.infomaniakAppPassword ?? '';
      _infomaniakCalendarUrlController.text =
          settings.infomaniakCalendarUrl ?? '';
      _notionApiKeyController.text = settings.notionApiKey ?? '';
      _controllersInitialized = true;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SettingsLogoHeader(),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration Infomaniak CalDAV',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Utilisez la synchronisation CalDAV Infomaniak.\n'
                  '1. Rendez-vous dans manager.infomaniak.com → kSuite → '
                  'Mail → Synchronisation CalDAV.\n'
                  '2. Copiez le nom d\'utilisateur et l\'URL du calendrier.\n'
                  '3. Créez un mot de passe d\'application depuis '
                  'votre profil Infomaniak.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _infomaniakUsernameController,
          decoration: const InputDecoration(
            labelText: 'Nom d\'utilisateur',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
            helperText: 'Votre identifiant Infomaniak',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _infomaniakPasswordController,
          decoration: const InputDecoration(
            labelText: 'Mot de passe d\'application',
            prefixIcon: Icon(Icons.key),
            border: OutlineInputBorder(),
            helperText: 'Généré depuis votre profil Infomaniak',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _infomaniakCalendarUrlController,
          decoration: const InputDecoration(
            labelText: 'URL CalDAV du calendrier',
            prefixIcon: Icon(Icons.link),
            border: OutlineInputBorder(),
            helperText: 'https://sync.infomaniak.com/calendars/…/…',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _infomaniakLoading
                ? null
                : () => _saveInfomaniakCredentials(context),
            child: _infomaniakLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Valider et connecter'),
          ),
        ),
        if (settings?.isInfomaniakConfigured == true) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () async {
              await ref
                  .read(settingsProvider.notifier)
                  .updateInfomaniakCredentials(
                    username: '',
                    appPassword: '',
                    calendarUrl: '',
                  );
              _infomaniakUsernameController.clear();
              _infomaniakPasswordController.clear();
              _infomaniakCalendarUrlController.clear();
              if (mounted) {
                UnifiedCalendarApp.scaffoldMessengerKey.currentState
                    ?.showSnackBar(
                  const SnackBar(
                    content: Text('Infomaniak déconnecté'),
                  ),
                );
              }
            },
            child: const Text('Déconnecter'),
          ),
        ],
      ],
    );
  }

  Widget _buildNotionTab() {
    final settings = ref.watch(settingsProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SettingsLogoHeader(),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration Notion',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Créez une intégration sur notion.so/my-integrations et '
                  'partagez vos bases de données avec elle.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notionApiKeyController,
          decoration: const InputDecoration(
            labelText: 'API Key (Integration Token)',
            prefixIcon: Icon(Icons.key),
            border: OutlineInputBorder(),
            helperText: 'Commence par "ntn_" ou "secret_"',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _notionLoading
                ? null
                : () =>
                    _saveNotionApiKey(context, _notionApiKeyController.text),
            child: _notionLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Valider et connecter'),
          ),
        ),
        if (settings?.isNotionConfigured == true) ...[
          const SizedBox(height: 24),
          const Text(
            'Bases de données',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          _buildNotionDatabasesList(),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _discoverNotionDatabases(context),
            icon: const Icon(Icons.search),
            label: const Text('Découvrir les bases de données'),
          ),
        ],
      ],
    );
  }

  Widget _buildNotionDatabasesList() {
    return FutureBuilder<List<NotionDatabaseModel>>(
      future: DatabaseHelper.instance.getNotionDatabases(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final dbs = snap.data ?? [];
        if (dbs.isEmpty) {
          return const Text(
            'Aucune base de données configurée',
            style: TextStyle(color: Colors.grey),
          );
        }
        return Column(
          children: dbs.map((db) => _buildNotionDbTile(db)).toList(),
        );
      },
    );
  }

  Widget _buildNotionDbTile(NotionDatabaseModel db) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          Icons.table_chart_outlined,
          color: db.isEnabled ? Colors.blue : Colors.grey,
        ),
        title: Text(
          db.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: db.isEnabled ? null : Colors.grey,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          db.isEnabled ? 'Activée' : 'Désactivée',
          style: TextStyle(
            fontSize: 12,
            color: db.isEnabled ? Colors.green : Colors.grey,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: db.isEnabled,
              onChanged: (v) async {
                await DatabaseHelper.instance.updateNotionDatabase(
                  db.copyWith(isEnabled: v),
                );
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer cette base ?'),
                    content: Text(
                      'La base "${db.name}" sera retirée de la synchronisation.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && db.id != null) {
                  await DatabaseHelper.instance.deleteNotionDatabase(db.id!);
                  setState(() {});
                }
              },
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMappingRow('Titre', db.titleProperty),
                _buildMappingRow('Date début', db.startDateProperty),
                _buildMappingRow('Catégorie / Couleur', db.categoryProperty),
                _buildMappingRow('Priorité', db.priorityProperty),
                _buildMappingRow('État', db.statusProperty),
                _buildMappingRow(
                    'Description',
                    db.descriptionProperties.isNotEmpty
                        ? db.descriptionProperties.join(', ')
                        : null),
                _buildMappingRow('Lieu (Où)', db.locationProperty),
                _buildMappingRow('Objectif (Pourquoi)', db.objectiveProperty),
                _buildMappingRow('Matériel (Quoi)', db.materialProperty),
                _buildMappingRow('Participants', db.participantsProperty),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _editNotionDbMappings(db),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Modifier les mappings'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              style: TextStyle(
                fontSize: 12,
                fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
                color: value != null ? null : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ouvre un dialogue pour modifier les mappings d'une BDD Notion.
  /// Récupère le schéma en live pour proposer les propriétés disponibles.
  Future<void> _editNotionDbMappings(NotionDatabaseModel db) async {
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings?.notionApiKey == null) return;

    // Chargement du schéma
    Map<String, dynamic>? schema;
    try {
      final service = NotionService();
      service.setCredentials(apiKey: settings!.notionApiKey!);
      schema = await service.getDatabaseSchema(db.effectiveSourceId);
    } catch (e) {
      if (mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Erreur schéma : $e')),
        );
      }
      return;
    }

    final props = schema['properties'] as Map<String, dynamic>? ?? {};

    // Construire les listes de propriétés par type
    final allPropNames = ['— Aucune —', ...props.keys.toList()..sort()];

    // Classifier
    final datePropNames = <String>['— Aucune —'];
    final selectPropNames = <String>['— Aucune —'];
    final textPropNames = <String>['— Aucune —'];
    final titlePropNames = <String>[];

    for (final entry in props.entries) {
      final type =
          (entry.value as Map<String, dynamic>)['type'] as String? ?? '';
      if (type == 'date') datePropNames.add(entry.key);
      if (type == 'select' || type == 'multi_select' || type == 'status') {
        selectPropNames.add(entry.key);
      }
      if (type == 'rich_text' ||
          type == 'url' ||
          type == 'email' ||
          type == 'phone_number' ||
          type == 'number') {
        textPropNames.add(entry.key);
      }
      if (type == 'title') titlePropNames.add(entry.key);
    }
    // also add to text for participants/description
    textPropNames.addAll(selectPropNames.skip(1));

    // Controllers initialized with current values
    String titleProp = db.titleProperty;
    String? startDateProp = db.startDateProperty;
    String? categoryProp = db.categoryProperty;
    String? priorityProp = db.priorityProperty;
    String? statusProp = db.statusProperty;
    List<String> descProps = List<String>.from(db.descriptionProperties);
    String? locationProp = db.locationProperty;
    String? objectiveProp = db.objectiveProperty;
    String? materialProp = db.materialProperty;
    String? participantsProp = db.participantsProperty;

    String norm(String? v) => (v == null || v.isEmpty) ? '— Aucune —' : v;

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Widget buildDropdown(
              String label,
              String? current,
              List<String> options,
              ValueChanged<String?> onChanged, {
              String? hint,
            }) {
              final val = norm(current);
              final safeOptions =
                  options.contains(val) ? options : [val, ...options];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('$label-$val'),
                  initialValue: val,
                  decoration: InputDecoration(
                    labelText: label,
                    helperText: hint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  isExpanded: true,
                  items: safeOptions
                      .map((n) => DropdownMenuItem(
                            value: n,
                            child:
                                Text(n, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => onChanged(
                    v == '— Aucune —' ? null : v,
                  ),
                ),
              );
            }

            return AlertDialog(
              title: Text(
                'Mappings — ${db.name}',
                style: const TextStyle(fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildDropdown(
                        'Titre',
                        titleProp,
                        titlePropNames.isEmpty ? allPropNames : titlePropNames,
                        (v) => setDialogState(() => titleProp = v ?? 'Name'),
                      ),
                      buildDropdown(
                        'Date de début',
                        startDateProp,
                        datePropNames,
                        (v) => setDialogState(() => startDateProp = v),
                      ),
                      buildDropdown(
                        'Catégorie / Couleur',
                        categoryProp,
                        selectPropNames,
                        (v) => setDialogState(() => categoryProp = v),
                        hint:
                            'Détermine la couleur de l\'événement dans le calendrier',
                      ),
                      buildDropdown(
                        'Priorité',
                        priorityProp,
                        selectPropNames,
                        (v) => setDialogState(() => priorityProp = v),
                      ),
                      buildDropdown(
                        'État d\'avancement',
                        statusProp,
                        selectPropNames,
                        (v) => setDialogState(() => statusProp = v),
                      ),
                      // Description — multi-select (comme Make/Integromat)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Description (multi-select)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            helperText:
                                'Sélectionnez les propriétés à concaténer dans la description',
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ...descProps.map(
                                (p) => Chip(
                                  label: Text(p,
                                      style: const TextStyle(fontSize: 12)),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () =>
                                      setDialogState(() => descProps.remove(p)),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              ActionChip(
                                label: const Text('+ Ajouter',
                                    style: TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onPressed: () async {
                                  final available = allPropNames
                                      .where((n) =>
                                          n != '— Aucune —' &&
                                          !descProps.contains(n))
                                      .toList();
                                  if (available.isEmpty) return;
                                  final picked = await showDialog<String>(
                                    context: ctx,
                                    builder: (c) => SimpleDialog(
                                      title:
                                          const Text('Ajouter une propriété'),
                                      children: available
                                          .map(
                                            (n) => SimpleDialogOption(
                                              child: Text(n),
                                              onPressed: () =>
                                                  Navigator.pop(c, n),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => descProps.add(picked));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      buildDropdown(
                        'Lieu',
                        locationProp,
                        allPropNames,
                        (v) => setDialogState(() => locationProp = v),
                      ),
                      buildDropdown(
                        'Objectif',
                        objectiveProp,
                        allPropNames,
                        (v) => setDialogState(() => objectiveProp = v),
                      ),
                      buildDropdown(
                        'Matériel',
                        materialProp,
                        allPropNames,
                        (v) => setDialogState(() => materialProp = v),
                      ),
                      buildDropdown(
                        'Participants',
                        participantsProp,
                        allPropNames,
                        (v) => setDialogState(() => participantsProp = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      final updated = db.copyWith(
        titleProperty: titleProp,
        startDateProperty: startDateProp,
        categoryProperty: categoryProp,
        priorityProperty: priorityProp,
        statusProperty: statusProp,
        descriptionProperties: descProps,
        locationProperty: locationProp,
        objectiveProperty: objectiveProp,
        materialProperty: materialProp,
        participantsProperty: participantsProp,
      );
      await DatabaseHelper.instance.updateNotionDatabase(updated);

      // ── Auto-générer les tags manquants depuis le schéma Notion ──
      try {
        final notion = NotionService();
        final allTags = await DatabaseHelper.instance.getAllTags();
        final schema =
            await notion.getDatabaseSchema(updated.effectiveSourceId);
        final missingTags = notion.extractMissingCategoryTags(
          schema: schema,
          dbModel: updated,
          allTags: allTags,
        );
        for (final tag in missingTags) {
          await DatabaseHelper.instance.insertTag(tag);
        }
        if (missingTags.isNotEmpty && mounted) {
          UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(
                'Mappings enregistrés — ${missingTags.length} tag(s) créé(s)',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Mappings enregistrés'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (_) {
        // Schema fetch failed — juste confirmer la sauvegarde
        if (mounted) {
          UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Mappings enregistrés',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      setState(() {});
    }
  }

  Widget _buildIcsTab() {
    return FutureBuilder<List<IcsSubscriptionModel>>(
      future: DatabaseHelper.instance.getIcsSubscriptions(),
      builder: (context, snap) {
        final subs = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SettingsLogoHeader(),
            ...subs.map((sub) => _buildIcsSubscriptionTile(sub)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addIcsSubscription(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un abonnement .ics'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _importIcsFile(context),
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Importer un fichier .ics'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIcsSubscriptionTile(IcsSubscriptionModel sub) {
    final color = AppColors.fromHex(sub.colorHex);
    return ListTile(
      leading: CircleAvatar(
        radius: 10,
        backgroundColor: color,
      ),
      title: Text(sub.name),
      subtitle: Text(
        sub.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: sub.isEnabled,
            onChanged: (v) async {
              await DatabaseHelper.instance
                  .updateIcsSubscription(sub.copyWith(isEnabled: v));
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () async {
              await DatabaseHelper.instance.deleteIcsSubscription(sub.id!);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveInfomaniakCredentials(BuildContext context) async {
    final username = _infomaniakUsernameController.text.trim();
    final appPassword = _infomaniakPasswordController.text.trim();
    final calendarUrl = _infomaniakCalendarUrlController.text.trim();

    if (username.isEmpty || appPassword.isEmpty) {
      UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content:
              Text('Veuillez remplir le nom d\'utilisateur et le mot de passe'),
        ),
      );
      return;
    }

    setState(() => _infomaniakLoading = true);

    try {
      final service = InfomaniakService();
      service.setCredentials(
        username: username,
        appPassword: appPassword,
        calendarUrl: calendarUrl.isNotEmpty ? calendarUrl : null,
      );
      await service.validateCredentials();

      await ref.read(settingsProvider.notifier).updateInfomaniakCredentials(
            username: username,
            appPassword: appPassword,
            calendarUrl: calendarUrl.isNotEmpty ? calendarUrl : null,
          );

      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Infomaniak connecté avec succès',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String errorMsg = 'Erreur de connexion';
      if (e is DioException) {
        final status = e.response?.statusCode;
        if (status == 401) {
          errorMsg =
              'Identifiants invalides (401). Vérifiez le nom d\'utilisateur '
              'et le mot de passe d\'application.';
        } else if (status == 404) {
          errorMsg =
              'URL non trouvée (404). Vérifiez l\'URL CalDAV du calendrier.';
        } else {
          errorMsg = 'Erreur $status : ${e.message}';
        }
      } else {
        errorMsg = 'Erreur : $e';
      }
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      setState(() => _infomaniakLoading = false);
    }
  }

  Future<void> _saveNotionApiKey(BuildContext context, String key) async {
    if (key.trim().isEmpty) return;
    setState(() => _notionLoading = true);

    try {
      final service = NotionService();
      service.setCredentials(apiKey: key.trim());
      await service.validateApiKey();

      await ref.read(settingsProvider.notifier).updateNotionApiKey(key.trim());

      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Notion connecté avec succès',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      String errorMsg = 'Erreur de connexion';
      if (e is DioException) {
        final status = e.response?.statusCode;
        final body = e.response?.data;
        if (status == 401) {
          final detail = body is Map ? body['message'] ?? '' : '';
          errorMsg = 'Clé API invalide (401). '
              'Vérifiez votre token sur notion.so/my-integrations.\n$detail';
        } else if (status == 403) {
          errorMsg =
              'Accès refusé (403). Vérifiez les permissions de l\'intégration.';
        } else {
          errorMsg = 'Erreur $status : ${e.message}';
        }
      } else {
        errorMsg = 'Erreur : $e';
      }
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      setState(() => _notionLoading = false);
    }
  }

  Future<void> _discoverNotionDatabases(BuildContext context) async {
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings?.notionApiKey == null) return;

    setState(() => _notionLoading = true);

    try {
      final service = NotionService();
      service.setCredentials(apiKey: settings!.notionApiKey!);
      final databases = await service.searchDatabases();

      int added = 0;

      for (final db in databases) {
        final props = db['properties'] as Map<String, dynamic>? ?? {};
        final propNames = props.keys.toList();

        // Auto-detect property mappings from the schema
        String? findProp(List<String> candidates) {
          for (final c in candidates) {
            final match = propNames.firstWhereOrNull(
              (p) => p.toLowerCase().contains(c.toLowerCase()),
            );
            if (match != null) return match;
          }
          return null;
        }

        // Title property : look for a 'title' type property
        String titleProp = 'Name';
        for (final entry in props.entries) {
          if ((entry.value as Map<String, dynamic>)['type'] == 'title') {
            titleProp = entry.key;
            break;
          }
        }

        final databaseId = db['database_id'] as String;

        await DatabaseHelper.instance.insertNotionDatabase(
          NotionDatabaseModel(
            notionId: databaseId,
            name: db['name'] as String,
            titleProperty: titleProp,
            startDateProperty: findProp(['Date']),
            categoryProperty: findProp(['Projet', 'Catégorie', 'Category']),
            priorityProperty: findProp(['Priorité', 'Priority']),
            descriptionProperties: [
              if (findProp(
                      ['Comment', 'Description', 'Résumé / Commentaire']) !=
                  null)
                findProp(['Comment', 'Description', 'Résumé / Commentaire'])!,
            ],
            participantsProperty:
                findProp(['Qui', 'Participant', 'Responsable']),
            statusProperty: findProp(['État', 'Status', 'Statut']),
            locationProperty: findProp(['Où', 'Location', 'Lieu']),
            objectiveProperty: findProp(['Pourquoi', 'Objectif', 'Objective']),
            materialProperty: findProp(['Quoi', 'Matériel', 'Material']),
          ),
        );
        added++;
      }

      setState(() {});

      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('$added base(s) de données trouvée(s)'),
            backgroundColor: added > 0 ? Colors.green : null,
          ),
        );
      }
    } catch (e) {
      String errorMsg = 'Erreur lors de la découverte';
      if (e is DioException) {
        final status = e.response?.statusCode;
        if (status == 401) {
          errorMsg = 'Clé API invalide. Vérifiez votre intégration Notion.';
        } else {
          errorMsg = 'Erreur $status : ${e.message}';
        }
      } else {
        errorMsg = 'Erreur : $e';
      }
      if (context.mounted) {
        UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _notionLoading = false);
    }
  }

  Future<void> _addIcsSubscription(BuildContext context) async {
    String name = '';
    String url = '';
    String color = '#78909C';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un abonnement .ics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Nom *',
                hintText: 'Vacances scolaires',
              ),
              onChanged: (v) => name = v,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'URL .ics *',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
              onChanged: (v) => url = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (confirmed == true && name.trim().isNotEmpty && url.trim().isNotEmpty) {
      await DatabaseHelper.instance.insertIcsSubscription(
        IcsSubscriptionModel(
          name: name.trim(),
          url: url.trim(),
          colorHex: color,
        ),
      );
      setState(() {});
    }
  }

  /// Import ponctuel d'un fichier .ics depuis le disque
  Future<void> _importIcsFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
      dialogTitle: 'Sélectionner un fichier .ics',
    );

    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    try {
      final content = await File(filePath).readAsString();
      final events = IcsService.parseIcsFile(content);

      if (events.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aucun événement trouvé dans le fichier.')),
        );
        return;
      }

      // Confirmation
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importer des événements'),
          content: Text(
            '${events.length} événement${events.length > 1 ? 's' : ''} '
            'trouvé${events.length > 1 ? 's' : ''} dans le fichier.\n\n'
            'Voulez-vous les importer ?',
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

      if (confirmed != true) return;

      // Insertion en base
      final db = DatabaseHelper.instance;
      int imported = 0;
      for (final event in events) {
        await db.insertEvent(event);
        imported++;
      }

      // Rafraîchir
      ref.invalidate(eventsInRangeProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$imported événement${imported > 1 ? 's' : ''} importé${imported > 1 ? 's' : ''} avec succès.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Erreur lors de l\'import : ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}')),
      );
    }
  }
}
