import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/database/database_helper.dart';
import '../core/models/event_model.dart';
import '../services/infomaniak_service.dart';
import '../services/notion_service.dart';
import '../services/ics_service.dart';
import '../services/notification_service.dart';
import '../services/sync_engine.dart';
import '../services/sync_queue_worker.dart';
import '../services/logger_service.dart';
import 'events_provider.dart';
import 'settings_provider.dart';

/// Provider du service Infomaniak.
final infomaniakServiceProvider = Provider<InfomaniakService>((ref) {
  final service = InfomaniakService();
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings?.infomaniakUsername != null &&
      settings?.infomaniakAppPassword != null) {
    service.setCredentials(
      username: settings!.infomaniakUsername!,
      appPassword: settings.infomaniakAppPassword!,
      calendarUrl: settings.infomaniakCalendarUrl,
    );
    AppLogger.instance.info(
      'Provider',
      'InfomaniakService configuré (user=${settings.infomaniakUsername}, calUrl=${settings.infomaniakCalendarUrl != null ? "SET" : "NULL"})',
    );
  } else {
    AppLogger.instance.warning(
      'Provider',
      'InfomaniakService créé SANS credentials (settings loaded=${settings != null})',
    );
  }
  return service;
});

/// Provider du service Notion.
final notionServiceProvider = Provider<NotionService>((ref) {
  final service = NotionService();
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings?.notionApiKey != null) {
    service.setCredentials(apiKey: settings!.notionApiKey!);
    AppLogger.instance.info(
      'Provider',
      'NotionService configuré (apiKey=SET)',
    );
  } else {
    AppLogger.instance.warning(
      'Provider',
      'NotionService créé SANS API key (settings loaded=${settings != null})',
    );
  }
  return service;
});

/// Provider du SyncEngine.
/// Utilise ref.watch pour se recréer quand les services changent
/// (ex: rechargement credentials depuis le stockage sécurisé).
final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    db: DatabaseHelper.instance,
    infomaniak: ref.watch(infomaniakServiceProvider),
    notion: ref.watch(notionServiceProvider),
    ics: IcsService(),
    notifications: NotificationService.instance,
  );
});

/// V2 : Provider du SyncQueueWorker.
/// Utilise ref.watch pour se recréer quand les services changent.
final syncQueueWorkerProvider = Provider<SyncQueueWorker>((ref) {
  return SyncQueueWorker(
    db: DatabaseHelper.instance,
    infomaniak: ref.watch(infomaniakServiceProvider),
    notion: ref.watch(notionServiceProvider),
  );
});

/// V2 : Provider du nombre d'actions en attente dans la queue.
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  return DatabaseHelper.instance.getPendingSyncCount();
});

/// V2 : Provider du nombre de logs d'erreur non lus.
final unreadErrorCountProvider = FutureProvider<int>((ref) async {
  return DatabaseHelper.instance.getUnreadErrorCount();
});

/// État de la synchronisation.
class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final SyncResult? lastResult;
  final Map<String, String> sourceErrors;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncedAt,
    this.errorMessage,
    this.lastResult,
    this.sourceErrors = const {},
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncedAt,
    String? errorMessage,
    SyncResult? lastResult,
    Map<String, String>? sourceErrors,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      lastResult: lastResult ?? this.lastResult,
      sourceErrors: sourceErrors ?? this.sourceErrors,
    );
  }
}

class SyncNotifier extends Notifier<SyncState> {
  Timer? _autoClearTimer;

  @override
  SyncState build() => const SyncState();

  /// Efface automatiquement le message d'erreur après [seconds] secondes.
  void _scheduleAutoClear({int seconds = 5}) {
    _autoClearTimer?.cancel();
    _autoClearTimer = Timer(Duration(seconds: seconds), () {
      state = state.copyWith(
        errorMessage: null,
        sourceErrors: const {},
      );
    });
  }

  Future<void> syncAll() async {
    if (state.isSyncing) return;

    // Bloquer la sync auto si mode hors-ligne forcé
    final forceOffline = ref.read(forceOfflineProvider);
    if (forceOffline) {
      state = state.copyWith(
        lastResult: SyncResult.offline,
        errorMessage: 'Mode hors-ligne activé',
      );
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      errorMessage: null,
      sourceErrors: {},
    );

    try {
      // V2 : D'abord dépiler la queue offline
      final queueWorker = ref.read(syncQueueWorkerProvider);
      final queueResult = await queueWorker.processQueue();
      if (queueResult > 0) {
        AppLogger.instance
            .info('Sync', '$queueResult actions offline traitées');
      }

      final engine = ref.read(syncEngineProvider);
      final (result, errors) = await engine.syncAll();

      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: DateTime.now(),
        lastResult: result,
        sourceErrors: errors,
        errorMessage: errors.isNotEmpty
            ? errors.entries.map((e) => '${e.key}: ${e.value}').join('\n')
            : null,
      );

      // Auto-clear du message d'erreur après 5 secondes
      if (errors.isNotEmpty) _scheduleAutoClear();

      // Actualiser les événements
      ref.read(eventsNotifierProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: e.toString(),
        lastResult: SyncResult.failure,
      );
      _scheduleAutoClear(seconds: 8);
    }
  }

  Future<void> pushEvent(EventModel event) async {
    final engine = ref.read(syncEngineProvider);
    AppLogger.instance.info('Sync',
        'pushEvent: source=${event.source}, id=${event.id}, remoteId=${event.remoteId}');
    if (event.isFromInfomaniak) {
      await engine.pushEventToInfomaniak(event);
    } else if (event.isFromNotion) {
      await engine.pushEventToNotion(event);
    } else {
      AppLogger.instance.warning(
          'Sync', 'pushEvent: source inconnue "${event.source}", push ignoré');
    }
  }

  Future<void> deleteEvent(EventModel event) async {
    final engine = ref.read(syncEngineProvider);
    await engine.deleteEvent(event);
    ref.read(eventsNotifierProvider.notifier).refresh();
  }

  /// Pousse la queue offline puis lance une sync complète.
  /// Utilisé après avoir travaillé en mode hors-ligne forcé.
  /// Désactive automatiquement le mode offline forcé.
  Future<void> pushAndSync() async {
    if (state.isSyncing) return;

    // Désactiver le mode hors-ligne forcé
    ref.read(forceOfflineProvider.notifier).set(false);

    state = state.copyWith(
      isSyncing: true,
      errorMessage: null,
      sourceErrors: {},
    );

    try {
      // 1. Dépiler toute la queue offline
      final queueWorker = ref.read(syncQueueWorkerProvider);
      final queueResult = await queueWorker.processQueue();
      if (queueResult > 0) {
        AppLogger.instance.info('Sync', '$queueResult modifications poussées');
      }

      // 2. Sync complète pour récupérer les changements distants
      final engine = ref.read(syncEngineProvider);
      final (result, errors) = await engine.syncAll();

      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: DateTime.now(),
        lastResult: result,
        sourceErrors: errors,
        errorMessage: errors.isNotEmpty
            ? errors.entries.map((e) => '${e.key}: ${e.value}').join('\n')
            : null,
      );

      // Auto-clear du message d'erreur après 5 secondes
      if (errors.isNotEmpty) _scheduleAutoClear();

      // Rafraîchir les providers
      ref.invalidate(pendingSyncCountProvider);
      ref.read(eventsNotifierProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: e.toString(),
        lastResult: SyncResult.failure,
      );
      _scheduleAutoClear(seconds: 8);
    }
  }
}

final syncNotifierProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Mode hors-ligne forcé par l'utilisateur.
/// Persiste dans SharedPreferences.
final forceOfflineProvider =
    StateNotifierProvider<ForceOfflineNotifier, bool>((ref) {
  return ForceOfflineNotifier();
});

class ForceOfflineNotifier extends StateNotifier<bool> {
  static const _key = 'force_offline_mode';

  ForceOfflineNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

/// Détection de la connexion réseau via connectivity_plus
/// combinée avec le mode hors-ligne forcé.
final isOfflineProvider = Provider<bool>((ref) {
  final forceOffline = ref.watch(forceOfflineProvider);
  if (forceOffline) return true;
  final connectivity = ref.watch(connectivityStreamProvider);
  return connectivity.valueOrNull ?? false;
});

/// Stream brut de l'état réseau.
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => results.every((r) => r == ConnectivityResult.none));
});

/// V2 : Auto-déclenche syncAll quand la connectivité revient.
/// Ce provider doit être watched au niveau app (ProviderScope) pour rester actif.
final autoSyncOnConnectivityProvider = Provider<void>((ref) {
  final forceOffline = ref.watch(forceOfflineProvider);
  if (forceOffline) return; // Ne pas auto-sync si mode offline forcé

  final isNetworkOffline = ref.watch(connectivityStreamProvider).valueOrNull;

  // isNetworkOffline == false signifie "réseau disponible"
  if (isNetworkOffline == false) {
    // Debounce : ne pas auto-sync si un sync est déjà en cours ou récent (< 5s)
    final syncState = ref.read(syncNotifierProvider);
    if (syncState.isSyncing) return;
    final lastSync = syncState.lastSyncedAt;
    if (lastSync != null && DateTime.now().difference(lastSync).inSeconds < 5) {
      return;
    }

    // Lancer une sync complète (processQueue + pull distant) en arrière-plan
    AppLogger.instance
        .info('AutoSync', 'Connectivité retrouvée — lancement syncAll');
    ref.read(syncNotifierProvider.notifier).syncAll().then((_) {
      ref.invalidate(pendingSyncCountProvider);
    }).catchError((e) {
      AppLogger.instance.error('AutoSync', 'Échec auto-sync: $e');
    });
  }
});

/// Fallback périodique (60 s) pour Linux où connectivity_plus peut ne pas
/// détecter les changements réseau. Vérifie s'il y a des actions en attente
/// et tente de les pousser + sync complète.
final periodicSyncRetryProvider = Provider<void>((ref) {
  final forceOffline = ref.watch(forceOfflineProvider);
  if (forceOffline) return;

  final timer = Timer.periodic(const Duration(seconds: 60), (_) async {
    final count = await DatabaseHelper.instance.getPendingSyncCount();
    if (count == 0) return;

    final syncState = ref.read(syncNotifierProvider);
    if (syncState.isSyncing) return;

    AppLogger.instance.info(
      'PeriodicRetry',
      '$count action(s) en attente — tentative de sync',
    );
    ref.read(syncNotifierProvider.notifier).syncAll().then((_) {
      ref.invalidate(pendingSyncCountProvider);
    }).catchError((e) {
      AppLogger.instance.error('PeriodicRetry', 'Échec retry: $e');
    });
  });

  ref.onDispose(() => timer.cancel());
});
