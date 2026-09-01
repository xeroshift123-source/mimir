import '../models/achievement_badge.dart';
import '../models/nikke.dart';

const List<AchievementBadgeDefinition> staticAchievementBadges = [
  AchievementBadgeDefinition(
    id: 'thousand_days',
    name: '천일동안',
    condition: '생성된 지 1,000일 이상 지난 계정 보유',
    imagePath: 'assets/images/badge/1000DAYS.png',
    comment: 'BA-01 다운!',
    imageScale: 1.6,
    focusX: -0.12,
    focusY: -0.42,
  ),
  AchievementBadgeDefinition(
    id: 'fashionista',
    name: '패셔니스타',
    condition: '코스튬 100개 이상 보유',
    imagePath: 'assets/images/badge/LUCHE.png',
    comment: '지르는 건 언제나 즐겁지?',
  ),
  AchievementBadgeDefinition(
    id: 'shoes_20',
    name: 'Nikkes on her feet',
    condition: '+5 오버로드 신발 20개 이상 보유',
    imagePath: 'assets/images/badge/SHOES.png',
    comment: 'Make my love complete.',
  ),
  AchievementBadgeDefinition(
    id: 'level_400',
    name: 'CD',
    condition: '400레벨 이상 니케 보유',
    imagePath: 'assets/images/badge/CD.webp',
    comment: '니응애 탈출.',
  ),
  AchievementBadgeDefinition(
    id: 'level_500',
    name: '니케500',
    condition: '500레벨 이상 니케 보유',
    imagePath: 'assets/images/badge/NIKKE500.png',
    comment: '카페인 없이 건강해요!',
    imageScale: 1.28,
    focusX: 0.12,
  ),
  AchievementBadgeDefinition(
    id: 'level_600',
    name: '600족',
    condition: '600레벨 이상 니케 보유',
    imagePath: 'assets/images/badge/600.png',
    comment: '도로도로!',
    imageScale: 2.25,
    focusX: -0.12,
    focusY: -0.55,
  ),
  AchievementBadgeDefinition(
    id: 'level_700',
    name: '귀여워',
    condition: '700레벨 이상 니케 보유',
    imagePath: 'assets/images/badge/700.png',
    comment: 'ㄱㅇㅇ',
  ),
  AchievementBadgeDefinition(
    id: 'level_808',
    name: '여명',
    condition: '808레벨 이상 니케 보유',
    imagePath: 'assets/images/badge/DAWN.png',
    comment: '정말 좋아요',
  ),
  AchievementBadgeDefinition(
    id: 'level_911',
    name: '대체재는 없다.',
    condition: '911레벨 이상 니케 보유',
    imagePath: 'assets/images/badge/911.png',
    comment: 'There is no substitute',
    imageScale: 1.28,
  ),
  AchievementBadgeDefinition(
    id: 'level_1000',
    name: '전설',
    condition: '1,000레벨 이상 니케 보유',
    imagePath: 'assets/images/badge/1000.webp',
    comment: '파티는 끝났다.',
    imageScale: 1.35,
    focusY: 0.12,
  ),
];

AchievementBadgeDefinition? buildUltimateBadge(
  AchievementBadgeUnlock unlock,
  Map<int, Nikke> nikkesByCode,
) {
  final nikke = nikkesByCode[unlock.nameCode];
  if (nikke == null) return null;
  return AchievementBadgeDefinition(
    id: unlock.id,
    name: '최강의 ${nikke.name}',
    condition: '코어 +7 · 스킬 10/10/10 · 오버로드 11줄 · 옵션 평균 11 이상',
    imagePath: nikke.imageUrl,
    comment: '코멘트가 아직 등록되지 않았습니다.',
  );
}
