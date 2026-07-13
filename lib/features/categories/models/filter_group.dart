/// A level-2 category: a named bundle of fine topics (FeedTopics). A video
/// matches it when its LLM topics intersect [topics]. [exposed] controls
/// whether it appears in the feed's selector bar.
class FilterSubcategory {
  const FilterSubcategory({
    required this.id,
    required this.name,
    required this.topics,
    this.exposed = true,
    required this.order,
  });

  final String id;
  final String name;
  final List<String> topics;
  final bool exposed;
  final int order;

  factory FilterSubcategory.fromJson(Map<String, dynamic> j) =>
      FilterSubcategory(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        topics: (j['topics'] as List?)?.map((e) => '$e').toList() ?? const [],
        exposed: j['exposed'] as bool? ?? true,
        order: (j['order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'topics': topics,
        'exposed': exposed,
        'order': order,
      };

  FilterSubcategory copyWith({
    String? name,
    List<String>? topics,
    bool? exposed,
    int? order,
  }) =>
      FilterSubcategory(
        id: id,
        name: name ?? this.name,
        topics: topics ?? this.topics,
        exposed: exposed ?? this.exposed,
        order: order ?? this.order,
      );
}

/// A level-1 category (대분류) containing level-2 subcategories.
class FilterGroup {
  const FilterGroup({
    required this.id,
    required this.name,
    required this.color,
    this.exposed = true,
    required this.order,
    this.subcats = const [],
  });

  final String id;
  final String name;
  final int color; // ARGB
  final bool exposed;
  final int order;
  final List<FilterSubcategory> subcats;

  factory FilterGroup.fromJson(Map<String, dynamic> j) => FilterGroup(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        color: (j['color'] as num?)?.toInt() ?? 0xFF3B82F6,
        exposed: j['exposed'] as bool? ?? true,
        order: (j['order'] as num?)?.toInt() ?? 0,
        subcats: (j['subcats'] as List?)
                ?.map((e) =>
                    FilterSubcategory.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'exposed': exposed,
        'order': order,
        'subcats': subcats.map((e) => e.toJson()).toList(),
      };

  FilterGroup copyWith({
    String? name,
    int? color,
    bool? exposed,
    int? order,
    List<FilterSubcategory>? subcats,
  }) =>
      FilterGroup(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        exposed: exposed ?? this.exposed,
        order: order ?? this.order,
        subcats: subcats ?? this.subcats,
      );
}
