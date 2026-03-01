import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/database/magic_habits_repository.dart';
import '../core/models/event_model.dart';
import '../providers/settings_provider.dart';
import '../services/logger_service.dart';
import '../services/llama_service.dart';
import '../services/model_download_service.dart';

/// Provider pour la Saisie Magique.
final magicEntryProvider =
    AsyncNotifierProvider<MagicEntryNotifier, EventModel?>(
        MagicEntryNotifier.new);

/// Indique si le modèle IA doit être téléchargé (true = absent).
final modelNeedsDownloadProvider = StateProvider<bool>((ref) => false);

class MagicEntryNotifier extends AsyncNotifier<EventModel?> {
  @override
  Future<EventModel?> build() async => null;

  /// Vérifie si le modèle est prêt (chargé ou sur disque).
  Future<bool> isModelAvailable() async {
    final llamaService = ref.read(llamaServiceProvider);
    if (llamaService.isModelLoaded) return true;
    final modelPath = await ModelDownloadService.instance.modelPath;
    return File(modelPath).exists();
  }

  /// Télécharge le modèle depuis HuggingFace. Retourne true si succès.
  Future<bool> downloadModel() async {
    try {
      final choice = ModelDownloadService.instance.selectedModel;
      AppLogger.instance.info(
          'MagicEntry', 'Downloading ${choice.label} from HuggingFace...');
      await ModelDownloadService.instance.ensureModelReady(choice.downloadUrl);
      ref.read(modelNeedsDownloadProvider.notifier).state = false;
      // Mettre à jour le statut global
      ref.invalidate(modelDownloadStatusProvider);
      AppLogger.instance.info('MagicEntry', 'Model downloaded successfully');
      return true;
    } catch (e) {
      AppLogger.instance.error('MagicEntry', 'Model download failed', e);
      return false;
    }
  }

  /// Parse un texte en langage naturel et retourne un EventModel.
  ///
  /// Stratégie : LLM-first quand le modèle est dispo, regex en fallback.
  /// Si le modèle n'est pas disponible, signale via modelNeedsDownloadProvider
  /// et utilise le regex en attendant.
  Future<EventModel?> parseText(String input) async {
    final stopwatch = Stopwatch()..start();
    state = const AsyncLoading();

    try {
      final llamaService = ref.read(llamaServiceProvider);
      final habitsRepo = ref.read(magicHabitsRepositoryProvider);

      // Déterminer la source par défaut selon la config utilisateur
      final settings = ref.read(settingsProvider).valueOrNull;
      final String defaultSource;
      if (settings != null && settings.isInfomaniakConfigured) {
        defaultSource = AppConstants.sourceInfomaniak;
      } else if (settings != null && settings.isNotionConfigured) {
        defaultSource = AppConstants.sourceNotion;
      } else {
        defaultSource = AppConstants.sourceInfomaniak;
      }

      // ── Étape 0 : Charger les habitudes utilisateur ──
      final habits = await habitsRepo.lookupForText(input);
      if (habits.isNotEmpty) {
        AppLogger.instance.info('MagicEntry', 'Habits found: $habits');
      }

      // ── Étape 1 : Essayer de charger le modèle si pas encore fait ──
      if (!llamaService.isModelLoaded) {
        try {
          final modelPath = await ModelDownloadService.instance.modelPath;
          final exists = await File(modelPath).exists();

          if (!exists) {
            // Signaler que le modèle doit être téléchargé (l'UI demandera)
            ref.read(modelNeedsDownloadProvider.notifier).state = true;
            AppLogger.instance
                .info('MagicEntry', 'Model not found — falling back to regex');
          } else {
            // Charger le modèle existant
            AppLogger.instance
                .info('MagicEntry', 'Lazy-loading Qwen2.5 model...');
            await llamaService.loadModel(modelPath);
            ref.read(llamaReadyProvider.notifier).state = true;
            AppLogger.instance
                .info('MagicEntry', 'Qwen2.5 model loaded successfully');
          }
        } catch (e) {
          AppLogger.instance.error('MagicEntry', 'Model load failed: $e', e);
        }
      }

      // ── Étape 2 : Inférence LLM (Qwen2.5) — source unique quand modèle dispo ──
      if (llamaService.isModelLoaded) {
        AppLogger.instance.info('MagicEntry', 'Calling Qwen2.5 for: "$input"');

        // Construire le contexte des habitudes pour le LLM
        String? habitsContext;
        if (habits.isNotEmpty) {
          final lines = habits.entries
              .map((e) => 'Défaut: ${e.key}=${e.value}')
              .join('. ');
          habitsContext = 'Habitudes utilisateur: $lines';
        }

        final iaResult =
            await llamaService.infer(input, habitsContext: habitsContext);
        AppLogger.instance.info('MagicEntry', 'Qwen2.5 raw result: $iaResult');
        if (iaResult != null) {
          // Appliquer les habitudes comme fallback sur les champs null
          final enriched = _applyHabitsToJson(iaResult, habits);
          final event = MagicEntryService.buildFromIaJson(enriched, input,
              defaultSource: defaultSource);
          if (event != null) {
            stopwatch.stop();
            AppLogger.instance.info('MagicEntry',
                'LLM parse OK in ${stopwatch.elapsedMilliseconds}ms — title="${event.title}"');
            state = AsyncData(event);
            return event;
          }
        }
        // LLM a échoué → fallback regex (modèle chargé mais résultat inutilisable)
        AppLogger.instance.info('MagicEntry',
            'LLM returned unusable result, falling back to regex');
      } else {
        AppLogger.instance
            .info('MagicEntry', 'Model not loaded — using regex only');
      }

      // ── Étape 3 : Fallback regex (uniquement si LLM indisponible ou échoué) ──
      final partial = MagicEntryService.parsePartialRegex(input,
          habits: habits, defaultSource: defaultSource);
      stopwatch.stop();
      AppLogger.instance.info('MagicEntry',
          'Regex fallback in ${stopwatch.elapsedMilliseconds}ms — title="${partial?.title}"');
      state = AsyncData(partial);
      return partial;
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('[MagicEntry] CRASH: $e\n$stack');
      AppLogger.instance.error('MagicEntry',
          'Parse failed in ${stopwatch.elapsedMilliseconds}ms', e);
      state = AsyncError(e, stack);
      return null;
    }
  }

  /// Applique les habitudes utilisateur comme fallback sur les champs null du JSON LLM.
  static Map<String, dynamic> _applyHabitsToJson(
      Map<String, dynamic> json, Map<String, String> habits) {
    if (habits.isEmpty) return json;
    final result = Map<String, dynamic>.from(json);
    for (final entry in habits.entries) {
      final field = entry.key;
      final value = entry.value;
      // Ne remplit que si le champ est null ou absent
      if (result[field] == null || result[field] == 'null') {
        result[field] = value;
      }
    }
    return result;
  }

  /// Apprend les habitudes utilisateur depuis les corrections.
  ///
  /// Compare le résultat original (IA ou regex) avec la version sauvegardée
  /// par l'utilisateur. Pour chaque champ corrigé (ajouté par l'utilisateur),
  /// extrait un mot-clé de l'input et crée une habitude.
  ///
  /// Exemple : input="aller à la messe", original.location=null,
  /// final.location="Saint-Défendent" → habitude(messe, location, Saint-Défendent)
  Future<void> learnFromCorrection({
    required String inputText,
    required EventModel originalEvent,
    required EventModel correctedEvent,
  }) async {
    final habitsRepo = ref.read(magicHabitsRepositoryProvider);
    final inputLc = inputText.toLowerCase();

    // Mots significatifs de l'input (>= 4 caractères, pas des stop words)
    final keywords = _extractKeywords(inputLc);
    if (keywords.isEmpty) return;

    // Comparer chaque champ corrigé
    final corrections = <String, String>{};

    if (correctedEvent.location != null &&
        correctedEvent.location != originalEvent.location &&
        correctedEvent.location!.isNotEmpty) {
      corrections['location'] = correctedEvent.location!;
    }
    if (correctedEvent.description != null &&
        correctedEvent.description != originalEvent.description &&
        correctedEvent.description!.isNotEmpty) {
      corrections['description'] = correctedEvent.description!;
    }

    if (corrections.isEmpty) return;

    // Pour chaque correction, associer au mot-clé le plus pertinent
    for (final entry in corrections.entries) {
      // Utiliser le premier mot-clé significatif comme ancre
      final keyword = keywords.first;
      await habitsRepo.upsert(
        keyword: keyword,
        fieldName: entry.key,
        fieldValue: entry.value,
      );
      AppLogger.instance.info('MagicEntry',
          'Habit learned: "$keyword" → ${entry.key}=${entry.value}');
    }
  }

  /// Extrait les mots-clés significatifs d'un texte (>= 4 chars, pas stop words).
  static List<String> _extractKeywords(String text) {
    const stopWords = {
      'aller',
      'faire',
      'voir',
      'avec',
      'pour',
      'dans',
      'chez',
      'mais',
      'donc',
      'puis',
      'aussi',
      'tout',
      'tous',
      'cette',
      'demain',
      'matin',
      'soir',
      'aujourd',
      'après',
      'avant',
      'faut',
      'penser',
      'comme',
      'être',
      'avoir',
      'très',
      'bien',
      'plus',
      'encore',
      'déjà',
      'toujours',
      'jamais',
    };
    return text
        .replaceAll(RegExp(r'[^a-zàâäéèêëïîôùûç\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4 && !stopWords.contains(w))
        .toList();
  }
}

/// Service de parsing NLP 100% local.
///
/// Stratégie (Plan V3 §4.2) :
/// 1. Regex-first : extraction #tags, @mentions, heures, dates relatives,
///    moments de la journée, participants "avec X", lieux
/// 2. Si title + date extraits → retourne directement (~80% des cas)
/// 3. Sinon → fallback llama.cpp via LlamaService (Isolate + GBNF)
/// 4. Post-validation : title.isNotEmpty, date cohérente, startTime < endTime
class MagicEntryService {
  // ──────────────────────────────────────────────────────────────
  // Regex patterns — Français NLP
  // ──────────────────────────────────────────────────────────────

  /// Catégorie : #travail, #perso, #sport ...
  static final _categoryPattern = RegExp(r'#(\w+)');

  /// Participants explicites : @Jean, @Marie
  static final _mentionPattern = RegExp(r'@(\w+)');

  /// Participants implicites : "avec X", "avec ma mère", "avec Jean et Marie"
  static final _avecPattern = RegExp(
    r'(?:^|\s)avec\s+(.+?)(?:\s+(?:à|au|chez|vers|pour|de\s+\d|demain|lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|ce\s+(?:soir|matin)|cet\s+après-midi)|[,.]|$)',
    caseSensitive: false,
  );

  /// Heures explicites : 20h00, 14:30, 9h, 20h30-22h00
  static final _timePattern = RegExp(r'(\d{1,2})[h:](\d{2})');
  static final _simpleTimePattern = RegExp(r'\b(\d{1,2})h\b');

  /// Plage horaire : "de 14h à 16h", "14h-16h", "14h30-16h00"
  static final _timeRangePattern = RegExp(
    r'(?:de\s+)?(\d{1,2})[h:]?(\d{2})?\s*(?:à|-)\s*(\d{1,2})[h:]?(\d{2})?',
    caseSensitive: false,
  );

  /// Moments de la journée : "matin", "ce matin", "cet après-midi", "ce soir", "cette nuit", etc.
  static final _momentPattern = RegExp(
    r"\b(?:"
    r"cet\s+après[- ]midi|ce\s+matin|ce\s+soir|cette\s+nuit|"
    r"en\s+fin\s+de?\s+(?:matinée|journée|après[- ]midi|soirée)|"
    r"en\s+(?:matinée|soirée)|"
    r"(?:la\s+)?matinée|(?:le\s+)?matin|"
    r"(?:l[' ]\s*)?après[- ]midi|"
    r"(?:la\s+)?soirée|(?:le\s+)?soir"
    r")\b",
    caseSensitive: false,
  );

  /// Dates relatives : demain, après-demain, aujourd'hui, jours de la semaine
  static final _dateRelativePattern = RegExp(
    r"\b(demain|après[- ]demain|aujourd'?hui|"
    r'lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)\b',
    caseSensitive: false,
  );

  /// "prochain/prochaine" après un jour : "lundi prochain", "semaine prochaine"
  static final _prochainPattern = RegExp(
    r'\b(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)\s+prochain\b',
    caseSensitive: false,
  );

  /// Dates absolues : 15/03, 15-03-2025, 15.03.2025
  static final _dateAbsolutePattern = RegExp(
    r'\b(\d{1,2})[/\-.](\d{1,2})(?:[/\-.](\d{2,4}))?\b',
  );

  /// Lieu : "à Paris", "au cinéma", "chez maman", "à la Valentine"
  /// Limite la capture à 1-4 mots maximum (noms de lieux).
  /// Chaque mot capturé ne doit PAS être un verbe courant ou mot temporel.
  /// Note : dates/heures sont déjà retirées du `remaining` avant cette regex.
  static final _locationPattern = RegExp(
    r"(?:^|\s)(?:à|au|chez|@)\s+"
    r"(?!(?:acheter|faire|voir|prendre|chercher|manger|boire|préparer|organiser|trouver|aller|partir|rentrer|venir)\b)"
    r"((?:l[ae']\s+|les?\s+|la\s+|du\s+)?"
    r"[\w'éèêëàâäôöùûüçïî-]+"
    r"(?:\s+(?!(?:aller|acheter|faire|voir|prendre|chercher|manger|boire|préparer|organiser|trouver|partir|rentrer|venir|"
    r"pour|avec|et|ou|puis|ce|cet|cette|en|je|on|il|elle|nous|qui|que|"
    r"demain|après|aujourd|lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|"
    r"prochain|prochaine|matin|midi|soir|nuit|"
    r"\d)\b)[\w'éèêëàâäôöùûüçïî-]+){0,4})",
    caseSensitive: false,
  );

  /// Durée : "pendant 2h", "pendant 30 minutes", "pendant 1h30"
  static final _durationPattern = RegExp(
    r'(?:pendant|durée\s*:?\s*)\s*(\d+)\s*(?:h(?:eures?)?(?:\s*(\d+)\s*(?:min(?:utes?)?)?)?|min(?:utes?)?)',
    caseSensitive: false,
  );

  // ──────────────────────────────────────────────────────────────
  // Parse methods
  // ──────────────────────────────────────────────────────────────

  /// Parse complet : retourne un EventModel si title + date sont extraits.
  static EventModel? parseWithRegex(String input,
      {Map<String, String> habits = const {},
      String defaultSource = 'infomaniak'}) {
    final parsed = _extractAll(input);
    // Appliquer les habitudes sur les champs null
    _applyHabitsToParsed(parsed, habits);
    final title = parsed['title'] as String?;
    if (title == null || title.isEmpty || parsed['startDate'] == null) {
      return null;
    }
    return _buildEventModel(parsed, defaultSource: defaultSource);
  }

  /// Parse partiel : retourne un EventModel avec ce qu'on a pu extraire.
  static EventModel? parsePartialRegex(String input,
      {Map<String, String> habits = const {},
      String defaultSource = 'infomaniak'}) {
    final parsed = _extractAll(input);
    // Appliquer les habitudes sur les champs null
    _applyHabitsToParsed(parsed, habits);
    final title = parsed['title'] as String?;
    if (title == null || title.isEmpty) {
      // Dernier recours : utiliser l'input brut comme titre
      parsed['title'] = _cleanTitle(input);
    }
    return _buildEventModel(parsed, defaultSource: defaultSource);
  }

  /// Construit un EventModel depuis le JSON retourné par l'IA.
  ///
  /// **Approche hybride** :
  /// - LLM → titre, description, lieu, catégorie, participants (sémantique)
  /// - Regex Dart → date, heures, moments, durée (déterministe, fiable)
  /// Le LLM 500M hallucine trop sur les calculs temporels.
  static EventModel? buildFromIaJson(
      Map<String, dynamic> json, String originalInput,
      {String defaultSource = 'infomaniak'}) {
    try {
      final rawTitle = json['title'] as String?;
      if (rawTitle == null || rawTitle.isEmpty) return null;

      // ── Champs sémantiques (LLM) ──
      final locationRaw = json['location'] as String?;
      String? location =
          (locationRaw != null && locationRaw != 'null') ? locationRaw : null;
      // Nettoyer les mots temporels qui fuient dans le lieu
      if (location != null) {
        location = _cleanTemporalFromLocation(location);
        if (location.isEmpty) location = null;
      }
      final title = _smartTitle(rawTitle, location: location);
      if (title.isEmpty) return null;

      final category = json['category'] as String?;
      final description = json['description'] as String?;

      final participants = <String>[];
      final rawParticipants = json['participants'];
      if (rawParticipants is List) {
        for (final p in rawParticipants) {
          if (p is String && p.isNotEmpty) participants.add(p);
        }
      }

      // ── Champs temporels (regex Dart — JAMAIS le LLM) ──
      // On extrait date, moment, heures, durée directement du texte original
      final regexParsed = _extractTemporalFromInput(originalInput);

      return _buildEventModel({
        'title': title,
        'description':
            (description != null && description != 'null') ? description : null,
        'startDate': regexParsed['startDate'],
        'startHour': regexParsed['startHour'],
        'startMinute': regexParsed['startMinute'],
        'endHour': regexParsed['endHour'],
        'endMinute': regexParsed['endMinute'],
        'location': location,
        'category': (category != null && category != 'null') ? category : null,
        'participants': participants,
      }, defaultSource: defaultSource);
    } catch (e) {
      AppLogger.instance.error('MagicEntry', 'buildFromIaJson failed', e);
      return null;
    }
  }

  /// Extrait TOUS les champs temporels d'un texte via regex Dart.
  /// Utilisé par le path hybride (LLM titre/lieu + regex dates/heures).
  static Map<String, dynamic> _extractTemporalFromInput(String input) {
    String remaining = input;
    DateTime? startDate;
    int? startHour;
    int? startMinute;
    int? endHour;
    int? endMinute;

    // ── Durée (pendant 40min, pendant 2h...) ──
    int? durationMinutes;
    final durationMatch = _durationPattern.firstMatch(remaining);
    if (durationMatch != null) {
      final mainVal = int.tryParse(durationMatch.group(1)!) ?? 0;
      final fullMatch = durationMatch.group(0)!.toLowerCase();
      if (fullMatch.contains('h')) {
        durationMinutes = mainVal * 60;
        final extraMin = durationMatch.group(2);
        if (extraMin != null) {
          durationMinutes =
              (durationMinutes ?? 0) + (int.tryParse(extraMin) ?? 0);
        }
      } else {
        durationMinutes = mainVal;
      }
      remaining = remaining.replaceFirst(durationMatch.group(0)!, '').trim();
    }

    // ── Plage horaire (de 14h à 16h) ──
    final rangeMatch = _timeRangePattern.firstMatch(remaining);
    if (rangeMatch != null) {
      startHour = int.tryParse(rangeMatch.group(1)!);
      startMinute = int.tryParse(rangeMatch.group(2) ?? '0') ?? 0;
      endHour = int.tryParse(rangeMatch.group(3)!);
      endMinute = int.tryParse(rangeMatch.group(4) ?? '0') ?? 0;
      remaining = remaining.replaceFirst(rangeMatch.group(0)!, '').trim();
    }

    // ── Heures isolées (20h00, 14:30, 9h) ──
    if (startHour == null) {
      final timeMatches = _timePattern.allMatches(remaining).toList();
      if (timeMatches.isNotEmpty) {
        startHour = int.parse(timeMatches[0].group(1)!);
        startMinute = int.parse(timeMatches[0].group(2)!);
        if (timeMatches.length >= 2) {
          endHour = int.parse(timeMatches[1].group(1)!);
          endMinute = int.parse(timeMatches[1].group(2)!);
        }
      }
      if (startHour == null) {
        final simpleMatch = _simpleTimePattern.firstMatch(remaining);
        if (simpleMatch != null) {
          startHour = int.parse(simpleMatch.group(1)!);
          startMinute = 0;
        }
      }
      remaining = remaining
          .replaceAll(_timePattern, '')
          .replaceAll(_simpleTimePattern, '')
          .trim();
    }

    // ── "prochain" (lundi prochain) ──
    final prochainMatch = _prochainPattern.firstMatch(remaining);
    if (prochainMatch != null) {
      startDate =
          _resolveRelativeDate(prochainMatch.group(1)!, forceNext: true);
      remaining = remaining.replaceFirst(prochainMatch.group(0)!, '').trim();
    }

    // ── Date relative (demain, lundi...) ──
    if (startDate == null) {
      final dateRelMatch = _dateRelativePattern.firstMatch(remaining);
      if (dateRelMatch != null) {
        startDate = _resolveRelativeDate(dateRelMatch.group(1)!);
        remaining = remaining.replaceFirst(dateRelMatch.group(0)!, '').trim();
      }
    }

    // ── Moments de la journée (matin, soir...) ──
    final momentMatch = _momentPattern.firstMatch(remaining);
    if (momentMatch != null) {
      final moment = momentMatch.group(0)!.toLowerCase();
      if (startDate == null) {
        final now = DateTime.now();
        startDate = DateTime(now.year, now.month, now.day);
      }
      if (startHour == null) {
        if (moment.contains('matin')) {
          startHour = 9;
          startMinute = 0;
          endHour ??= 12;
          endMinute ??= 0;
        } else if (moment.contains('après') || moment.contains('après-midi')) {
          startHour = 14;
          startMinute = 0;
          endHour ??= 17;
          endMinute ??= 0;
        } else if (moment.contains('soir')) {
          startHour = 19;
          startMinute = 0;
          endHour ??= 21;
          endMinute ??= 0;
        } else if (moment.contains('nuit')) {
          startHour = 22;
          startMinute = 0;
        }
      }
    }

    // ── Date absolue (15/03) ──
    if (startDate == null) {
      final dateAbsMatch = _dateAbsolutePattern.firstMatch(remaining);
      if (dateAbsMatch != null) {
        final day = int.parse(dateAbsMatch.group(1)!);
        final month = int.parse(dateAbsMatch.group(2)!);
        final yearStr = dateAbsMatch.group(3);
        final year = yearStr != null
            ? (yearStr.length == 2
                ? 2000 + int.parse(yearStr)
                : int.parse(yearStr))
            : DateTime.now().year;
        startDate = DateTime(year, month, day);
      }
    }

    startDate ??= DateTime.now();

    // ── Appliquer la durée ──
    if (durationMinutes != null && startHour != null && endHour == null) {
      final startTotal = startHour * 60 + (startMinute ?? 0);
      final endTotal = startTotal + durationMinutes;
      endHour = (endTotal ~/ 60).clamp(0, 23);
      endMinute = endTotal % 60;
    }

    return {
      'startDate': startDate,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }

  /// Supprime les mots temporels qui ont fui dans le lieu (ex: "demainmatin").
  static String _cleanTemporalFromLocation(String loc) {
    var cleaned = loc;
    // Mots temporels collés ou séparés
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:demain\s*matin|demain\s*soir|demain\s*après[- ]?midi|'
        r'demain|après[- ]?demain|aujourd.?hui|'
        r'ce\s+matin|ce\s+soir|cet\s+après[- ]?midi|cette\s+nuit|'
        r'matin|soir|après[- ]?midi|nuit|midi|matinée|soirée|'
        r'lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|'
        r'prochain|prochaine|'
        r'pendant\s+\d+\s*(?:h(?:eures?)?|min(?:utes?)?)?|'
        r'\d+\s*(?:h\d*|min(?:utes?)?))\b',
        caseSensitive: false,
      ),
      '',
    );
    // Nettoyer espaces multiples
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Capitaliser
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    return cleaned;
  }

  // ──────────────────────────────────────────────────────────────
  // Extraction principale
  // ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _extractAll(String input) {
    String remaining = input;
    String? category;
    final participants = <String>[];
    DateTime? startDate;
    int? startHour;
    int? startMinute;
    int? endHour;
    int? endMinute;
    String? location;

    // ── 1. Catégorie (#tag) ──
    final catMatch = _categoryPattern.firstMatch(remaining);
    if (catMatch != null) {
      category = catMatch.group(1);
      remaining = remaining.replaceFirst(catMatch.group(0)!, '').trim();
    }

    // ── 2. Participants @mention ──
    for (final match in _mentionPattern.allMatches(remaining)) {
      participants.add(match.group(1)!);
    }
    remaining = remaining.replaceAll(_mentionPattern, '').trim();

    // ── 3. Participants "avec X" ──
    final avecMatch = _avecPattern.firstMatch(remaining);
    if (avecMatch != null) {
      final avecText = avecMatch.group(1)!.trim();
      // Séparer les noms : "Jean et Marie", "ma mère", "Jean, Marie et Paul"
      final names = avecText
          .split(RegExp(r'\s*(?:,\s*|\s+et\s+)\s*'))
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty)
          .toList();
      participants.addAll(names);
      remaining = remaining.replaceFirst(avecMatch.group(0)!, ' ').trim();
    }

    // ── 4. "prochain" (lundi prochain → semaine prochaine) ──
    final prochainMatch = _prochainPattern.firstMatch(remaining);
    if (prochainMatch != null) {
      startDate =
          _resolveRelativeDate(prochainMatch.group(1)!, forceNext: true);
      remaining = remaining.replaceFirst(prochainMatch.group(0)!, '').trim();
    }

    // ── 4b. Durée (pendant 30min, pendant 2h, pendant 1h30) ──
    int? durationMinutes;
    final durationMatch = _durationPattern.firstMatch(remaining);
    if (durationMatch != null) {
      final mainVal = int.tryParse(durationMatch.group(1)!) ?? 0;
      final fullMatch = durationMatch.group(0)!.toLowerCase();
      if (fullMatch.contains('h')) {
        // "pendant 2h" ou "pendant 1h30"
        durationMinutes = mainVal * 60;
        final extraMin = durationMatch.group(2);
        if (extraMin != null) {
          durationMinutes =
              (durationMinutes ?? 0) + (int.tryParse(extraMin) ?? 0);
        }
      } else {
        // "pendant 30min"
        durationMinutes = mainVal;
      }
      remaining = remaining.replaceFirst(durationMatch.group(0)!, '').trim();
    }

    // ── 5. Plages horaires (de 14h à 16h, 14h-16h) ──
    final rangeMatch = _timeRangePattern.firstMatch(remaining);
    if (rangeMatch != null) {
      startHour = int.tryParse(rangeMatch.group(1)!);
      startMinute = int.tryParse(rangeMatch.group(2) ?? '0') ?? 0;
      endHour = int.tryParse(rangeMatch.group(3)!);
      endMinute = int.tryParse(rangeMatch.group(4) ?? '0') ?? 0;
      remaining = remaining.replaceFirst(rangeMatch.group(0)!, '').trim();
    }

    // ── 6. Heures isolées (20h00, 14:30, 9h) ──
    if (startHour == null) {
      final timeMatches = _timePattern.allMatches(remaining).toList();
      if (timeMatches.isNotEmpty) {
        startHour = int.parse(timeMatches[0].group(1)!);
        startMinute = int.parse(timeMatches[0].group(2)!);
        if (timeMatches.length >= 2) {
          endHour = int.parse(timeMatches[1].group(1)!);
          endMinute = int.parse(timeMatches[1].group(2)!);
        }
      }
      if (startHour == null) {
        final simpleMatch = _simpleTimePattern.firstMatch(remaining);
        if (simpleMatch != null) {
          startHour = int.parse(simpleMatch.group(1)!);
          startMinute = 0;
        }
      }
      remaining = remaining
          .replaceAll(_timePattern, '')
          .replaceAll(_simpleTimePattern, '')
          .trim();
      // Supprimer les "à" orphelins en fin de texte (restant après
      // extraction de "à 14h" où seul "14h" a été retiré)
      remaining = remaining.replaceAll(RegExp(r'(?:\s+à)+\s*$'), '').trim();
    }

    // ── 7. Date relative (demain, après-demain, lundi, ...) ──
    // IMPORTANT : doit être AVANT le moment pattern (matin/soir/etc.)
    // sinon "demain matin" → matin fixe la date à aujourd'hui et "demain" est ignoré.
    if (startDate == null) {
      final dateRelMatch = _dateRelativePattern.firstMatch(remaining);
      if (dateRelMatch != null) {
        startDate = _resolveRelativeDate(dateRelMatch.group(1)!);
        remaining = remaining.replaceFirst(dateRelMatch.group(0)!, '').trim();
      }
    }

    // ── 8. Moments de la journée (cet après-midi, ce soir, ce matin) ──
    final momentMatch = _momentPattern.firstMatch(remaining);
    if (momentMatch != null) {
      final moment = momentMatch.group(0)!.toLowerCase();

      // Ne fixer la date à aujourd'hui QUE si aucune date relative n'a été trouvée
      if (startDate == null) {
        final now = DateTime.now();
        startDate = DateTime(now.year, now.month, now.day);
      }

      // Assigner les heures par défaut si pas explicites
      if (startHour == null) {
        if (moment.contains('matin')) {
          startHour = 9;
          startMinute = 0;
          endHour ??= 12;
          endMinute ??= 0;
        } else if (moment.contains('après') || moment.contains('après-midi')) {
          startHour = 14;
          startMinute = 0;
          endHour ??= 17;
          endMinute ??= 0;
        } else if (moment.contains('soir')) {
          startHour = 19;
          startMinute = 0;
          endHour ??= 21;
          endMinute ??= 0;
        } else if (moment.contains('nuit')) {
          startHour = 22;
          startMinute = 0;
        } else if (moment.contains('fin')) {
          if (moment.contains('matinée')) {
            startHour = 11;
            startMinute = 0;
          } else if (moment.contains('journée')) {
            startHour = 17;
            startMinute = 0;
          } else if (moment.contains('après')) {
            startHour = 16;
            startMinute = 30;
          } else if (moment.contains('soirée')) {
            startHour = 21;
            startMinute = 0;
          }
        }
      }

      remaining = remaining.replaceFirst(momentMatch.group(0)!, '').trim();
    }

    // ── 9. Date absolue (15/03, 15-03-2025) ──
    if (startDate == null) {
      final dateAbsMatch = _dateAbsolutePattern.firstMatch(remaining);
      if (dateAbsMatch != null) {
        final day = int.parse(dateAbsMatch.group(1)!);
        final month = int.parse(dateAbsMatch.group(2)!);
        final yearStr = dateAbsMatch.group(3);
        final year = yearStr != null
            ? (yearStr.length == 2
                ? 2000 + int.parse(yearStr)
                : int.parse(yearStr))
            : DateTime.now().year;
        startDate = DateTime(year, month, day);
        remaining = remaining.replaceFirst(dateAbsMatch.group(0)!, '').trim();
      }
    }

    // ── 10. Lieu (à Paris, au cinéma, chez X) ──
    final locMatch = _locationPattern.firstMatch(remaining);
    if (locMatch != null) {
      location = locMatch.group(1)?.trim();
      // Supprimer uniquement les possessifs (mon bureau → Bureau)
      // Garder les articles définis (la Valentine → La Valentine)
      location = location?.replaceFirst(
          RegExp(r"^(?:mon|ma|mes|son|sa|ses)\s+", caseSensitive: false), '');
      // Capitaliser la première lettre du lieu
      if (location != null && location.isNotEmpty) {
        location = location[0].toUpperCase() + location.substring(1);
      }
      remaining = remaining.replaceFirst(locMatch.group(0)!, '').trim();
    }

    // ── 11. Séparation titre/description si texte long ──
    String? description;
    if (remaining.length > 40) {
      final split = _splitTitleDescription(remaining);
      if (split['description'] != null) {
        remaining = split['title']!;
        description = split['description'];
      }
    }

    // ── 12. Titre intelligent (nettoyage + fallback lieu) ──
    remaining = _smartTitle(remaining, location: location);

    // ── 12b. Appliquer la durée si on a un startHour mais pas de endHour ──
    if (durationMinutes != null && startHour != null && endHour == null) {
      final startTotal = startHour * 60 + (startMinute ?? 0);
      final endTotal = startTotal + durationMinutes;
      endHour = (endTotal ~/ 60).clamp(0, 23);
      endMinute = endTotal % 60;
    }

    return {
      'title': remaining.isNotEmpty ? remaining : null,
      'description': description,
      'category': category,
      'participants': participants,
      'startDate': startDate,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'location': location,
      'durationMinutes': durationMinutes,
    };
  }

  /// Sépare un texte long en titre court + description.
  /// Split sur "et" + verbe d'action, ou "puis", ou "penser à".
  static Map<String, String?> _splitTitleDescription(String text) {
    // Split sur "et" suivi d'un verbe d'action (infinitif)
    final etSplit = RegExp(
      r'\s+et\s+(?=(?:penser|faire|acheter|prendre|voir|trouver|préparer|'
      r'ne\s+pas\s+oublier|pas\s+oublier|organiser|chercher|gérer|vérifier|'
      r'appeler|envoyer|écrire|finir|commencer|essayer|prévoir|réserver|'
      r'confirmer|annuler|rappeler|commander|récupérer|déposer|amener|ramener)\b)',
      caseSensitive: false,
    ).firstMatch(text);

    if (etSplit != null && etSplit.start >= 3) {
      final title = text.substring(0, etSplit.start).trim();
      var desc = text.substring(etSplit.end).trim();
      if (desc.isNotEmpty) {
        desc = desc[0].toUpperCase() + desc.substring(1);
      }
      return {'title': title, 'description': desc};
    }

    // Split sur "puis"
    final puisSplit =
        RegExp(r'\s+puis\s+', caseSensitive: false).firstMatch(text);
    if (puisSplit != null && puisSplit.start >= 3) {
      final title = text.substring(0, puisSplit.start).trim();
      var desc = text.substring(puisSplit.end).trim();
      if (desc.isNotEmpty) {
        desc = desc[0].toUpperCase() + desc.substring(1);
      }
      return {'title': title, 'description': desc};
    }

    return {'title': text, 'description': null};
  }

  /// Nettoie une chaîne pour en faire un titre propre.
  /// Supprime verbes creux, mots temporels, prépositions orphelines.
  static String _cleanTitle(String raw) {
    var title = raw;

    // Supprimer les mots temporels (demain, matin, soir, jours de la semaine...)
    title = title.replaceAll(
      RegExp(
        r"\b(?:demain|après[- ]demain|aujourd'?hui|"
        r"ce\s+(?:matin|soir)|cet\s+après[- ]midi|cette\s+nuit|"
        r"(?:le\s+)?matin|(?:la\s+)?matinée|(?:le\s+)?soir|(?:la\s+)?soirée|"
        r"(?:l[' ]\s*)?après[- ]midi|midi|nuit|"
        r"lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|"
        r"prochain(?:e)?)\b",
        caseSensitive: false,
      ),
      '',
    );

    // Supprimer les verbes creux / préfixes (aller, faire, voir, penser à...)
    title = title.replaceFirst(
      RegExp(
        r"^(?:aller(?:\s+|$)|"
        r"je\s+(?:vais|dois|voudrais|veux)\s+|"
        r"il\s+faut\s+|"
        r"j'ai\s+|"
        r"on\s+(?:va|doit)\s+|"
        r"(?:il|elle)\s+(?:va|doit)\s+|"
        r"faut\s+|"
        r"faire\s+|"
        r"voir\s+|"
        r"penser\s+à\s+)",
        caseSensitive: false,
      ),
      '',
    );

    // Supprimer les prépositions orphelines en début ("à la", "au", "chez", "en")
    title = title.replaceFirst(
      RegExp(
        r"^(?:à\s+(?:la\s+|l['']\s*)?|au\s+|chez\s+(?:le\s+|la\s+|l['']\s*)?|en\s+)",
        caseSensitive: false,
      ),
      '',
    );

    // Nettoyer espaces, ponctuation résiduelle, "et" orphelin
    title = title
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^\s*(?:et\s+|[,\-–.]\s*)'), '')
        .replaceAll(RegExp(r'\s*[,\-–.]\s*$'), '')
        .trim();

    // Première lettre en majuscule
    if (title.isNotEmpty) {
      title = title[0].toUpperCase() + title.substring(1);
    }

    return title;
  }

  /// Génère un titre intelligent : nettoie le raw, fallback sur le lieu si vide.
  /// Agressif : si le LLM copie le texte brut, on extrait le sujet principal.
  static String _smartTitle(String rawTitle, {String? location}) {
    var title = _cleanTitle(rawTitle);

    // Si titre trop long (>5 mots), c'est probablement du texte brut copié
    // → ne garder que les 3 premiers mots significatifs
    final words =
        title.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 5) {
      title = words.take(3).join(' ');
    }

    // Si le titre est vide/trop court et qu'on a un lieu, l'utiliser
    if (title.length <= 2 && location != null && location.isNotEmpty) {
      title = location.replaceFirst(
        RegExp(r"^(?:La\s+|Le\s+|Les\s+|L['']\s*)", caseSensitive: false),
        '',
      );
      if (title.isNotEmpty) {
        title = title[0].toUpperCase() + title.substring(1);
      }
    }

    // Dernier garde-fou : si toujours vide
    if (title.trim().isEmpty) {
      title = 'Nouvel événement';
    }

    return title;
  }

  static DateTime _resolveRelativeDate(String word, {bool forceNext = false}) {
    final now = DateTime.now();
    final lc = word.toLowerCase();

    if (lc == 'demain') return DateTime(now.year, now.month, now.day + 1);
    if (lc == 'après-demain' || lc == 'après demain') {
      return DateTime(now.year, now.month, now.day + 2);
    }
    if (lc == "aujourd'hui" || lc == 'aujourdhui') {
      return DateTime(now.year, now.month, now.day);
    }

    // Jours de la semaine → prochain occurrence
    const dayNames = {
      'lundi': DateTime.monday,
      'mardi': DateTime.tuesday,
      'mercredi': DateTime.wednesday,
      'jeudi': DateTime.thursday,
      'vendredi': DateTime.friday,
      'samedi': DateTime.saturday,
      'dimanche': DateTime.sunday,
    };
    final targetDay = dayNames[lc];
    if (targetDay != null) {
      int daysUntil = targetDay - now.weekday;
      if (forceNext) {
        // "lundi prochain" = toujours >= 7 jours
        if (daysUntil <= 0) daysUntil += 7;
        if (daysUntil < 7) daysUntil += 7;
      } else {
        if (daysUntil <= 0) daysUntil += 7;
      }
      return DateTime(now.year, now.month, now.day + daysUntil);
    }

    return DateTime(now.year, now.month, now.day);
  }

  // ──────────────────────────────────────────────────────────────
  // Habitudes utilisateur
  // ──────────────────────────────────────────────────────────────

  /// Applique les habitudes comme fallback sur les champs null du parsed map.
  static void _applyHabitsToParsed(
      Map<String, dynamic> parsed, Map<String, String> habits) {
    if (habits.isEmpty) return;
    for (final entry in habits.entries) {
      switch (entry.key) {
        case 'location':
          parsed['location'] ??= entry.value;
        case 'category':
          parsed['category'] ??= entry.value;
        case 'description':
          parsed['description'] ??= entry.value;
        // startTime/endTime : seulement si pas d'heure extraite du tout
        case 'startTime':
          if (parsed['startHour'] == null) {
            final parts = entry.value.split(':');
            if (parts.length >= 2) {
              parsed['startHour'] = int.tryParse(parts[0]);
              parsed['startMinute'] = int.tryParse(parts[1]) ?? 0;
            }
          }
        case 'endTime':
          if (parsed['endHour'] == null) {
            final parts = entry.value.split(':');
            if (parts.length >= 2) {
              parsed['endHour'] = int.tryParse(parts[0]);
              parsed['endMinute'] = int.tryParse(parts[1]) ?? 0;
            }
          }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Construction du modèle
  // ──────────────────────────────────────────────────────────────

  static EventModel _buildEventModel(Map<String, dynamic> parsed,
      {String defaultSource = 'infomaniak'}) {
    final now = DateTime.now();
    DateTime startDate = parsed['startDate'] as DateTime? ??
        DateTime(now.year, now.month, now.day);
    final startHour = parsed['startHour'] as int?;
    final startMinute = parsed['startMinute'] as int?;
    final endHour = parsed['endHour'] as int?;
    final endMinute = parsed['endMinute'] as int?;
    final participantNames = parsed['participants'] as List<String>? ?? [];

    DateTime startDateTime;
    DateTime endDateTime;

    if (startHour != null) {
      startDateTime = DateTime(startDate.year, startDate.month, startDate.day,
          startHour, startMinute ?? 0);
      if (endHour != null) {
        endDateTime = DateTime(startDate.year, startDate.month, startDate.day,
            endHour, endMinute ?? 0);
      } else {
        // Durée par défaut : 1h
        endDateTime = startDateTime.add(const Duration(hours: 1));
      }
    } else {
      // Événement all-day
      startDateTime = startDate;
      endDateTime = startDate;
    }

    // Post-validation : startTime < endTime
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = startDateTime.add(const Duration(hours: 1));
    }

    // Post-validation : heures cohérentes (0-23)
    if (startHour != null && (startHour < 0 || startHour > 23)) {
      startDateTime =
          DateTime(startDate.year, startDate.month, startDate.day, 9, 0);
      endDateTime = startDateTime.add(const Duration(hours: 1));
    }

    // Construire les participants
    final participants = participantNames
        .map((name) => ParticipantModel(
              email: '', // Pas d'email connu depuis le texte libre
              name: name,
              status: 'pending',
            ))
        .toList();

    // Déterminer la source par défaut (passée en paramètre depuis la couche Notifier)
    return EventModel(
      source: defaultSource,
      type: startHour != null ? EventType.appointment : EventType.allDay,
      title: (parsed['title'] as String?) ?? 'Nouvel événement',
      startDate: startDateTime,
      endDate: endDateTime,
      isAllDay: startHour == null,
      location: parsed['location'] as String?,
      description: parsed['description'] as String?,
      participants: participants,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
