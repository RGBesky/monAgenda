import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/tag_model.dart';
import '../../../providers/tags_provider.dart';

/// Palette organisée en 5 rangées de 6 — couleurs vives, modernes, lisibles.
const List<Color> _paletteColors = [
  // ─ Row 1 : Rouges → Violets
  Color(0xFFFF3B30), // Rouge vif
  Color(0xFFFF6B6B), // Corail
  Color(0xFFE84393), // Rose fuchsia
  Color(0xFFAF52DE), // Violet
  Color(0xFF6C5CE7), // Indigo
  Color(0xFF5856D6), // Bleu indigo

  // ─ Row 2 : Bleus → Turquoises
  Color(0xFF007AFF), // Bleu Apple
  Color(0xFF0984E3), // Bleu océan
  Color(0xFF00B4D8), // Cyan
  Color(0xFF00C7BE), // Turquoise
  Color(0xFF30B0C7), // Sarcelle
  Color(0xFF0077B6), // Bleu marine

  // ─ Row 3 : Verts
  Color(0xFF34C759), // Vert Apple
  Color(0xFF00B894), // Émeraude
  Color(0xFF2ECC71), // Vert prairie
  Color(0xFF55A630), // Vert olive
  Color(0xFF8AC926), // Lime
  Color(0xFF7CB342), // Vert sauge

  // ─ Row 4 : Jaunes → Oranges
  Color(0xFFFFCC00), // Jaune soleil
  Color(0xFFFFC43D), // Ambre
  Color(0xFFFF9500), // Orange Apple
  Color(0xFFFF7043), // Tangerine
  Color(0xFFE17055), // Terre cuite
  Color(0xFFA2845E), // Marron chaud

  // ─ Row 5 : Neutres + Pastels
  Color(0xFF8E8E93), // Gris Apple
  Color(0xFFB0BEC5), // Gris bleuté
  Color(0xFF636E72), // Ardoise
  Color(0xFF2D3436), // Charbon
  Color(0xFF8ABBE6), // Pastel bleu
  Color(0xFFF2A5B8), // Pastel rose
];

class TagsSettingsScreen extends ConsumerWidget {
  const TagsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Réinitialiser les tags ?'),
                    content: const Text(
                      'Tous vos tags personnalisés seront remplacés par les tags par défaut.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(tagsNotifierProvider.notifier)
                      .resetToDefaults();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('Réinitialiser par défaut'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (tags) {
          final categories = tags.where((t) => t.isCategory).toList();
          final priorities = tags.where((t) => t.isPriority).toList();

          return ListView(
            children: [
              _buildSection(
                context,
                ref,
                title: 'Catégories',
                subtitle: 'Multi-sélection par événement',
                tags: categories,
                type: AppConstants.tagTypeCategory,
              ),
              _buildSection(
                context,
                ref,
                title: 'Priorités',
                subtitle: 'Une seule par événement',
                tags: priorities,
                type: AppConstants.tagTypePriority,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required List<TagModel> tags,
    required String type,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...tags.map((tag) => _buildTagTile(context, ref, tag)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: TextButton.icon(
            onPressed: () => _addOrEditTag(context, ref, type: type),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Ajouter une $title'.toLowerCase()),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildTagTile(BuildContext context, WidgetRef ref, TagModel tag) {
    final color = AppColors.fromHex(tag.colorHex);
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      title: Text(tag.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () =>
                _addOrEditTag(context, ref, tag: tag, type: tag.type),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _confirmDeleteTag(context, ref, tag),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrEditTag(
    BuildContext context,
    WidgetRef ref, {
    TagModel? tag,
    required String type,
  }) async {
    String name = tag?.name ?? '';
    String colorHex = tag?.colorHex ?? '#1E88E5';
    Color currentColor = AppColors.fromHex(colorHex);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tag == null ? 'Nouveau tag' : 'Modifier le tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nom *'),
                controller: TextEditingController(text: name),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Couleur : '),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (_) {
                          Color tempColor = currentColor;
                          return StatefulBuilder(
                            builder: (ctx, setPickerState) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text('Choisir une couleur'),
                              content: SizedBox(
                                width: 280,
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _paletteColors.map((c) {
                                    final isSelected =
                                        c.toARGB32() == tempColor.toARGB32();
                                    return GestureDetector(
                                      onTap: () {
                                        setPickerState(() => tempColor = c);
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: c,
                                          shape: BoxShape.circle,
                                          border: isSelected
                                              ? Border.all(
                                                  color: Colors.white,
                                                  width: 3,
                                                )
                                              : null,
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: c.withValues(
                                                        alpha: 0.5),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              )
                                            : null,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Annuler'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      currentColor = tempColor;
                                      colorHex =
                                          '#${tempColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                                    });
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: currentColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    colorHex,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                if (name.trim().isEmpty) return;
                Navigator.pop(context);

                final notifier = ref.read(tagsNotifierProvider.notifier);
                if (tag == null) {
                  await notifier.addTag(TagModel(
                    type: type,
                    name: name.trim(),
                    colorHex: colorHex,
                    infomaniakMapping: name.trim(),
                    sortOrder: 99,
                  ));
                } else {
                  await notifier.updateTag(tag.copyWith(
                    name: name.trim(),
                    colorHex: colorHex,
                    infomaniakMapping: name.trim(),
                  ));
                }
              },
              child: Text(tag == null ? 'Créer' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTag(
    BuildContext context,
    WidgetRef ref,
    TagModel tag,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce tag ?'),
        content: Text('Supprimer "${tag.name}" ?'),
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

    if (confirmed == true && tag.id != null) {
      await ref.read(tagsNotifierProvider.notifier).deleteTag(tag.id!);
    }
  }
}
