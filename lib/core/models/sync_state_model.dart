import 'package:equatable/equatable.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncStateModel extends Equatable {
  final int? id;
  final String source;       // 'infomaniak', notion DB id, ics URL
  final DateTime? lastSyncedAt;
  final String? syncToken;   // Pour delta sync (CalDAV sync-token / ctag)
  final SyncStatus status;
  final String? errorMessage;

  const SyncStateModel({
    this.id,
    required this.source,
    this.lastSyncedAt,
    this.syncToken,
    this.status = SyncStatus.idle,
    this.errorMessage,
  });

  SyncStateModel copyWith({
    int? id,
    String? source,
    DateTime? lastSyncedAt,
    String? syncToken,
    SyncStatus? status,
    String? errorMessage,
  }) {
    return SyncStateModel(
      id: id ?? this.id,
      source: source ?? this.source,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncToken: syncToken ?? this.syncToken,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': source,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'sync_token': syncToken,
      'status': status.name,
      'error_message': errorMessage,
    };
  }

  factory SyncStateModel.fromMap(Map<String, dynamic> map) {
    return SyncStateModel(
      id: map['id'] as int?,
      source: map['source'] as String,
      lastSyncedAt: map['last_synced_at'] != null
          ? DateTime.parse(map['last_synced_at'] as String)
          : null,
      syncToken: map['sync_token'] as String?,
      status: SyncStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SyncStatus.idle,
      ),
      errorMessage: map['error_message'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, source, status];
}
