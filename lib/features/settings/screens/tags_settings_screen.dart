import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/tag_model.dart';
import '../../../providers/tags_provider.dart';

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
                        builder: (_) => AlertDialog(
                          title: const Text('Choisir une couleur'),
                          content: SingleChildScrollView(
                            child: BlockPicker(
                              pickerColor: currentColor,
                              onColorChanged: (c) {
                                setDialogState(() {
                                  currentColor = c;
                                  colorHex =
                                      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                                });
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
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
