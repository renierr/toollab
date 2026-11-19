class TodoFolder {
  final String shortId;
  final String name;
  final double sortOrder;
  final int createdAt;
  final int updatedAt;
  final bool deleted;

  const TodoFolder({
    required this.shortId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  factory TodoFolder.fromMap(Map<String, Object?> map) => TodoFolder(
    shortId: map['short_id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    sortOrder: (map['sort_order'] as num?)?.toDouble() ?? 0,
    createdAt: map['created_at'] as int? ?? 0,
    updatedAt: map['updated_at'] as int? ?? 0,
    deleted: (map['deleted'] as int? ?? 0) == 1,
  );

  factory TodoFolder.fromJson(
    String shortId,
    Map<String, dynamic> json, {
    required int updatedAt,
    bool deleted = false,
  }) => TodoFolder(
    shortId: shortId,
    name: json['name'] as String? ?? '',
    sortOrder: (json['sortOrder'] as num?)?.toDouble() ?? 0,
    createdAt: json['createdAt'] as int? ?? updatedAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );

  Map<String, Object?> toRow() => {
    'short_id': shortId,
    'name': name,
    'sort_order': sortOrder,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted': deleted ? 1 : 0,
  };

  Map<String, dynamic> toJson() => {
    'name': name,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
  };

  TodoFolder copyWith({String? name, double? sortOrder, int? updatedAt}) =>
      TodoFolder(
        shortId: shortId,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted,
      );
}
