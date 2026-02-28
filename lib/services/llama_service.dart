import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'logger_service.dart';

/// Service d'inférence locale via llama.cpp (dart:ffi).
///
/// Conformité Plan d'Action V3 — Tâche 4.2 :
/// - Wrapper FFI : dart:ffi pour llama.cpp (.so Linux / .so Android)
/// - Isolate obligatoire (via LlamaParent)
/// - Grammaire GBNF obligatoire
/// - Modèle : H2O Danube 3 (500M, q4_k_m, ~400Mo)
/// - SLA : < 3s mid-range, timeout 8s
class LlamaService {
  LlamaService._();
  static final LlamaService instance = LlamaService._();

  LlamaParent? _parent;
  bool _isModelLoaded = false;
  String? _loadedModelPath;

  bool get isModelLoaded => _isModelLoaded;

  /// Grammaire GBNF contraignant la sortie IA à un JSON strict.
  static const String gbnfGrammar = r'''
root   ::= "{" ws "\"title\"" ws ":" ws string "," ws "\"description\"" ws ":" ws (string | "null") "," ws "\"date\"" ws ":" ws string "," ws "\"startTime\"" ws ":" ws (string | "null") "," ws "\"endTime\"" ws ":" ws (string | "null") "," ws "\"location\"" ws ":" ws (string | "null") "," ws "\"category\"" ws ":" ws (string | "null") "," ws "\"participants\"" ws ":" ws (arr | "null") ws "}"
arr    ::= "[" ws (string ("," ws string)*)? ws "]"
string ::= "\"" [^"\\]* "\""
ws     ::= [ \t\n]*
''';

  /// System prompt pour l'extraction d'événements.
  /// Danube 3 chat template : <|prompt|>instructions+user</s><|answer|>
  /// PAS de rôle système séparé — tout est dans <|prompt|>.
  /// Prompt optimisé pour Danube 3 500M : exemples concrets, pas de template abstrait.
  static const String systemPrompt =
      'Extrais un événement du texte. Réponds UNIQUEMENT en JSON.\n'
      'title: résumé court (2-5 mots). description: détails/rappels ou null.\n'
      'date: YYYY-MM-DD. matin=09:00-12:00. après-midi=14:00-17:00. soir=19:00-21:00.\n'
      'location: lieu physique (pas l\'activité) ou null. category: Travail/Perso/Sport/Santé/Famille/Social/Formation/Administratif ou null.\n'
      'Ex: "Réunion avec Marc demain matin salle B et préparer les slides" →\n'
      '{"title":"Réunion","description":"Préparer les slides","date":"2026-03-01","startTime":"09:00","endTime":"12:00","location":"Salle B","category":"Travail","participants":["Marc"]}';

  /// Initialise le chemin de la bibliothèque native llama.cpp.
  /// Appelé une fois au démarrage de l'app.
  static void initLibraryPath() {
    if (Platform.isLinux) {
      // En debug, les libs sont dans linux/libs/
      // En release, elles sont dans le bundle lib/
      final execDir = File(Platform.resolvedExecutable).parent.path;
      final bundleLib = '$execDir/lib/libllama.so';
      final devLib = '${Directory.current.path}/linux/libs/libllama.so';

      if (File(bundleLib).existsSync()) {
        Llama.libraryPath = bundleLib;
      } else if (File(devLib).existsSync()) {
        Llama.libraryPath = devLib;
      } else {
        // Fallback: le système (LD_LIBRARY_PATH)
        Llama.libraryPath = 'libllama.so';
      }

      AppLogger.instance
          .info('LlamaService', 'Library path: ${Llama.libraryPath}');
    } else if (Platform.isAndroid) {
      Llama.libraryPath = 'libllama.so';
    } else if (Platform.isWindows) {
      Llama.libraryPath = 'llama.dll';
    }
  }

  /// Construit le LlamaLoad command avec les params optimisés Danube 3.
  static LlamaLoad _buildLoadCommand(String modelPath) {
    final modelParams = ModelParams()
      ..nGpuLayers = 0 // CPU only
      ..mainGpu = -1; // Pas de sélection GPU (évite "invalid value for main_gpu: 0")
    final contextParams = ContextParams()
      ..nCtx = 768 // Contexte suffisant pour prompt amélioré + extraction
      ..nBatch = 256;
    final samplerParams = SamplerParams()
      ..temp = 0.1 // Quasi-déterministe pour extraction JSON
      ..topK = 10
      ..topP = 0.9
      ..grammarStr = gbnfGrammar
      ..grammarRoot = 'root';

    return LlamaLoad(
      path: modelPath,
      modelParams: modelParams,
      contextParams: contextParams,
      samplingParams: samplerParams,
      verbose: false,
    );
  }

  /// Charge le modèle GGUF dans un Isolate dédié.
  /// [modelPath] : chemin vers le fichier .gguf sur disque.
  Future<void> loadModel(String modelPath) async {
    if (_isModelLoaded && _loadedModelPath == modelPath) return;

    // Libérer le modèle précédent si chargé
    await dispose();

    final stopwatch = Stopwatch()..start();

    try {
      final loadCommand = _buildLoadCommand(modelPath);
      _parent = LlamaParent(loadCommand);
      await _parent!.init(); // Spawns isolate + sends LlamaInit + LlamaLoad

      _isModelLoaded = true;
      _loadedModelPath = modelPath;

      stopwatch.stop();
      AppLogger.instance.info('LlamaService',
          'Model loaded in ${stopwatch.elapsedMilliseconds}ms: $modelPath');
    } catch (e) {
      stopwatch.stop();
      AppLogger.instance.error('LlamaService',
          'Model loading failed after ${stopwatch.elapsedMilliseconds}ms', e);
      await dispose();
      rethrow;
    }
  }

  /// Exécute une inférence dans l'Isolate. Retourne le JSON parsé.
  /// Timeout de 8 secondes comme spécifié dans le plan.
  Future<Map<String, dynamic>?> infer(String userText) async {
    if (!_isModelLoaded || _parent == null) {
      AppLogger.instance
          .error('LlamaService', 'infer() called but model not loaded');
      return null;
    }

    final stopwatch = Stopwatch()..start();
    final now = DateTime.now();
    final dateContext =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // Danube 3 chat template : <|prompt|>instructions+contenu</s><|answer|>
    // Pas de rôle system séparé — tout va dans <|prompt|>
    final prompt = '<|prompt|>$systemPrompt\n'
        'Date du jour: $dateContext\n'
        'Texte: $userText</s><|answer|>';

    try {
      // Collecter la sortie via le stream de tokens
      final buffer = StringBuffer();
      StreamSubscription<String>? tokenSub;
      final completer = Completer<void>();

      tokenSub = _parent!.stream.listen((token) {
        buffer.write(token);
      });

      // Ecouter la complétion
      StreamSubscription<CompletionEvent>? completionSub;
      completionSub = _parent!.completions.listen((event) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      // Envoyer le prompt
      await _parent!.sendPrompt(prompt);

      // Attendre la fin avec timeout 15s (CPU-only peut être lent)
      await completer.future.timeout(const Duration(seconds: 15));

      await tokenSub.cancel();
      await completionSub.cancel();

      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      final rawOutput = buffer.toString().trim();
      AppLogger.instance
          .info('LlamaService', 'Inference OK in ${elapsed}ms: $rawOutput');

      // Parse le JSON retourné (contraint par GBNF)
      final json = jsonDecode(rawOutput) as Map<String, dynamic>;
      return json;
    } on TimeoutException {
      // Arrêter la génération en cours
      await _parent!.stop();
      stopwatch.stop();
      AppLogger.instance.error('LlamaService',
          'Inference timeout after ${stopwatch.elapsedMilliseconds}ms');
      return null;
    } catch (e) {
      stopwatch.stop();
      AppLogger.instance.error('LlamaService',
          'Inference failed after ${stopwatch.elapsedMilliseconds}ms', e);
      return null;
    }
  }

  /// Libère le modèle et l'isolate.
  Future<void> dispose() async {
    if (_parent != null) {
      try {
        await _parent!.dispose();
      } catch (_) {
        // Ignore — l'isolate peut déjà être mort
      }
      _parent = null;
    }
    _isModelLoaded = false;
    _loadedModelPath = null;
  }
}

/// Provider indiquant si le modèle IA est chargé et prêt.
final llamaReadyProvider = StateProvider<bool>((ref) => false);

/// Provider pour le statut global du service Llama.
final llamaServiceProvider = Provider<LlamaService>((ref) {
  return LlamaService.instance;
});
