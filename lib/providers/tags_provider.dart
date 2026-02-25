import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/models/tag_model.dart';

final tagsProvider = FutureProvider<List<TagModel>>((ref) async {
  return DatabaseHelper.instance.getAllTags();
});

final categoryTagsProvider = FutureProvider<List<TagModel>>((ref) async {
  return DatabaseHelper.instance.getTagsByType(AppConstants.tagTypeCategory);
});

final priorityTagsProvider = FutureProvider<List<TagModel>>((ref) async {
  return DatabaseHelper.instance.getTagsByType(AppConstants.tagTypePriority);
});

class TagsNotifier extends AsyncNotifier<List<TagModel>> {
  @override
  Future<List<TagModel>> build() async {
    return DatabaseHelper.instance.getAllTags();
  }

  Future<void> addTag(TagModel tag) async {
    await DatabaseHelper.instance.insertTag(tag);
    ref.invalidateSelf();
  }

  Future<void> updateTag(TagModel tag) async {
    await DatabaseHelper.instance.updateTag(tag);
    ref.invalidateSelf();
  }

  Future<void> deleteTag(int id) async {
    await DatabaseHelper.instance.deleteTag(id);
    ref.invalidateSelf();
  }

  Future<void> resetToDefaults() async {
    final tags = await DatabaseHelper.instance.getAllTags();
    for (final tag in tags) {
      if (tag.id != null) {
        await DatabaseHelper.instance.deleteTag(tag.id!);
      }
    }
    // Les tags par défaut sont recréés via migration DB
    // ou on les insère manuellement ici
    for (int i = 0; i < AppConstants.defaultCategories.length; i++) {
      final cat = AppConstants.defaultCategories[i];
      await DatabaseHelper.instance.insertTag(TagModel(
        type: AppConstants.tagTypeCategory,
        name: cat['name'] as String,
        colorHex: cat['color'] as String,
        infomaniakMapping: cat['name'] as String,
        sortOrder: i,
      ));
    }
    for (int i = 0; i < AppConstants.defaultPriorities.length; i++) {
      final pri = AppConstants.defaultPriorities[i];
      await DatabaseHelper.instance.insertTag(TagModel(
        type: AppConstants.tagTypePriority,
        name: pri['name'] as String,
        colorHex: pri['color'] as String,
        infomaniakMapping: (pri['level'] as int).toString(),
        sortOrder: pri['level'] as int,
      ));
    }
    ref.invalidateSelf();
  }
}

final tagsNotifierProvider =
    AsyncNotifierProvider<TagsNotifier, List<TagModel>>(TagsNotifier.new);
