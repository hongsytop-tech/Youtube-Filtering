import '../../feed/models/feed_video.dart';

/// A blacklist applied to the feed: hide any video whose channel, LLM topic, or
/// title keyword the user has muted.
class Exclusions {
  const Exclusions({
    this.keywords = const {},
    this.channels = const {},
    this.topics = const {},
  });

  final Set<String> keywords; // lowercase substrings matched against the title
  final Set<String> channels; // matched against channelTitle
  final Set<String> topics; // matched against the video's LLM topics

  bool get isEmpty =>
      keywords.isEmpty && channels.isEmpty && topics.isEmpty;

  int get length => keywords.length + channels.length + topics.length;

  bool matches(FeedVideo v) {
    if (channels.contains(v.channelTitle)) return true;
    if (v.topics.any(topics.contains)) return true;
    if (keywords.isNotEmpty) {
      final t = v.title.toLowerCase();
      if (keywords.any(t.contains)) return true;
    }
    return false;
  }

  factory Exclusions.fromJson(Map<String, dynamic> j) => Exclusions(
        keywords:
            (j['keywords'] as List?)?.map((e) => '$e').toSet() ?? const {},
        channels:
            (j['channels'] as List?)?.map((e) => '$e').toSet() ?? const {},
        topics: (j['topics'] as List?)?.map((e) => '$e').toSet() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'keywords': keywords.toList(),
        'channels': channels.toList(),
        'topics': topics.toList(),
      };

  Exclusions copyWith({
    Set<String>? keywords,
    Set<String>? channels,
    Set<String>? topics,
  }) =>
      Exclusions(
        keywords: keywords ?? this.keywords,
        channels: channels ?? this.channels,
        topics: topics ?? this.topics,
      );
}
