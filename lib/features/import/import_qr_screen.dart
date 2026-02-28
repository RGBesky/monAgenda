import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/event_model.dart';
import '../../../core/utils/crypto_utils.dart';
import '../../../providers/events_provider.dart';
import '../../../services/logger_service.dart';

/// Résultat d'un import QR.
class ImportResult {
  final int inserted;
  final int updated;
  final int skipped;
  const ImportResult(
      {required this.inserted, required this.updated, required this.skipped});
}

/// Provider pour l'état d'import QR.
final importProvider =
    AsyncNotifierProvider<ImportNotifier, ImportResult?>(ImportNotifier.new);

class ImportNotifier extends AsyncNotifier<ImportResult?> {
  @override
  Future<ImportResult?> build() async => null;

  /// Merge les events importés avec la base locale.
  /// Règle : updatedAt gagne toujours.
  Future<ImportResult> mergeImport(List<Map<String, dynamic>> events) async {
    int inserted = 0, updated = 0, skipped = 0;
    final db = DatabaseHelper.instance;

    for (final map in events) {
      try {
        final imported = EventModel.fromMap(map);
        final existing = imported.remoteId != null
            ? await db.getEventByRemoteId(
                imported.remoteId!, imported.source)
            : null;

        if (existing == null) {
          // Pas d'event local → INSERT
          await db.insertEvent(imported);
          inserted++;
        } else if (imported.updatedAt != null &&
            existing.updatedAt != null &&
            imported.updatedAt!.isAfter(existing.updatedAt!)) {
          // Import plus récent → UPDATE
          await db.updateEvent(imported.copyWith(id: existing.id));
          updated++;
        } else {
          // Local plus récent ou égal → SKIP
          skipped++;
        }
      } catch (e) {
        AppLogger.instance.error('ImportQR', 'Merge error for event', e);
        skipped++;
      }
    }

    final result = ImportResult(
        inserted: inserted, updated: updated, skipped: skipped);
    state = AsyncData(result);
    ref.invalidate(eventsInRangeProvider);
    return result;
  }
}

/// Écran d'import QR — scan mobile + import image desktop.
class ImportQrScreen extends ConsumerStatefulWidget {
  const ImportQrScreen({super.key});

  @override
  ConsumerState<ImportQrScreen> createState() => _ImportQrScreenState();
}

class _ImportQrScreenState extends ConsumerState<ImportQrScreen> {
  final _scannerController = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isLinux || Platform.isMacOS || Platform.isWindows;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer via QR Code'),
      ),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(context),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            if (_processing) return;
            final barcodes = capture.barcodes;
            if (barcodes.isEmpty) return;
            final rawValue = barcodes.first.rawValue;
            if (rawValue != null && rawValue.isNotEmpty) {
              _handleScannedData(rawValue);
            }
          },
        ),
        // Overlay
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (_processing)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
          const SizedBox(height: 24),
          Text(
            'Importez une image QR Code',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _processing ? null : () => _pickQrImage(),
            icon: const Icon(Icons.image),
            label: const Text('Importer une image QR'),
          ),
          if (_processing) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Future<void> _pickQrImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _processing = true);
    try {
      final barcodeCapture = await _scannerController
          .analyzeImage(result.files.single.path!);
      if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
        final rawValue = barcodeCapture.barcodes.first.rawValue;
        if (rawValue != null && rawValue.isNotEmpty) {
          await _handleScannedData(rawValue);
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun QR Code trouvé dans l\'image'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.instance.error('ImportQR', 'Image analysis failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'analyse : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _processing = false);
    }
  }

  Future<void> _handleScannedData(String encoded) async {
    setState(() => _processing = true);
    _scannerController.stop();

    // Demander le mot de passe
    final password = await _showPasswordDialog();
    if (password == null || !mounted) {
      setState(() => _processing = false);
      _scannerController.start();
      return;
    }

    try {
      // Déchiffrer via AES-256
      final jsonStr = CryptoUtils.decryptFromExportString(encoded, password);
      final decoded = jsonDecode(jsonStr);

      List<Map<String, dynamic>> events;
      if (decoded is List) {
        events = decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map && decoded.containsKey('events')) {
        events = (decoded['events'] as List).cast<Map<String, dynamic>>();
      } else {
        throw const FormatException('Format QR non reconnu');
      }

      // Merge
      final result =
          await ref.read(importProvider.notifier).mergeImport(events);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import terminé : ${result.inserted} ajoutés, '
              '${result.updated} mis à jour, ${result.skipped} ignorés',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.instance.error('ImportQR', 'Decrypt/merge failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('decrypt') ||
                    e.toString().contains('padding')
                ? 'Mot de passe incorrect'
                : 'Erreur d\'import : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _processing = false);
      _scannerController.start();
    }
  }

  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    bool obscure = true;
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mot de passe du QR'),
          content: TextField(
            controller: controller,
            obscureText: obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              errorText: errorText,
              filled: true,
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setDialogState(() => obscure = !obscure),
              ),
            ),
            onSubmitted: (v) {
              if (v.isNotEmpty) Navigator.pop(context, v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isEmpty) {
                  setDialogState(
                      () => errorText = 'Veuillez saisir un mot de passe');
                  return;
                }
                Navigator.pop(context, controller.text);
              },
              child: const Text('Déchiffrer'),
            ),
          ],
        ),
      ),
    );
  }
}
