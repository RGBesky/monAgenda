import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/models/event_model.dart';
import '../core/models/sync_state_model.dart';
import '../services/infomaniak_service.dart';
import '../services/notion_service.dart';
import '../services/ics_service.dart';
import '../services/notification_service.dart';
import '../services/sync_engine.dart';
import 'events_provider.dart';
import 'settings_provider.dart';

/// Provider du service Infomaniak.
final infomaniakServiceProvider = Provider<InfomaniakService>((ref) {
  final service = InfomaniakService();
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings?.infomaniakToken != null) {
    service.setCredentials(
      token: settings!.infomaniakToken!,
      calendarId: settings.infomaniakCalendarId,
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
  }
  return service;
});

/// Provider du SyncEngine.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    db: DatabaseHelper.instance,
    infomaniak: ref.read(infomaniakServiceProvider),
    notion: ref.read(notionServiceProvider),
    ics: IcsService(),
    notifications: NotificationService.instance,
  );
});

/// État de la synchronisation.
class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final SyncResult? lastResult;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncedAt,
    this.errorMessage,
    this.lastResult,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncedAt,
    String? errorMessage,
    SyncResult? lastResult,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  Future<void> syncAll() async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final engine = ref.read(syncEngineProvider);
      final result = await engine.syncAll();

      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: DateTime.now(),
        lastResult: result,
        errorMessage: result == SyncResult.failure
            ? 'Synchronisation échouée'
            : null,
      );

      // Actualiser les événements
      ref.read(eventsNotifierProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: e.toString(),
        lastResult: SyncResult.failure,
      );
    }
  }

  Future<void> pushEvent(EventModel event) async {
    final engine = ref.read(syncEngineProvider);
    if (event.isFromInfomaniak) {
      await engine.pushEventToInfomaniak(event);
    } else if (event.isFromNotion) {
      await engine.pushEventToNotion(event);
    }
  }

  Future<void> deleteEvent(EventModel event) async {
    final engine = ref.read(syncEngineProvider);
    await engine.deleteEvent(event);
    ref.read(eventsNotifierProvider.notifier).refresh();
  }
}

final syncNotifierProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Connexion réseau.
final isOfflineProvider = StateProvider<bool>((ref) => false);
