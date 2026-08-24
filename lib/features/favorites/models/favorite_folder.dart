/// A user-created folder for organizing favorites.
class FavoriteFolder {
  const FavoriteFolder({
    required this.id,
    required this.name,
    required this.order,
  });

  final String id;
  final String name;
  final int order;

  FavoriteFolder copyWith({String? name, int? order}) => FavoriteFolder(
        id: id,
        name: name ?? this.name,
        order: order ?? this.order,
      );

  factory FavoriteFolder.fromJson(Map<String, dynamic> j) => FavoriteFolder(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        order: (j['order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
      };
}
