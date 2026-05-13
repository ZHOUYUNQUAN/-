class Category {
  final int? id;
  final String name;
  final String icon;
  final int? parentId;
  final int sortOrder;

  Category({
    this.id,
    required this.name,
    this.icon = '',
    this.parentId,
    this.sortOrder = 0,
  });

  bool get isParent => parentId == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'parent_id': parentId,
        'sort_order': sortOrder,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        icon: map['icon'] as String? ?? '',
        parentId: map['parent_id'] as int?,
        sortOrder: map['sort_order'] as int? ?? 0,
      );

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    int? parentId,
    int? sortOrder,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        parentId: parentId ?? this.parentId,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
