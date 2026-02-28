import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/models/tag_model.dart';
import '../core/models/notion_database_model.dart';
import '../core/models/ics_subscription_model.dart';
import '../core/models/event_model.dart';
import 'logger_service.dart';

/// Service de sauvegarde/restauration via lien de dépôt kDrive (Infomaniak).
/// Configuration chiffrée AES-256. Pas besoin de token OAuth2.
class BackupService {
  final DatabaseHelper _db;

  BackupService({required DatabaseHelper db}) : _db = db;

  // ───────────────────────── Deposit link helpers ──────────────────────────

  /// Extrait l'UUID du lien de dépôt kDrive.
  /// Accepte :
  ///   • https://kdrive.infomaniak.com/app/share/{uuid}/files
  ///   • https://kdrive.infomaniak.com/app/share/{uuid}
  ///   • Juste l'UUID brut
  static String? extractShareUuid(String depositLink) {
    final trimmed = depositLink.trim();
    if (trimmed.isEmpty) return null;

    // Cas 1 : /app/collaborate/{driveId}/{uuid}
    final collab = RegExp(r'/collaborate/\d+/([a-zA-Z0-9\-]+)');
    final collabMatch = collab.firstMatch(trimmed);
    if (collabMatch != null) return collabMatch.group(1);

    // Cas 2 : /app/share/{uuid}
    final share = RegExp(r'/share/([a-zA-Z0-9\-]+)');
    final shareMatch = share.firstMatch(trimmed);
    if (shareMatch != null) return shareMatch.group(1);

    // Cas 3 : UUID brut (alphanumérique + tirets, ≥ 8 chars)
    if (RegExp(r'^[a-zA-Z0-9\-]{8,}$').hasMatch(trimmed)) return trimmed;

    return null;
  }

  // ─────────────────────── Upload via lien de dépôt ────────────────────────

  /// Sauvegarde locale + ouvre le lien de dépôt dans le navigateur.
  /// Retourne le fichier local pour que l'UI guide l'utilisateur.
  Future<File> backup({
    required String encryptionPassword,
    required String depositLink,
  }) async {
    final uuid = extractShareUuid(depositLink);
    if (uuid == null) {
      throw Exception(
        'Lien de dépôt invalide. Collez l\'URL depuis kDrive '
        '(ex: https://kdrive.infomaniak.com/app/collaborate/xxxxx/xxxxx)',
      );
    }

    final config = await _buildBackupConfig();
    final encrypted = _encrypt(jsonEncode(config), encryptionPassword);

    // Sauvegarder localement
    final localFile = await _localBackupFile();
    await localFile.parent.create(recursive: true);
    await localFile.writeAsBytes(encrypted);

    return localFile;
  }

  // ──────────────────────── Sauvegarde locale seule ────────────────────────

  /// Sauvegarde uniquement en local (sans kDrive).
  Future<File> backupLocally({required String encryptionPassword}) async {
    final config = await _buildBackupConfig();
    final encrypted = _encrypt(jsonEncode(config), encryptionPassword);

    final localFile = await _localBackupFile();
    await localFile.parent.create(recursive: true);
    await localFile.writeAsBytes(encrypted);
    return localFile;
  }

  // ──────────────────────────── Restauration ───────────────────────────────

  /// Restaure depuis la sauvegarde locale.
  Future<bool> restoreFromLocal({required String encryptionPassword}) async {
    final localFile = await _localBackupFile();
    if (!await localFile.exists()) return false;

    final bytes = await localFile.readAsBytes();
    return _restoreFromBytes(bytes, encryptionPassword);
  }

  /// Restaure depuis un fichier .enc quelconque (file picker).
  Future<bool> restoreFromFile({
    required String filePath,
    required String encryptionPassword,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final bytes = await file.readAsBytes();
    return _restoreFromBytes(bytes, encryptionPassword);
  }

  /// Vérifie si une sauvegarde locale existe et retourne sa date.
  Future<DateTime?> lastLocalBackupDate() async {
    final file = await _localBackupFile();
    if (!await file.exists()) return null;
    return file.lastModified();
  }

  /// Chemin du fichier de sauvegarde local.
  Future<File> _localBackupFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(
      '${appDir.path}/${AppConstants.kDriveLocalBackupDir}/'
      '${AppConstants.kDriveBackupFileName}',
    );
  }

  Future<bool> _restoreFromBytes(
    Uint8List bytes,
    String encryptionPassword,
  ) async {
    try {
      final decrypted = _decrypt(bytes, encryptionPassword);
      final config = jsonDecode(decrypted) as Map<String, dynamic>;
      await _restoreFromConfig(config);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _buildBackupConfig() async {
    final tags = await _db.getAllTags();
    final notionDbs = await _db.getNotionDatabases();
    final icsSubscriptions = await _db.getIcsSubscriptions();

    return {
      'version': 1,
      'backup_date': DateTime.now().toIso8601String(),
      'tags': tags.map((t) => t.toMap()).toList(),
      'notion_databases': notionDbs.map((d) => d.toMap()).toList(),
      'ics_subscriptions': icsSubscriptions.map((s) => s.toMap()).toList(),
    };
  }

  Future<void> _restoreFromConfig(Map<String, dynamic> config) async {
    // Les tokens sont gérés par flutter_secure_storage, non inclus dans backup
    // Restaurer les tags, BDD Notion, abonnements .ics
    final tags = config['tags'] as List? ?? [];
    final notionDbs = config['notion_databases'] as List? ?? [];
    final icsSubscriptions = config['ics_subscriptions'] as List? ?? [];

    // Restaurer les tags (suppression puis ré-import)
    final existingTags = await _db.getAllTags();
    for (final tag in existingTags) {
      if (tag.id != null) await _db.deleteTag(tag.id!);
    }
    for (final tagMap in tags) {
      final tag = TagModel.fromMap(tagMap as Map<String, dynamic>);
      await _db.insertTag(tag);
    }

    // Restaurer les BDD Notion
    final existingDbs = await _db.getNotionDatabases();
    for (final db in existingDbs) {
      if (db.id != null) await _db.deleteNotionDatabase(db.id!);
    }
    for (final dbMap in notionDbs) {
      final db = NotionDatabaseModel.fromMap(dbMap as Map<String, dynamic>);
      await _db.insertNotionDatabase(db);
    }

    // Restaurer les abonnements .ics
    final existingSubs = await _db.getIcsSubscriptions();
    for (final sub in existingSubs) {
      if (sub.id != null) await _db.deleteIcsSubscription(sub.id!);
    }
    for (final subMap in icsSubscriptions) {
      final sub = IcsSubscriptionModel.fromMap(subMap as Map<String, dynamic>);
      await _db.insertIcsSubscription(sub);
    }
  }

  Uint8List _encrypt(String plaintext, String password) {
    final key = Key.fromUtf8(password.padRight(32, '0').substring(0, 32));
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    // Format : [IV (16 bytes)] + [données chiffrées]
    final result = Uint8List(16 + encrypted.bytes.length);
    result.setAll(0, iv.bytes);
    result.setAll(16, encrypted.bytes);
    return result;
  }

  String _decrypt(Uint8List data, String password) {
    if (data.length < 16) throw Exception('Données invalides');

    final iv = IV(Uint8List.fromList(data.sublist(0, 16)));
    final encryptedBytes = data.sublist(16);

    final key = Key.fromUtf8(password.padRight(32, '0').substring(0, 32));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt(Encrypted(encryptedBytes), iv: iv);
  }

  /// Exporte les événements en CSV.
  static String exportToCsv(List<EventModel> events) {
    final lines = <String>[
      'ID,Titre,Début,Fin,Journée entière,Lieu,Description,Source,Catégories,Priorité',
    ];

    for (final event in events) {
      final categories =
          event.tags.where((t) => t.isCategory).map((t) => t.name).join('; ');
      final priority =
          event.tags.where((t) => t.isPriority).map((t) => t.name).join();

      lines.add([
        event.id?.toString() ?? '',
        _csvEscape(event.title),
        event.startDate.toIso8601String(),
        event.endDate.toIso8601String(),
        event.isAllDay ? 'Oui' : 'Non',
        _csvEscape(event.location ?? ''),
        _csvEscape(event.description ?? ''),
        event.source,
        _csvEscape(categories),
        _csvEscape(priority),
      ].join(','));
    }

    return lines.join('\n');
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ────────────────── V3 : Test connexion kDrive ───────────────────────────

  /// Teste la connexion au lien de dépôt kDrive.
  /// Retourne `true` si accessible (200/207), `false` sinon.
  /// Lance une requête OPTIONS/GET sur l'URL d'API du share.
  static Future<({bool success, int? statusCode, String? error})>
      testKDriveConnection(String depositLink) async {
    final uuid = extractShareUuid(depositLink);
    if (uuid == null) {
      return (
        success: false,
        statusCode: null,
        error: 'Lien de dépôt invalide',
      );
    }

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    try {
      // Tester l'API externe de share kDrive
      final testUrl =
          '${AppConstants.kDriveDepositApiBase}/$uuid/file';
      final response = await dio.get(testUrl);
      final ok = response.statusCode == 200 || response.statusCode == 207;
      AppLogger.instance.info(
        'kDrive',
        'Test connexion: status=${response.statusCode}, ok=$ok',
      );
      return (
        success: ok,
        statusCode: response.statusCode,
        error: ok ? null : 'Code HTTP ${response.statusCode}',
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      AppLogger.instance.error('kDrive', 'Test connexion échoué', e);
      return (
        success: false,
        statusCode: code,
        error: code != null ? 'Erreur HTTP $code' : e.message ?? 'Timeout',
      );
    } finally {
      dio.close();
    }
  }
}
