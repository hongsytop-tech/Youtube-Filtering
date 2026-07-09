/// Standard YouTube Data API `videoCategory` ids → Korean labels.
/// (Region-independent core set; the ids are global.)
class YoutubeCategories {
  YoutubeCategories._();

  static const Map<String, String> labels = {
    '1': '영화/애니메이션',
    '2': '자동차',
    '10': '음악',
    '15': '반려동물/동물',
    '17': '스포츠',
    '19': '여행/이벤트',
    '20': '게임',
    '22': '인물/블로그',
    '23': '코미디',
    '24': '엔터테인먼트',
    '25': '뉴스/정치',
    '26': '노하우/스타일',
    '27': '교육',
    '28': '과학/기술',
    '29': '비영리/사회운동',
  };

  static String label(String id) => labels[id] ?? '기타($id)';

  static List<MapEntry<String, String>> get all => labels.entries.toList();
}
