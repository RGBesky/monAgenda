import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/ics_subscription_model.dart';
import '../../../core/models/notion_database_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/infomaniak_service.dart';
import '../../../services/notion_service.dart';

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
    final tokenController = TextEditingController(
      text: settings?.infomaniakToken ?? '',
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration Infomaniak',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Obtenez un Bearer Token depuis manager.infomaniak.com → '
                  'API Tokens. Scopes requis : workspace:calendar + user_info',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: tokenController,
          decoration: const InputDecoration(
            labelText: 'Bearer Token',
            prefixIcon: Icon(Icons.key),
            border: OutlineInputBorder(),
            helperText: 'Token OAuth2 Infomaniak',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _infomaniakLoading
                ? null
                : () => _saveInfomaniakToken(
                      context,
                      tokenController.text,
                    ),
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
                  .updateInfomaniakToken('');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
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
    final apiKeyController = TextEditingController(
      text: settings?.notionApiKey ?? '',
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
          controller: apiKeyController,
          decoration: const InputDecoration(
            labelText: 'API Key (Integration Token)',
            prefixIcon: Icon(Icons.key),
            border: OutlineInputBorder(),
            helperText: 'Commence par "secret_"',
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
                    _saveNotionApiKey(context, apiKeyController.text),
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
          children: dbs
              .map(
                (db) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.table_chart_outlined),
                  title: Text(db.name),
                  trailing: Switch(
                    value: db.isEnabled,
                    onChanged: (v) async {
                      await DatabaseHelper.instance.updateNotionDatabase(
                        db.copyWith(isEnabled: v),
                      );
                      setState(() {});
                    },
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildIcsTab() {
    return FutureBuilder<List<IcsSubscriptionModel>>(
      future: DatabaseHelper.instance.getIcsSubscriptions(),
      builder: (context, snap) {
        final subs = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...subs.map((sub) => _buildIcsSubscriptionTile(sub)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addIcsSubscription(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un abonnement .ics'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIcsSubscriptionTile(IcsSubscriptionModel sub) {
    final color = _colorFromHex(sub.colorHex);
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
              await DatabaseHelper.instance
                  .deleteIcsSubscription(sub.id!);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveInfomaniakToken(
    BuildContext context,
    String token,
  ) async {
    if (token.trim().isEmpty) return;
    setState(() => _infomaniakLoading = true);

    try {
      final service = InfomaniakService();
      service.setCredentials(token: token.trim());
      await service.validateToken();

      await ref
          .read(settingsProvider.notifier)
          .updateInfomaniakToken(token.trim());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Infomaniak connecté avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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

      await ref
          .read(settingsProvider.notifier)
          .updateNotionApiKey(key.trim());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notion connecté avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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

    try {
      final service = NotionService();
      service.setCredentials(apiKey: settings!.notionApiKey!);
      final databases = await service.searchDatabases();

      for (final db in databases) {
        await DatabaseHelper.instance.insertNotionDatabase(
          NotionDatabaseModel(
            notionId: db['id'] as String,
            name: db['name'] as String,
            titleProperty: 'Name',
          ),
        );
      }

      setState(() {});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${databases.length} base(s) trouvée(s)'),
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

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
