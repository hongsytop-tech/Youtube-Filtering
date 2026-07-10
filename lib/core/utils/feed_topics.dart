/// Fine-grained topic taxonomy used for "세분화" filtering. YouTube only exposes
/// ~15 coarse `videoCategory` ids; these sub-topics are assigned per-video by
/// the `tag-feed` Edge Function (Claude Haiku). The Korean label IS the stored
/// value — the app and the Edge Function must agree on this exact list.
///
/// Keep this list in sync with `supabase/functions/tag-feed/index.ts` (TOPICS).
class FeedTopics {
  FeedTopics._();

  /// Macro group label → its fine topics, in display order.
  static const Map<String, List<String>> groups = {
    '음악': [
      'K-POP', '팝', '힙합/랩', 'R&B/소울', '록/메탈', '인디음악',
      'EDM/일렉트로닉', '재즈', '클래식', '발라드', '트로트', 'OST',
      '커버/버스킹', '뮤직비디오', '음악방송', '직캠/팬캠',
    ],
    '게임': [
      'FPS/슈팅', 'RPG', 'MOBA/AOS', '전략/시뮬레이션', '인디게임', '모바일게임',
      '공포게임', '콘솔/레트로', 'e스포츠', '게임리뷰/공략', '마인크래프트', '리그오브레전드',
    ],
    '지식/교육': [
      '과학', '우주/천문', '수학', '역사', '경제/금융', '주식/투자',
      'IT/프로그래밍', 'AI/인공지능', '어학/외국어', '자기계발', '다큐멘터리', '인문/철학',
    ],
    '엔터테인먼트': [
      '예능', '영화리뷰', '드라마리뷰', '웹예능', '챌린지/몰카', '연예/셀럽', 'K-드라마',
    ],
    '일상/인물': [
      '브이로그', '먹방', 'ASMR', '일상', '룸투어/인테리어', '육아',
    ],
    '뷰티/패션/라이프': [
      '뷰티/메이크업', '패션/스타일', '요리/레시피', '베이킹', 'DIY/공예',
      '홈트/피트니스', '다이어트',
    ],
    '스포츠': [
      '축구', '야구', '농구', '격투기/UFC', '골프', '등산/아웃도어', '헬스/보디빌딩',
    ],
    '자동차/모터': [
      '자동차리뷰', '모터스포츠', '오토바이',
    ],
    '여행': [
      '국내여행', '해외여행', '캠핑', '맛집탐방',
    ],
    '뉴스/시사': [
      '정치/시사', '경제뉴스', '국제뉴스', 'IT뉴스',
    ],
    '코미디': [
      '개그/스탠드업', '밈/짤',
    ],
    '반려동물': [
      '강아지', '고양이', '반려동물기타',
    ],
    '영화/애니': [
      '애니메이션', '영화/예고편',
    ],
  };

  /// Every topic, flat.
  static List<String> get all =>
      groups.values.expand((e) => e).toList(growable: false);

  /// Topic → its macro group label.
  static String groupOf(String topic) {
    for (final e in groups.entries) {
      if (e.value.contains(topic)) return e.key;
    }
    return '기타';
  }
}
