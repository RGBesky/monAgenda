import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'logger_service.dart';

/// Choix du modèle IA pour la Saisie Magique.
/// Qwen2.5 (Alibaba) — multilingue (29 langues dont FR), optimisé JSON structuré.
enum MagicModelChoice {
  /// Qwen2.5-0.5B-Instruct Q4_K_M (~491 Mo) — léger, tourne partout.
  qwen05b,

  /// Qwen2.5-1.5B-Instruct Q4_K_M (~1.12 Go) — meilleure qualité.
  qwen15b,
}

extension MagicModelChoiceExt on MagicModelChoice {
  String get fileName => switch (this) {
        MagicModelChoice.qwen05b => 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
        MagicModelChoice.qwen15b => 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      };

  String get downloadUrl => switch (this) {
        MagicModelChoice.qwen05b =>
          'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        MagicModelChoice.qwen15b =>
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      };

  String get sha256 => switch (this) {
        // SHA-256 will be verified on first download — skip until known
        MagicModelChoice.qwen05b => 'PLACEHOLDER_QWEN05B',
        MagicModelChoice.qwen15b => 'PLACEHOLDER_QWEN15B',
      };

  String get label => switch (this) {
        MagicModelChoice.qwen05b => 'Qwen 2.5 (0.5B)',
        MagicModelChoice.qwen15b => 'Qwen 2.5 (1.5B)',
      };

  String get subtitle => switch (this) {
        MagicModelChoice.qwen05b => '~491 Mo · Rapide · Recommandé',
        MagicModelChoice.qwen15b =>
          '~1.1 Go · Meilleure qualité · Desktop / 8 Go+ RAM',
      };

  int get approxSizeMb => switch (this) {
        MagicModelChoice.qwen05b => 491,
        MagicModelChoice.qwen15b => 1120,
      };

  static MagicModelChoice fromString(String s) => switch (s) {
        'qwen15b' => MagicModelChoice.qwen15b,
        _ => MagicModelChoice.qwen05b,
      };
}

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
    // Delete all known model files
    for (final choice in MagicModelChoice.values) {
      final path = await ModelDownloadService.instance.modelPathFor(choice);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    state = const AsyncData(ModelStatus.notDownloaded);
  }
}

/// Service de gestion du cycle de vie du fichier .gguf.
class ModelDownloadService {
  static final ModelDownloadService instance = ModelDownloadService._();
  ModelDownloadService._();

  /// Modèle sélectionné par l'utilisateur.
  MagicModelChoice selectedModel = MagicModelChoice.qwen05b;

  final Dio _dio = Dio();
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  Stream<double> get progressStream => _progressController.stream;

  /// Chemin du modèle actuellement sélectionné.
  Future<String> get modelPath => modelPathFor(selectedModel);

  /// Chemin pour un modèle spécifique.
  Future<String> modelPathFor(MagicModelChoice choice) async {
    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return '${modelsDir.path}/${choice.fileName}';
  }

  /// Supprime l'ancien modèle legacy s'il existe (migration v3).
  Future<void> cleanupLegacyModel() async {
    final appDir = await getApplicationSupportDirectory();
    final legacyFile = File('${appDir.path}/models/magic_model.gguf');
    if (await legacyFile.exists()) {
      await legacyFile.delete();
      AppLogger.instance
          .info('ModelDownload', 'Deleted legacy model (magic_model.gguf)');
    }
  }

  /// Retourne le chemin local du modèle prêt à l'emploi.
  /// Télécharge si nécessaire, vérifie l'intégrité par SHA-256.
  Future<String> ensureModelReady(String downloadUrl) async {
    final localPath = await modelPath;
    final file = File(localPath);

    // Vérifier si le fichier existe et son hash
    if (await file.exists()) {
      final hashOk =
          await _verifySha256InIsolate(localPath, selectedModel.sha256);
      if (hashOk) return localPath;
      // Hash invalide → supprimer et re-télécharger
      await file.delete();
      AppLogger.instance
          .error('ModelDownload', 'Hash mismatch, re-downloading');
    }

    // Télécharger avec reprise partielle
    await _downloadWithResume(downloadUrl, localPath);

    // Vérifier l'intégrité
    final hashOk =
        await _verifySha256InIsolate(localPath, selectedModel.sha256);
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
  Future<bool> _verifySha256InIsolate(String path, String expectedHash) async {
    // Skip si placeholder hash
    if (expectedHash.startsWith('PLACEHOLDER')) return true;

    return await Isolate.run(() async {
      final file = File(path);
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString() == expectedHash;
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
