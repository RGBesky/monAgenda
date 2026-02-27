import '../../../app.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../providers/settings_provider.dart';

/// Écran d'import de configuration via QR Code (mobile) ou saisie manuelle.
/// Le QR scanné est chiffré AES-256 — un mot de passe est requis pour déchiffrer.
class ImportConfigScreen extends ConsumerStatefulWidget {
  const ImportConfigScreen({super.key});

  @override
  ConsumerState<ImportConfigScreen> createState() => _ImportConfigScreenState();
}

class _ImportConfigScreenState extends ConsumerState<ImportConfigScreen> {
  String? _scannedData;
  bool _isProcessing = false;
  String? _errorMessage;
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer la configuration'),
      ),
      body: _scannedData != null
          ? _buildPasswordForm(isDark)
          : _buildScannerOrManual(isDark),
    );
  }

  Widget _buildScannerOrManual(bool isDark) {
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F0ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comment importer ?',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF37352F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isMobile
                      ? '1. Scannez le QR code affiché sur votre ordinateur\n'
                          '2. Saisissez le mot de passe utilisé lors de l\'export\n'
                          '3. Vos paramètres et identifiants seront importés'
                      : '1. Collez les données chiffrées ci-dessous\n'
                          '2. Saisissez le mot de passe utilisé lors de l\'export\n'
                          '3. Vos paramètres et identifiants seront importés',
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
          const SizedBox(height: 24),

          if (isMobile) ...[
            // Bouton scanner
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _openScanner,
                icon: const Icon(Icons.qr_code_scanner, size: 24),
                label: const Text(
                  'Scanner un QR Code',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ou'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Saisie manuelle
          TextField(
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Données chiffrées (base64)',
              border: OutlineInputBorder(),
              hintText: 'Collez ici le contenu du QR code...',
            ),
            onChanged: (value) {
              if (value.trim().isNotEmpty) {
                setState(() {
                  _scannedData = value.trim();
                });
              }
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPasswordForm(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Succès scan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF34C759).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF34C759)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Données chiffrées reçues. Saisissez le mot de passe pour déchiffrer.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Mot de passe de déchiffrement',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
              helperText: 'Le mot de passe utilisé lors de l\'export',
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _decryptAndImport,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download),
              label: const Text(
                'Déchiffrer et importer',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _scannedData = null;
                _errorMessage = null;
              });
            },
            child: const Text('Recommencer'),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openScanner() async {
    // Import dynamique pour éviter les erreurs sur desktop
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const _QrScannerView()),
      );
      if (result != null && mounted) {
        setState(() {
          _scannedData = result;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Scanner non disponible : $e';
        });
      }
    }
  }

  Future<void> _decryptAndImport() async {
    if (_scannedData == null || _passwordController.text.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final settings = AppSettings.fromEncryptedExportString(
        _scannedData!,
        _passwordController.text,
      );
      // Extraire les tags exportés
      final exportedTags = AppSettings.parseExportedTagsEncrypted(
        _scannedData!,
        _passwordController.text,
      );

      if (!mounted) return;

      // Confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importer cette configuration ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings.infomaniakUsername != null)
                Text('• Infomaniak : ${settings.infomaniakUsername}'),
              if (settings.notionApiKey != null)
                const Text('• Notion : ✓ (clé API détectée)'),
              Text('• Thème : ${settings.theme}'),
              Text('• Vue : ${settings.defaultView}'),
              Text('• Météo : ${settings.weatherCity}'),
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

      if (confirm == true && mounted) {
        await ref.read(settingsProvider.notifier).importSettings(
              settings,
              tags: exportedTags,
            );
        if (mounted) {
          UnifiedCalendarApp.scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('✅ Configuration importée avec succès'),
            ),
          );
          Navigator.pop(context);
        }
      }
    } on FormatException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de déchiffrement. Vérifiez le mot de passe.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}

/// Vue interne du scanner QR utilisant mobile_scanner.
/// Isolée pour n'être instanciée que sur mobile.
class _QrScannerView extends StatefulWidget {
  const _QrScannerView();

  @override
  State<_QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<_QrScannerView> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_hasScanned) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                  _hasScanned = true;
                  Navigator.pop(context, barcode.rawValue);
                  return;
                }
              }
            },
          ),
          // Overlay avec zone de scan
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF007AFF),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Instructions en bas
          Positioned(
            bottom: 48,
            left: 32,
            right: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Pointez votre caméra vers le QR Code affiché sur votre ordinateur',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
