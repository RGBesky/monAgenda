import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_helper.dart';

/// Paire (input_text, ia_output, correction utilisateur).
/// 100 % locale — aucun envoi Cloud.
class MagicFeedbackRepository {
  final DatabaseHelper _db;

  MagicFeedbackRepository([DatabaseHelper? db])
      : _db = db ?? DatabaseHelper.instance;

  /// Enregistre une correction si au moins un champ diffère.
  Future<void> record({
    required String inputText,
    required Map<String, dynamic> iaOutputJson,
    required Map<String, dynamic> correctedOutputJson,
  }) async {
    final db = await _db.database;
    await db.insert('magic_feedback', {
      'input_text': inputText,
      'ia_output_json': jsonEncode(iaOutputJson),
      'corrected_output_json': jsonEncode(correctedOutputJson),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Retourne toutes les entrées (plus récentes en premier).
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db.database;
    return db.query('magic_feedback', orderBy: 'created_at DESC');
  }

  /// Nombre total de corrections enregistrées.
  Future<int> count() async {
    final db = await _db.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM magic_feedback');
    return result.first['cnt'] as int? ?? 0;
  }

  /// Export CSV pour analyse locale.
  Future<String> exportToCsv() async {
    final rows = await getAll();
    final buf = StringBuffer();
    buf.writeln('id,input_text,ia_output_json,corrected_output_json,created_at');
    for (final row in rows) {
      final id = row['id'];
      final input = _csvEscape(row['input_text'] as String);
      final ia = _csvEscape(row['ia_output_json'] as String);
      final corrected = _csvEscape(row['corrected_output_json'] as String);
      final date = row['created_at'];
      buf.writeln('$id,$input,$ia,$corrected,$date');
    }
    return buf.toString();
  }

  /// Supprime toutes les entrées.
  Future<void> clear() async {
    final db = await _db.database;
    await db.delete('magic_feedback');
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

// ─── Riverpod ────────────────────────────────────────────────

final magicFeedbackRepositoryProvider = Provider<MagicFeedbackRepository>(
  (ref) => MagicFeedbackRepository(),
);

/// Nombre de corrections enregistrées (utilisé dans Settings).
final magicFeedbackCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(magicFeedbackRepositoryProvider);
  return repo.count();
});
