import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';

/// Service de sauvegarde/restauration sur kDrive (Infomaniak).
/// Configuration chiffrée AES-256.
class BackupService {
  final Dio _dio;
  final DatabaseHelper _db;
  String? _bearerToken;
  String? _driveId;

  BackupService({required DatabaseHelper db})
      : _db = db,
        _dio = Dio(BaseOptions(
          baseUrl: AppConstants.kDriveApiBase,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        ));

  void setCredentials({required String token, required String driveId}) {
    _bearerToken = token;
    _driveId = driveId;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  bool get isConfigured =>
      _bearerToken != null && _driveId != null;

  /// Sauvegarde la configuration sur kDrive.
  Future<void> backup({required String encryptionPassword}) async {
    final config = await _buildBackupConfig();
    final encrypted = _encrypt(jsonEncode(config), encryptionPassword);

    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/${AppConstants.kDriveBackupFileName}',
    );
    await tempFile.writeAsBytes(encrypted);

    // Créer le dossier si nécessaire
    await _ensureBackupFolder();

    // Upload via API kDrive
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        tempFile.path,
        filename: AppConstants.kDriveBackupFileName,
      ),
    });

    await _dio.post(
      '/$_driveId/files/upload',
      data: formData,
      queryParameters: {
        'directory_path': AppConstants.kDriveBackupFolder,
        'conflict': 'replace',
      },
    );

    await tempFile.delete();
  }

  /// Restaure la configuration depuis kDrive.
  Future<bool> restore({required String encryptionPassword}) async {
    try {
      // Chercher le fichier de sauvegarde
      final response = await _dio.get(
        '/$_driveId/files',
        queryParameters: {
          'path': '${AppConstants.kDriveBackupFolder}/${AppConstants.kDriveBackupFileName}',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final fileId = data['data']?['id']?.toString();
      if (fileId == null) return false;

      // Télécharger
      final downloadResponse = await _dio.get<List<int>>(
        '/$_driveId/files/$fileId/download',
        options: Options(responseType: ResponseType.bytes),
      );

      if (downloadResponse.data == null) return false;

      final decrypted = _decrypt(
        Uint8List.fromList(downloadResponse.data!),
        encryptionPassword,
      );

      final config = jsonDecode(decrypted) as Map<String, dynamic>;
      await _restoreFromConfig(config);
      return true;
    } catch (e) {
      return false;
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

    for (final tagMap in tags) {
      // Import des tags (gestion des doublons)
    }
  }

  Future<void> _ensureBackupFolder() async {
    try {
      await _dio.post(
        '/$_driveId/files/folder',
        data: {
          'name': 'unified_calendar',
          'parent_path': '/',
        },
      );
    } catch (_) {
      // Dossier probablement déjà existant
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
  static String exportToCsv(List<dynamic> events) {
    final lines = <String>[
      'ID,Titre,Début,Fin,Journée entière,Lieu,Description,Source,Catégories,Priorité',
    ];

    for (final event in events) {
      lines.add([
        event.id?.toString() ?? '',
        _csvEscape(event.title as String),
        event.startDate.toString(),
        event.endDate.toString(),
        (event.isAllDay as bool) ? 'Oui' : 'Non',
        _csvEscape(event.location as String? ?? ''),
        _csvEscape(event.description as String? ?? ''),
        event.source as String,
        '',
        '',
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
}
