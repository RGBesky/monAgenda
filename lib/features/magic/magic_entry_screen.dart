import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/models/event_model.dart';
import '../../core/database/magic_feedback_repository.dart';
import '../../services/magic_entry_service.dart';
import '../../services/model_download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../events/screens/event_form_screen.dart';

/// Écran de Saisie Magique — NLP local.
/// Mobile : bouton "✨ Magie", Desktop : Ctrl+K "Spotlight".
class MagicEntryScreen extends ConsumerStatefulWidget {
  const MagicEntryScreen({super.key});

  @override
  ConsumerState<MagicEntryScreen> createState() => _MagicEntryScreenState();
}

class _MagicEntryScreenState extends ConsumerState<MagicEntryScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _parsing = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus le champ texte
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isLinux || Platform.isMacOS || Platform.isWindows;

    if (isDesktop) return _buildSpotlight(context);
    return _buildMobileScreen(context);
  }

  /// Mode Spotlight (Desktop) : barre flottante centrée style Alfred/Raycast.
  Widget _buildSpotlight(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
          }
        },
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Empêche la propagation
              child: Container(
                width: 560,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header : titre + bouton fermer
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Saisie Magique',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                    letterSpacing: 0.5,
                                  ),
                        ),
                        const Spacer(),
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(context),
                    if (_parsing) _buildShimmer(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mode plein écran (Mobile).
  Widget _buildMobileScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ Saisie Magique'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Décrivez votre événement en langage naturel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 16),
            _buildInputField(context),
            if (_parsing) ...[
              const SizedBox(height: 16),
              _buildShimmer(context),
            ],
            const SizedBox(height: 16),
            Text(
              'Exemples :\n'
              '• "Dîner avec Marc vendredi 20h au Resto #Perso"\n'
              '• "Réunion budget demain 14h-15h30"\n'
              '• "Dentiste 15/04 à 10h"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(BuildContext context) {
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      decoration: InputDecoration(
        hintText: 'Décrivez votre événement...',
        prefixIcon: const Icon(Icons.auto_awesome, color: Color(0xFFFFBD98)),
        suffixIcon: IconButton(
          icon: _parsing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          onPressed: _parsing ? null : () => _parse(),
        ),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _parse(),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[600]! : Colors.grey[100]!,
        child: Column(
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _parse() async {
    final input = _textController.text.trim();
    if (input.isEmpty) return;

    setState(() => _parsing = true);

    try {
      final event =
          await ref.read(magicEntryProvider.notifier).parseText(input);

      // Vérifier si le modèle doit être téléchargé
      final needsDownload = ref.read(modelNeedsDownloadProvider);
      if (needsDownload && mounted) {
        _showDownloadProposal(context, input, event);
        return;
      }

      if (event != null && mounted) {
        await _navigateToForm(event, input);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de parser le texte. Reformulez.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  /// Propose le téléchargement du modèle IA après un premier parsing regex.
  void _showDownloadProposal(
      BuildContext context, String input, EventModel? regexResult) {
    var chosen = ModelDownloadService.instance.selectedModel;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          icon: const Icon(Icons.smart_toy_outlined,
              color: Color(0xFFFFBD98), size: 40),
          title: const Text('Modèle IA non installé'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Un modèle IA local permet une compréhension bien plus '
                'précise de vos événements (lieux, participants…).',
              ),
              const SizedBox(height: 16),
              Text('Choisissez votre modèle :',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              RadioGroup<MagicModelChoice>(
                groupValue: chosen,
                onChanged: (v) {
                  if (v != null) setDialogState(() => chosen = v);
                },
                child: Column(
                  children: MagicModelChoice.values
                      .map((m) => RadioListTile<MagicModelChoice>(
                            title: Text(m.label),
                            subtitle: Text('${m.subtitle} · ~${m.approxSizeMb} Mo'),
                            value: m,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Téléchargement depuis HuggingFace.\n'
                '100% local, aucune donnée envoyée.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              if (regexResult != null) ...[
                const SizedBox(height: 12),
                Text(
                  'En attendant, un résultat a été obtenu par analyse basique.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ],
          ),
          actions: [
            if (regexResult != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToForm(regexResult, input);
                },
                child: const Text('Utiliser le résultat basique'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Plus tard'),
            ),
            FilledButton.icon(
              onPressed: () async {
                // Persister le choix
                ModelDownloadService.instance.selectedModel = chosen;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('magic_model_choice', chosen.name);
                if (ctx.mounted) Navigator.pop(ctx);
                _startModelDownload(input);
              },
              icon: const Icon(Icons.download, size: 18),
              label: Text('Télécharger ${chosen.label}'),
            ),
          ],
        ),
      ),
    );
  }

  /// Lance le téléchargement avec indicateur de progression.
  Future<void> _startModelDownload(String pendingInput) async {
    if (!mounted) return;

    // Afficher le dialog de progression
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ModelDownloadDialog(
        onComplete: (success) async {
          Navigator.pop(ctx);
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('✓ Modèle IA installé ! Relancez la saisie magique.'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('✗ Échec du téléchargement. Réessayez plus tard.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _navigateToForm(EventModel event, String input) async {
    final iaMap = event.toMap();
    // Naviguer vers le formulaire pré-rempli
    final result = await Navigator.push<EventModel>(
      context,
      MaterialPageRoute(
        builder: (_) => EventFormScreen(event: event),
      ),
    );

    // Feedback loop : enregistrer si l'utilisateur a corrigé
    if (result != null) {
      final correctedMap = result.toMap();
      final modified = iaMap.entries.any(
        (e) => correctedMap[e.key]?.toString() != e.value?.toString(),
      );
      if (modified) {
        ref.read(magicFeedbackRepositoryProvider).record(
              inputText: input,
              iaOutputJson: iaMap,
              correctedOutputJson: correctedMap,
            );
        // Apprentissage automatique des habitudes
        ref.read(magicEntryProvider.notifier).learnFromCorrection(
              inputText: input,
              originalEvent: event,
              correctedEvent: result,
            );
      }
    }

    if (mounted) Navigator.pop(context, result);
  }
}

/// Dialog de progression du téléchargement du modèle IA.
class _ModelDownloadDialog extends ConsumerStatefulWidget {
  final Function(bool success) onComplete;
  const _ModelDownloadDialog({required this.onComplete});

  @override
  ConsumerState<_ModelDownloadDialog> createState() =>
      _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends ConsumerState<_ModelDownloadDialog> {
  bool _downloading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
    });

    final success = await ref.read(magicEntryProvider.notifier).downloadModel();

    if (mounted) {
      setState(() {
        _downloading = false;
        _done = true;
        if (!success) _error = 'Échec du téléchargement';
      });
      // Petit délai pour que l'utilisateur voie le 100%
      await Future.delayed(const Duration(milliseconds: 500));
      widget.onComplete(success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(modelDownloadProgressProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.download, color: Color(0xFFFFBD98)),
          const SizedBox(width: 8),
          Text(_done
              ? (_error != null ? 'Erreur' : 'Terminé !')
              : 'Téléchargement du modèle IA'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_downloading) ...[
            progress.when(
              data: (value) => Column(
                children: [
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 8),
                  Text('${(value * 100).toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              loading: () => const Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Connexion à HuggingFace...'),
                ],
              ),
              error: (e, _) =>
                  Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 12),
            Text(
              '${ModelDownloadService.instance.selectedModel.label} · ~${ModelDownloadService.instance.selectedModel.approxSizeMb} Mo\n100% local, aucune donnée envoyée.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}
