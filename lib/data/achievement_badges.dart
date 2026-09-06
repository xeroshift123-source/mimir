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
    id: 'counters',
    name: 'COUNTERS',
    condition: '라피 : 레드 후드, 아니스 : 트윙클 스타, 네온 : 비전아이의 호감도 40',
    imagePath: 'assets/images/badge/COUNTERS.webp',
    comment: '명실공히 최고의 지휘관과 스쿼드로 불리기에 충분',
    imageBackgroundColor: 0xFFFFFFFF,
  ),
  AchievementBadgeDefinition(
    id: 'extreme_firepower',
    name: '초화력',
    condition: '화력형 콘솔을 방어형 콘솔보다 10레벨 이상 높이기',
    imagePath: 'assets/images/badge/FIREPOWER.png',
    comment: '화력~! 화력~!',
  ),
  AchievementBadgeDefinition(
    id: 'reliable_companion',
    name: '믿음직한 동반자',
    condition: '15레벨 큐브를 하나 이상 장착',
    imagePath: 'assets/images/badge/CUBE.png',
    comment: '말은 할 수 없습니다.',
  ),
  AchievementBadgeDefinition(
    id: 'no_distinction',
    name: '귀천은 없다',
    condition: '등급이 SR 또는 R인 니케의 장비 4부위를 오버로드',
    imagePath: 'assets/nikke/rapi.webp',
    comment: '강한 니케, 약한 니케, 그런 건 지휘관이 멋대로 정하는 것.',
  ),
  AchievementBadgeDefinition(
    id: 'union_leader_tears',
    name: '유니온 장의 눈물',
    condition: '길티, 신, 퀀시, 니힐리스타 중 한 명 이상을 3돌파 이상 달성',
    imagePath: 'assets/images/badge/TEAR.webp',
    comment: '이쁘잖아요',
  ),
  AchievementBadgeDefinition(
    id: 'battle_data',
    name: '배틀 데이터',
    condition: '덱 라이브러리에 덱 공유하기',
    imagePath: 'assets/images/badge/BATTLEDATA.png',
    comment: '감사합니다',
  ),
  AchievementBadgeDefinition(
    id: 'shoes_20',
    name: 'Nikkes, On her feet',
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
    condition: '최강의 니케입니다!',
    imagePath: nikke.imageUrl,
    comment: '코멘트가 아직 등록되지 않았습니다.',
  );
}
