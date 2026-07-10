/// A user-defined filter: which YouTube categories (and/or title keywords)
/// should surface in the feed. Blob-synced (order matters).
class FilterCategory {
  const FilterCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.youtubeCategoryIds,
    required this.keywords,
    this.topics = const [],
    required this.enabled,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int color; // ARGB int
  final List<String> youtubeCategoryIds;
  final List<String> keywords;

  /// Fine-grained topics (see FeedTopics) matched against a video's tags.
  final List<String> topics;
  final bool enabled;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FilterCategory.fromJson(Map<String, dynamic> j) {
    final created =
        DateTime.tryParse('${j['createdAt'] ?? ''}') ?? DateTime.now();
    return FilterCategory(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      color: (j['color'] as num?)?.toInt() ?? 0xFFEF4444,
      youtubeCategoryIds:
          (j['youtubeCategoryIds'] as List?)?.map((e) => '$e').toList() ??
              const [],
      keywords:
          (j['keywords'] as List?)?.map((e) => '$e').toList() ?? const [],
      topics: (j['topics'] as List?)?.map((e) => '$e').toList() ?? const [],
      enabled: j['enabled'] as bool? ?? true,
      order: (j['order'] as num?)?.toInt() ?? 0,
      createdAt: created,
      // hydrate updatedAt from createdAt for backward-compat
      updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}') ?? created,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'youtubeCategoryIds': youtubeCategoryIds,
        'keywords': keywords,
        'topics': topics,
        'enabled': enabled,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  FilterCategory copyWith({
    String? name,
    int? color,
    List<String>? youtubeCategoryIds,
    List<String>? keywords,
    List<String>? topics,
    bool? enabled,
    int? order,
    DateTime? updatedAt,
  }) {
    return FilterCategory(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      youtubeCategoryIds: youtubeCategoryIds ?? this.youtubeCategoryIds,
      keywords: keywords ?? this.keywords,
      topics: topics ?? this.topics,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
