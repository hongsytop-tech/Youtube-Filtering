import '../../../core/storage/local_storage.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/sample_feed.dart';
import '../models/feed_video.dart';

/// Reads the feed the server populated into `feed_videos`. Falls back to a
/// local cache, then to sample data (demo mode) so the UI is never empty.
class FeedService {
  FeedService(this._local);

  final LocalStorage _local;

  static const _key = 'feed_videos_cache';
  static const _table = 'feed_videos';

  List<FeedVideo> loadCache() {
    final cached = _local.getJsonList(_key).map(FeedVideo.fromJson).toList();
    return cached.isEmpty ? kSampleFeed : cached;
  }

  Future<List<FeedVideo>> fetch() async {
    final user = SupabaseService.currentUser;
    if (user == null) return loadCache();

    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .eq('user_id', user.id)
        .order('published_at', ascending: false)
        .limit(1000);

    final videos = (rows as List)
        .map((e) => FeedVideo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    if (videos.isEmpty) return loadCache();

    await _local.setJsonList(_key, videos.map((v) => v.toJson()).toList());
    return videos;
  }
}
