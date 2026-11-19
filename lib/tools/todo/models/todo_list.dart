class TodoList {
  final String shortId;
  final String? folderId;
  final String name;
  final String emoji;
  final int color;
  final double sortOrder;
  final int createdAt;
  final int updatedAt;
  final bool deleted;

  const TodoList({
    required this.shortId,
    this.folderId,
    required this.name,
    this.emoji = '',
    required this.color,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  factory TodoList.fromMap(Map<String, Object?> map) => TodoList(
    shortId: map['short_id'] as String? ?? '',
    folderId: map['folder_id'] as String?,
    name: map['name'] as String? ?? '',
    emoji: map['emoji'] as String? ?? '',
    color: map['color'] as int? ?? 0xFF4FC3F7,
    sortOrder: (map['sort_order'] as num?)?.toDouble() ?? 0,
    createdAt: map['created_at'] as int? ?? 0,
    updatedAt: map['updated_at'] as int? ?? 0,
    deleted: (map['deleted'] as int? ?? 0) == 1,
  );

  factory TodoList.fromJson(
    String shortId,
    Map<String, dynamic> json, {
    required int updatedAt,
    bool deleted = false,
  }) => TodoList(
    shortId: shortId,
    folderId: json['folderId'] as String?,
    name: json['name'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '',
    color: json['color'] as int? ?? 0xFF4FC3F7,
    sortOrder: (json['sortOrder'] as num?)?.toDouble() ?? 0,
    createdAt: json['createdAt'] as int? ?? updatedAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );

  Map<String, Object?> toRow() => {
    'short_id': shortId,
    'folder_id': folderId,
    'name': name,
    'emoji': emoji,
    'color': color,
    'sort_order': sortOrder,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted': deleted ? 1 : 0,
  };

  Map<String, dynamic> toJson() => {
    'folderId': folderId,
    'name': name,
    'emoji': emoji,
    'color': color,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
  };

  TodoList copyWith({
    String? name,
    String? emoji,
    int? color,
    double? sortOrder,
    int? updatedAt,
    String? Function()? folderId,
  }) => TodoList(
    shortId: shortId,
    folderId: folderId != null ? folderId() : this.folderId,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    color: color ?? this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted,
  );
}
