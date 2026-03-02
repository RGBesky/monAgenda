import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/tag_model.dart';
import '../../../core/widgets/settings_logo_header.dart';
import '../../../providers/tags_provider.dart';

/// Palette 100 couleurs Stabilo Boss × Paper Mate Flair.
/// Grille 10 colonnes × 10 rangées (néon → fluo → acidulé → vif → medium → doux → pastel → pastel doux → pâle → glacé).
const List<Color> _paletteColors = AppColors.palette100;

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
              const SettingsLogoHeader(),
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
                                width: 420,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Labels nuances
                                    const Row(
                                      children: [
                                        _ColorFamilyLabel('Néon'),
                                        Spacer(),
                                        _ColorFamilyLabel('Glacé'),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Grille 10 familles × 10 nuances
                                    // Transposée : chaque ligne = 1 famille (rouge→neutre)
                                    // Chaque colonne = 1 nuance (néon→glacé)
                                    ...List.generate(10, (family) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: List.generate(10, (shade) {
                                            final c = _paletteColors[
                                                shade * 10 + family];
                                            final isSelected = c.toARGB32() ==
                                                tempColor.toARGB32();
                                            return GestureDetector(
                                              onTap: () {
                                                setPickerState(
                                                    () => tempColor = c);
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 150),
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: c,
                                                  shape: BoxShape.circle,
                                                  border: isSelected
                                                      ? Border.all(
                                                          color:
                                                              c.computeLuminance() >
                                                                      0.5
                                                                  ? Colors
                                                                      .black54
                                                                  : Colors
                                                                      .white,
                                                          width: 3,
                                                        )
                                                      : Border.all(
                                                          color: c.computeLuminance() >
                                                                  0.85
                                                              ? Colors.grey
                                                                  .withValues(
                                                                      alpha:
                                                                          0.3)
                                                              : Colors
                                                                  .transparent,
                                                          width: 1,
                                                        ),
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
                                                    ? Icon(
                                                        Icons.check_rounded,
                                                        color:
                                                            c.computeLuminance() >
                                                                    0.5
                                                                ? Colors.black87
                                                                : Colors.white,
                                                        size: 14,
                                                      )
                                                    : null,
                                              ),
                                            );
                                          }),
                                        ),
                                      );
                                    }),
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

/// Petit label pour les en-têtes du nuancier.
class _ColorFamilyLabel extends StatelessWidget {
  final String text;
  const _ColorFamilyLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
