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
    unionBosses: {
      "풍압": "두리안",
      "수냉": "헤비메탈",
      "작열": "모더니아 (★)",
      "철갑": "리빌드 벌컨R",
      "전격": "알트아이젠 (★)",
    },
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
    unionBosses: {
      "작열": "시니스터",
      "풍압": "레플리카 레드슈즈",
      "수냉": "니힐리스타 (★)",
      "전격": "리빌드 빅 토르소",
      "철갑": "울트라 (★)",
    },
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
];
