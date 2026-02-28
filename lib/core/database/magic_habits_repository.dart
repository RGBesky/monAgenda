import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_helper.dart';

/// Stocke les habitudes utilisateur extraites des corrections de la Saisie Magique.
///
/// Exemple : l'utilisateur tape "aller à la messe" et corrige le lieu en
/// "Saint-Défendent" → on stocke keyword="messe", field="location",
/// value="Saint-Défendent". La prochaine fois que "messe" apparaît,
/// on pré-remplit le lieu.
///
/// 100 % locale — aucun envoi Cloud.
class MagicHabitsRepository {
  final DatabaseHelper _db;
  static const _table = 'magic_habits';

  MagicHabitsRepository([DatabaseHelper? db])
      : _db = db ?? DatabaseHelper.instance;

  /// Enregistre ou met à jour une habitude.
  /// Si le couple (keyword, field_name) existe déjà, on incrémente usage_count
  /// et on met à jour field_value (l'utilisateur a peut-être changé d'avis).
  Future<void> upsert({
    required String keyword,
    required String fieldName,
    required String fieldValue,
  }) async {
    final db = await _db.database;
    final kw = keyword.toLowerCase().trim();

    final existing = await db.query(
      _table,
      where: 'keyword = ? AND field_name = ?',
      whereArgs: [kw, fieldName],
    );

    if (existing.isNotEmpty) {
      await db.update(
        _table,
        {
          'field_value': fieldValue,
          'usage_count': (existing.first['usage_count'] as int? ?? 1) + 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'keyword = ? AND field_name = ?',
        whereArgs: [kw, fieldName],
      );
    } else {
      await db.insert(_table, {
        'keyword': kw,
        'field_name': fieldName,
        'field_value': fieldValue,
        'usage_count': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  /// Recherche les habitudes correspondant aux mots-clés présents dans [text].
  /// Retourne une Map {field_name: field_value} des meilleurs matchs
  /// (la plus haute usage_count gagne en cas de conflit sur un même champ).
  Future<Map<String, String>> lookupForText(String text) async {
    final db = await _db.database;
    final allHabits = await db.query(_table, orderBy: 'usage_count DESC');

    if (allHabits.isEmpty) return {};

    final lc = text.toLowerCase();
    final results = <String, String>{};

    for (final habit in allHabits) {
      final kw = habit['keyword'] as String;
      if (lc.contains(kw)) {
        final field = habit['field_name'] as String;
        // Premier match gagne (trié par usage_count DESC)
        results.putIfAbsent(field, () => habit['field_value'] as String);
      }
    }

    return results;
  }

  /// Retourne toutes les habitudes (plus utilisées en premier).
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return db.query(_table, orderBy: 'usage_count DESC, updated_at DESC');
  }

  /// Supprime une habitude par id.
  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Nombre total d'habitudes enregistrées.
  Future<int> count() async {
    final db = await _db.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM $_table');
    return result.first['cnt'] as int? ?? 0;
  }
}

/// Provider pour le repository des habitudes.
final magicHabitsRepositoryProvider = Provider<MagicHabitsRepository>((ref) {
  return MagicHabitsRepository();
});
