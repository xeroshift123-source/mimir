// lib/data/raid_data.dart

import '../models/raid_info.dart';

final List<RaidInfo> raidHistory = [
  const RaidInfo(
    type: RaidType.solo,
    seasonName: "SEASON 36",
    bossName: "에고비스타",
    period: "4/30(목) 12:00 ~ 5/7(수) 4:59",
    imagePath:
        "assets/images/raids/wigobi.png", // Replace with correct image later
    bossElement: "수냉",
    weakness: "전격",
    keyword: ["파츠"],
  ),
  const RaidInfo(
    type: RaidType.union,
    seasonName: "26년 5월",
    period: "5/15(금)",
    imagePath: "assets/images/dororong.png",
    unionBosses: [
      UnionBossInfo(element: "풍압", name: "두리안"),
      UnionBossInfo(element: "수냉", name: "헤비메탈"),
      UnionBossInfo(element: "작열", name: "모더니아 (★)"),
      UnionBossInfo(element: "철갑", name: "리빌드 벌컨R"),
      UnionBossInfo(element: "전격", name: "알트아이젠 (★)"),
    ],
  ),
  const RaidInfo(
    type: RaidType.solo,
    seasonName: "SEASON 37",
    bossName: "울라리",
    period: "5/28(목) 12:00 ~ 6/4(목) 4:59",
    imagePath: "assets/images/raids/ultra.webp",
    bossElement: "작열",
    weakness: "수냉",
    keyword: ["관통데미지", "코어", "파츠"],
  ),
  const RaidInfo(
    type: RaidType.union,
    seasonName: "26년 6월",
    period: "6/12(금)",
    imagePath: "assets/images/dororong.png",
    unionBosses: [
      UnionBossInfo(element: "작열", name: "시니스터"),
      UnionBossInfo(element: "풍압", name: "레플리카 레드슈즈"),
      UnionBossInfo(element: "수냉", name: "니힐리스타 (★)"),
      UnionBossInfo(element: "전격", name: "리빌드 빅 토르소"),
      UnionBossInfo(element: "철갑", name: "울트라 (★)"),
    ],
  ),
  const RaidInfo(
    type: RaidType.solo,
    seasonName: "SEASON 38.5",
    bossName: "애니힐리오(RE)",
    period: " 7/3(금) 12:00 ~ 7/8(수) 4:59",
    imagePath: "assets/images/raids/annihilio.png",
    bossElement: "철갑",
    weakness: "풍압",
    keyword: ["코어", "파츠"],
  ),
  const RaidInfo(
    type: RaidType.union,
    seasonName: "26년 7월",
    period: "7/10(금)",
    imagePath: "assets/images/union_raid.webp",
    unionBosses: [
      UnionBossInfo(element: "작열", name: "리빌드 오벨리스크", keyword: ["파츠"]),
      UnionBossInfo(element: "풍압", name: "크라켄 (★)", keyword: ["코어", "파츠"]),
      UnionBossInfo(element: "수냉", name: "두리안", keyword: ["코어", "힐"]),
      UnionBossInfo(element: "전격", name: "알트아이젠 (★)", keyword: ["파츠"]),
      UnionBossInfo(element: "철갑", name: "닥터", keyword: ["코어"]),
    ],
  ),
  const RaidInfo(
    type: RaidType.solo,
    seasonName: "SEASON 39",
    bossName: "아일랜드이터",
    period: " 7/16(금) 12:00 ~ 7/23(수) 4:59",
    imagePath: "assets/images/raids/island_eater2.png",
    bossElement: "전격",
    weakness: "철갑",
    keyword: ["코어", "힐"],
  ),
];
