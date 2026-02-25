import 'package:equatable/equatable.dart';

class IcsSubscriptionModel extends Equatable {
  final int? id;
  final String name;
  final String url;
  final String colorHex;
  final bool isEnabled;
  final DateTime? lastSyncedAt;

  const IcsSubscriptionModel({
    this.id,
    required this.name,
    required this.url,
    this.colorHex = '#78909C',
    this.isEnabled = true,
    this.lastSyncedAt,
  });

  IcsSubscriptionModel copyWith({
    int? id,
    String? name,
    String? url,
    String? colorHex,
    bool? isEnabled,
    DateTime? lastSyncedAt,
  }) {
    return IcsSubscriptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      colorHex: colorHex ?? this.colorHex,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'color_hex': colorHex,
      'is_enabled': isEnabled ? 1 : 0,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
  }

  factory IcsSubscriptionModel.fromMap(Map<String, dynamic> map) {
    return IcsSubscriptionModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      url: map['url'] as String,
      colorHex: map['color_hex'] as String? ?? '#78909C',
      isEnabled: (map['is_enabled'] as int?) == 1,
      lastSyncedAt: map['last_synced_at'] != null
          ? DateTime.parse(map['last_synced_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, url, name];
}
