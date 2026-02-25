import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/backup_service.dart';
import '../../../core/database/database_helper.dart';

class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  bool _isLoading = false;
  final _passwordController = TextEditingController();
  final _driveIdController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _driveIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde kDrive')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sauvegarde sur kDrive',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'La configuration (tokens, tags, abonnements .ics, BDD Notion) '
                    'est chiffrée en AES-256 et sauvegardée sur votre kDrive Infomaniak.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _driveIdController,
            decoration: const InputDecoration(
              labelText: 'ID kDrive',
              prefixIcon: Icon(Icons.cloud_outlined),
              border: OutlineInputBorder(),
              helperText: 'Trouvez votre ID dans manager.infomaniak.com',
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Mot de passe de chiffrement',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
              helperText: 'Gardez ce mot de passe en lieu sûr',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _performBackup,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('Sauvegarder maintenant'),
            ),
          ),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: _isLoading ? null : _performRestore,
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Restaurer depuis kDrive'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBackup() async {
    if (_passwordController.text.isEmpty ||
        _driveIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renseignez l\'ID kDrive et un mot de passe'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final settings = ref.read(settingsProvider).valueOrNull;
      final backupService = BackupService(db: DatabaseHelper.instance);
      backupService.setCredentials(
        token: settings?.infomaniakToken ?? '',
        driveId: _driveIdController.text.trim(),
      );

      await backupService.backup(
        encryptionPassword: _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sauvegarde effectuée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de sauvegarde : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performRestore() async {
    if (_passwordController.text.isEmpty ||
        _driveIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renseignez l\'ID kDrive et le mot de passe'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer la sauvegarde ?'),
        content: const Text(
          'La configuration actuelle sera remplacée par la sauvegarde kDrive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final settings = ref.read(settingsProvider).valueOrNull;
      final backupService = BackupService(db: DatabaseHelper.instance);
      backupService.setCredentials(
        token: settings?.infomaniakToken ?? '',
        driveId: _driveIdController.text.trim(),
      );

      final success = await backupService.restore(
        encryptionPassword: _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Restauration réussie'
                  : 'Aucune sauvegarde trouvée',
            ),
            backgroundColor: success ? Colors.green : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de restauration : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
