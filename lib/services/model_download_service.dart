import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'logger_service.dart';

/// SHA-256 attendu du modèle GGUF H2O Danube 3 500M Q4_K_M.
const String kModelSha256 =
    '021f78849c5670ecb2aa4cd7c5972eee0a3c9e41e33e5902c408a2ab989f0b43';

/// Nom du fichier modèle sur disque.
const String kModelFileName = 'magic_model.gguf';

/// URL de téléchargement par défaut (HuggingFace, repo officiel h2oai).
const String kModelDownloadUrl =
    'https://huggingface.co/h2oai/h2o-danube3-500m-chat-GGUF/resolve/main/h2o-danube3-500m-chat-Q4_K_M.gguf';

/// Exception d'intégrité du modèle.
class ModelIntegrityException implements Exception {
  final String message;
  const ModelIntegrityException(this.message);
  @override
  String toString() => 'ModelIntegrityException: $message';
}

/// Statut du modèle IA.
enum ModelStatus {
  notDownloaded,
  downloading,
  ready,
  error,
}

/// Provider du statut de téléchargement du modèle.
final modelDownloadStatusProvider =
    AsyncNotifierProvider<ModelDownloadNotifier, ModelStatus>(
        ModelDownloadNotifier.new);

/// Provider du progrès de téléchargement (0.0 à 1.0).
final modelDownloadProgressProvider = StreamProvider<double>((ref) {
  return ModelDownloadService.instance.progressStream;
});

class ModelDownloadNotifier extends AsyncNotifier<ModelStatus> {
  @override
  Future<ModelStatus> build() async {
    final localPath = await ModelDownloadService.instance.modelPath;
    if (await File(localPath).exists()) {
      return ModelStatus.ready;
    }
    return ModelStatus.notDownloaded;
  }

  Future<String> ensureModelReady(String downloadUrl) async {
    state = const AsyncData(ModelStatus.downloading);
    try {
      final path =
          await ModelDownloadService.instance.ensureModelReady(downloadUrl);
      state = const AsyncData(ModelStatus.ready);
      return path;
    } catch (e) {
      state = const AsyncData(ModelStatus.error);
      rethrow;
    }
  }

  Future<void> deleteModel() async {
    final localPath = await ModelDownloadService.instance.modelPath;
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
    state = const AsyncData(ModelStatus.notDownloaded);
  }
}

/// Service de gestion du cycle de vie du fichier .gguf.
class ModelDownloadService {
  static final ModelDownloadService instance = ModelDownloadService._();
  ModelDownloadService._();

  final Dio _dio = Dio();
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  Stream<double> get progressStream => _progressController.stream;

  Future<String> get modelPath async {
    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return '${modelsDir.path}/$kModelFileName';
  }

  /// Retourne le chemin local du modèle prêt à l'emploi.
  /// Télécharge si nécessaire, vérifie l'intégrité par SHA-256.
  Future<String> ensureModelReady(String downloadUrl) async {
    final localPath = await modelPath;
    final file = File(localPath);

    // Vérifier si le fichier existe et son hash
    if (await file.exists()) {
      final hashOk = await _verifySha256InIsolate(localPath);
      if (hashOk) return localPath;
      // Hash invalide → supprimer et re-télécharger
      await file.delete();
      AppLogger.instance
          .error('ModelDownload', 'Hash mismatch, re-downloading');
    }

    // Télécharger avec reprise partielle
    await _downloadWithResume(downloadUrl, localPath);

    // Vérifier l'intégrité
    final hashOk = await _verifySha256InIsolate(localPath);
    if (!hashOk) {
      await File(localPath).delete();
      throw const ModelIntegrityException(
          'Le fichier téléchargé est corrompu (SHA-256 mismatch)');
    }

    return localPath;
  }

  Future<void> _downloadWithResume(String url, String localPath) async {
    final partPath = '$localPath.part';
    final partFile = File(partPath);
    int startByte = 0;

    if (await partFile.exists()) {
      startByte = await partFile.length();
    }

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
        ),
      );

      final contentLength =
          int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
      final totalLength = startByte + contentLength;

      final sink = partFile.openWrite(mode: FileMode.append);
      int received = startByte;

      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalLength > 0) {
          _progressController.add(received / totalLength);
        }
      }

      await sink.flush();
      await sink.close();

      // Renommer .part → final
      await partFile.rename(localPath);
      _progressController.add(1.0);
    } catch (e) {
      AppLogger.instance.error('ModelDownload', 'Download failed', e);
      rethrow;
    }
  }

  /// Vérifie le SHA-256 du fichier dans un Isolate pour ne pas bloquer le UI.
  Future<bool> _verifySha256InIsolate(String path) async {
    // Skip si placeholder hash
    if (kModelSha256.startsWith('PLACEHOLDER')) return true;

    return await Isolate.run(() async {
      final file = File(path);
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString() == kModelSha256;
    });
  }

  /// Taille du modèle sur disque (en Mo).
  Future<double?> get modelSizeMb async {
    final localPath = await modelPath;
    final file = File(localPath);
    if (await file.exists()) {
      final bytes = await file.length();
      return bytes / (1024 * 1024);
    }
    return null;
  }
}
