import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? _statusMessage;
  bool _statusIsError = false;
  DateTime? _lastBackupDate;

  final _passwordController = TextEditingController();
  final _depositLinkController = TextEditingController();

  static const _prefDepositLink = 'kdrive_deposit_link';
  // Le mot de passe n'est PAS persisté (l'utilisateur le saisit à chaque fois)

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLink = prefs.getString(_prefDepositLink);
    if (savedLink != null) {
      _depositLinkController.text = savedLink;
    }

    // Vérifier la dernière sauvegarde locale
    final backupService = BackupService(db: DatabaseHelper.instance);
    final lastDate = await backupService.lastLocalBackupDate();
    if (mounted) {
      setState(() => _lastBackupDate = lastDate);
    }
  }

  Future<void> _saveDepositLink() async {
    final prefs = await SharedPreferences.getInstance();
    final link = _depositLinkController.text.trim();
    if (link.isNotEmpty) {
      await prefs.setString(_prefDepositLink, link);
    } else {
      await prefs.remove(_prefDepositLink);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _depositLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde kDrive')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Explication ───
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Sauvegarde via lien de dépôt',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La configuration (tags, abonnements .ics, BDD Notion) '
                    'est chiffrée en AES-256 puis envoyée sur votre kDrive '
                    'via un lien de dépôt. Aucun token API n\'est nécessaire.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Créez un lien de dépôt sur kdrive.infomaniak.com\n'
                    '2. Collez l\'URL ci-dessous\n'
                    '3. Choisissez un mot de passe de chiffrement',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Lien de dépôt ───
          TextField(
            controller: _depositLinkController,
            decoration: InputDecoration(
              labelText: 'Lien de dépôt kDrive',
              prefixIcon: const Icon(Icons.link),
              border: const OutlineInputBorder(),
              helperText:
                  'Ex : https://kdrive.infomaniak.com/app/share/xxxx/files',
              helperMaxLines: 2,
              suffixIcon: _depositLinkController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _depositLinkController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            maxLines: 1,
          ),
          const SizedBox(height: 12),

          // ─── Mot de passe de chiffrement ───
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Mot de passe de chiffrement',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
              helperText: 'Gardez ce mot de passe en lieu sûr !',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 20),

          // ─── Bouton Sauvegarder (kDrive + local) ───
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _performBackupKDrive,
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
              label: const Text('Sauvegarder sur kDrive'),
            ),
          ),
          const SizedBox(height: 8),

          // ─── Bouton Sauvegarder en local uniquement ───
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _performBackupLocal,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Sauvegarder en local uniquement'),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // ─── Section Restauration ───
          const Text(
            'Restauration',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _performRestoreLocal,
            icon: const Icon(Icons.restore),
            label: const Text('Restaurer (dernière sauvegarde locale)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _performRestoreFromFile,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Restaurer depuis un fichier .enc'),
          ),

          // ─── Dernière sauvegarde ───
          if (_lastBackupDate != null) ...[
            const SizedBox(height: 16),
            Card(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 18,
                        color: isDark ? Colors.white54 : Colors.black45),
                    const SizedBox(width: 8),
                    Text(
                      'Dernière sauvegarde locale : '
                      '${_formatDate(_lastBackupDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ─── Message de statut ───
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Card(
              color: _statusIsError
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _statusIsError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: _statusIsError
                          ? Theme.of(context).colorScheme.error
                          : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: _statusIsError
                              ? Theme.of(context).colorScheme.error
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────── Actions ─────────────────────────

  bool _validatePassword() {
    if (_passwordController.text.isEmpty) {
      _setStatus('Renseignez un mot de passe de chiffrement', isError: true);
      return false;
    }
    if (_passwordController.text.length < 4) {
      _setStatus('Le mot de passe doit contenir au moins 4 caractères',
          isError: true);
      return false;
    }
    return true;
  }

  Future<void> _performBackupKDrive() async {
    if (!_validatePassword()) return;
    if (_depositLinkController.text.trim().isEmpty) {
      _setStatus('Renseignez le lien de dépôt kDrive', isError: true);
      return;
    }

    final uuid =
        BackupService.extractShareUuid(_depositLinkController.text.trim());
    if (uuid == null) {
      _setStatus(
        'Lien de dépôt invalide. Collez l\'URL depuis kDrive '
        '(ex : https://kdrive.infomaniak.com/app/share/xxxxx/files)',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    _setStatus(null);

    try {
      await _saveDepositLink();
      final backupService = BackupService(db: DatabaseHelper.instance);
      await backupService.backup(
        encryptionPassword: _passwordController.text,
        depositLink: _depositLinkController.text.trim(),
      );

      final lastDate = await backupService.lastLocalBackupDate();
      if (mounted) {
        setState(() => _lastBackupDate = lastDate);
        _setStatus('Sauvegarde envoyée sur kDrive + copie locale');
      }
    } catch (e) {
      if (mounted) {
        _setStatus('Erreur : $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performBackupLocal() async {
    if (!_validatePassword()) return;

    setState(() => _isLoading = true);
    _setStatus(null);

    try {
      final backupService = BackupService(db: DatabaseHelper.instance);
      final file = await backupService.backupLocally(
        encryptionPassword: _passwordController.text,
      );

      final lastDate = await backupService.lastLocalBackupDate();
      if (mounted) {
        setState(() => _lastBackupDate = lastDate);
        _setStatus('Sauvegarde locale effectuée\n${file.path}');
      }
    } catch (e) {
      if (mounted) {
        _setStatus('Erreur : $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performRestoreLocal() async {
    if (!_validatePassword()) return;

    final confirmed = await _confirmRestore();
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    _setStatus(null);

    try {
      final backupService = BackupService(db: DatabaseHelper.instance);
      final success = await backupService.restoreFromLocal(
        encryptionPassword: _passwordController.text,
      );

      if (mounted) {
        if (success) {
          _setStatus('Restauration réussie. Redémarrez l\'application.');
        } else {
          _setStatus('Aucune sauvegarde locale trouvée', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _setStatus('Erreur de restauration : $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performRestoreFromFile() async {
    if (!_validatePassword()) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Sélectionner le fichier .enc',
    );

    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.first.path;
    if (filePath == null) return;

    final confirmed = await _confirmRestore();
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    _setStatus(null);

    try {
      final backupService = BackupService(db: DatabaseHelper.instance);
      final success = await backupService.restoreFromFile(
        filePath: filePath,
        encryptionPassword: _passwordController.text,
      );

      if (mounted) {
        if (success) {
          _setStatus('Restauration réussie. Redémarrez l\'application.');
        } else {
          _setStatus('Fichier introuvable ou invalide', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _setStatus('Erreur de restauration : $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────────── Helpers ─────────────────────────

  Future<bool?> _confirmRestore() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer la sauvegarde ?'),
        content: const Text(
          'La configuration actuelle (tags, BDD Notion, abonnements .ics) '
          'sera remplacée par la sauvegarde.',
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
  }

  void _setStatus(String? message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
