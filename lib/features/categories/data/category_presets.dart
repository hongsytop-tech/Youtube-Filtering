import '../../../core/utils/feed_topics.dart';

/// A ready-made fine-grained category the user can load with one tap. Each
/// carries [topics] (matched against AI tags once tag-feed runs) AND [keywords]
/// (matched against the title immediately, so it works before tagging too).
class CategoryPreset {
  const CategoryPreset({
    required this.name,
    required this.color,
    required this.topics,
    required this.keywords,
  });

  final String name;
  final int color;
  final List<String> topics;
  final List<String> keywords;
}

/// Curated granular categories spanning the FeedTopics taxonomy. Loaded on the
/// categories screen ("추천 세분 카테고리") and used to seed new users.
const List<CategoryPreset> kCategoryPresets = [
  // 음악
  CategoryPreset(name: 'K-POP', color: 0xFFEF4444, topics: ['K-POP'], keywords: ['kpop', 'k-pop', '케이팝', '아이돌']),
  CategoryPreset(name: '힙합/랩', color: 0xFFEF4444, topics: ['힙합/랩'], keywords: ['힙합', '랩', 'hiphop', 'rap', '사이퍼']),
  CategoryPreset(name: '재즈', color: 0xFFEF4444, topics: ['재즈'], keywords: ['재즈', 'jazz']),
  CategoryPreset(name: '클래식', color: 0xFFEF4444, topics: ['클래식'], keywords: ['클래식', 'classical', '오케스트라', '피아노']),
  CategoryPreset(name: '음악방송', color: 0xFFEF4444, topics: ['음악방송', '직캠/팬캠'], keywords: ['뮤직뱅크', '음악중심', '인기가요', '엠카운트다운', '쇼챔피언', '직캠', 'music bank']),
  CategoryPreset(name: '뮤직비디오', color: 0xFFEF4444, topics: ['뮤직비디오'], keywords: ['mv', '뮤직비디오', 'official video', 'm/v']),
  // 게임
  CategoryPreset(name: 'FPS 게임', color: 0xFF8B5CF6, topics: ['FPS/슈팅'], keywords: ['발로란트', '오버워치', '배그', 'fps', '옵치', '서든']),
  CategoryPreset(name: '롤 (LoL)', color: 0xFF8B5CF6, topics: ['리그오브레전드'], keywords: ['롤', 'lol', '리그오브레전드', '롤드컵']),
  CategoryPreset(name: 'e스포츠', color: 0xFF8B5CF6, topics: ['e스포츠'], keywords: ['e스포츠', '이스포츠', 'esports', '프로게이머']),
  // 지식/교육
  CategoryPreset(name: '과학', color: 0xFF3B82F6, topics: ['과학', '우주/천문'], keywords: ['과학', 'science', '물리', '화학', '우주']),
  CategoryPreset(name: '역사', color: 0xFF3B82F6, topics: ['역사'], keywords: ['역사', 'history', '조선', '세계사']),
  CategoryPreset(name: '경제/투자', color: 0xFF3B82F6, topics: ['경제/금융', '주식/투자'], keywords: ['주식', '투자', '증시', '경제', '부동산', '코인']),
  CategoryPreset(name: 'IT/프로그래밍', color: 0xFF3B82F6, topics: ['IT/프로그래밍'], keywords: ['프로그래밍', '코딩', '개발자', '파이썬', 'coding']),
  CategoryPreset(name: 'AI/인공지능', color: 0xFF3B82F6, topics: ['AI/인공지능'], keywords: ['ai', '인공지능', 'chatgpt', '챗gpt', 'gpt', '딥러닝']),
  // 일상/인물
  CategoryPreset(name: '먹방', color: 0xFFF59E0B, topics: ['먹방'], keywords: ['먹방', 'mukbang', '먹방', '리얼사운드']),
  CategoryPreset(name: '브이로그', color: 0xFFF59E0B, topics: ['브이로그'], keywords: ['브이로그', 'vlog']),
  // 뷰티/라이프
  CategoryPreset(name: '뷰티/메이크업', color: 0xFFEC4899, topics: ['뷰티/메이크업'], keywords: ['메이크업', '뷰티', 'makeup', '화장', '스킨케어']),
  CategoryPreset(name: '요리/레시피', color: 0xFFEC4899, topics: ['요리/레시피', '베이킹'], keywords: ['레시피', '요리', 'cooking', '만들기', '베이킹']),
  CategoryPreset(name: '헬스/운동', color: 0xFF10B981, topics: ['홈트/피트니스', '헬스/보디빌딩', '다이어트'], keywords: ['헬스', '운동', '홈트', '다이어트', '피트니스']),
  // 스포츠
  CategoryPreset(name: '축구', color: 0xFF10B981, topics: ['축구'], keywords: ['축구', 'football', 'soccer', '손흥민', 'epl']),
  CategoryPreset(name: '야구', color: 0xFF10B981, topics: ['야구'], keywords: ['야구', 'baseball', 'kbo', 'mlb']),
  // 여행/자동차
  CategoryPreset(name: '여행', color: 0xFF06B6D4, topics: ['국내여행', '해외여행', '캠핑'], keywords: ['여행', 'travel', '캠핑']),
  CategoryPreset(name: '자동차', color: 0xFF64748B, topics: ['자동차리뷰'], keywords: ['자동차', '시승', '신차', '리뷰']),
  // 시사/영화/반려
  CategoryPreset(name: '정치/시사', color: 0xFF71717A, topics: ['정치/시사'], keywords: ['정치', '시사', '국회', '뉴스']),
  CategoryPreset(name: '영화/드라마 리뷰', color: 0xFF6366F1, topics: ['영화리뷰', '드라마리뷰'], keywords: ['영화리뷰', '결말포함', '영화추천', '드라마리뷰']),
  CategoryPreset(name: '강아지/고양이', color: 0xFFF97316, topics: ['강아지', '고양이'], keywords: ['강아지', '고양이', '반려견', '반려묘', '냥이']),
];

/// Sanity: every preset topic must exist in the taxonomy (guards typos).
bool presetsAreValid() {
  final all = FeedTopics.all.toSet();
  return kCategoryPresets.every((p) => p.topics.every(all.contains));
}

/// Colors cycled across the 13 bundle categories (one per macro group).
const _bundleColors = <int>[
  0xFF3B82F6, 0xFFEF4444, 0xFF8B5CF6, 0xFF10B981, 0xFFF59E0B, 0xFFEC4899,
  0xFF06B6D4, 0xFF64748B, 0xFF14B8A6, 0xFF71717A, 0xFFF97316, 0xFF6366F1,
  0xFFA855F7,
];

/// "묶음" categories: one per macro group (e.g. "지식/교육 전체"), bundling all
/// of that group's fine topics. Derived from the taxonomy so they never drift.
/// Topic-based (not YouTube category id), so a bundle chip stays consistent
/// with the fine topic shown on each card.
List<CategoryPreset> bundlePresets() {
  final groups = FeedTopics.groups.entries.toList();
  return [
    for (var i = 0; i < groups.length; i++)
      CategoryPreset(
        name: '${groups[i].key} 전체',
        color: _bundleColors[i % _bundleColors.length],
        topics: groups[i].value,
        keywords: const [],
      ),
  ];
}
