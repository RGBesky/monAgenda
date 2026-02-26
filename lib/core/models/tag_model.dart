import 'package:equatable/equatable.dart';
import '../constants/app_constants.dart';

class TagModel extends Equatable {
  final int? id;
  final String type; // 'category' ou 'priority'
  final String name;
  final String colorHex;
  final String? infomaniakMapping; // CATEGORIES value ou PRIORITY 1-9
  final String? notionMapping; // ID option Notion
  final int sortOrder;

  const TagModel({
    this.id,
    required this.type,
    required this.name,
    required this.colorHex,
    this.infomaniakMapping,
    this.notionMapping,
    this.sortOrder = 0,
  });

  bool get isCategory => type == AppConstants.tagTypeCategory;
  bool get isPriority => type == AppConstants.tagTypePriority;
  bool get isStatus => type == AppConstants.tagTypeStatus;

  TagModel copyWith({
    int? id,
    String? type,
    String? name,
    String? colorHex,
    String? infomaniakMapping,
    String? notionMapping,
    int? sortOrder,
  }) {
    return TagModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      infomaniakMapping: infomaniakMapping ?? this.infomaniakMapping,
      notionMapping: notionMapping ?? this.notionMapping,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'color_hex': colorHex,
      'infomaniak_mapping': infomaniakMapping,
      'notion_mapping': notionMapping,
      'sort_order': sortOrder,
    };
  }

  factory TagModel.fromMap(Map<String, dynamic> map) {
    return TagModel(
      id: map['id'] as int?,
      type: map['type'] as String,
      name: map['name'] as String,
      colorHex: map['color_hex'] as String,
      infomaniakMapping: map['infomaniak_mapping'] as String?,
      notionMapping: map['notion_mapping'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, type, name, colorHex, sortOrder];
}
