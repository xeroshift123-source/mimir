class AchievementBadgeDefinition {
  const AchievementBadgeDefinition({
    required this.id,
    required this.name,
    required this.condition,
    required this.imagePath,
    required this.comment,
    this.imageScale = 1,
    this.focusX = 0,
    this.focusY = 0,
    this.imageBackgroundColor,
  });

  final String id;
  final String name;
  final String condition;
  final String imagePath;
  final String comment;
  final double imageScale;
  final double focusX;
  final double focusY;
  final int? imageBackgroundColor;
}

class AchievementBadgeUnlock {
  const AchievementBadgeUnlock({
    required this.id,
    required this.acquiredAt,
    this.nameCode,
  });

  final String id;
  final DateTime acquiredAt;
  final int? nameCode;

  factory AchievementBadgeUnlock.fromJson(Map<String, dynamic> json) {
    return AchievementBadgeUnlock(
      id: json['id']?.toString() ?? '',
      acquiredAt: DateTime.tryParse(json['acquiredAt']?.toString() ?? '') ??
          DateTime.now(),
      nameCode: (json['nameCode'] as num?)?.toInt(),
    );
  }
}

class AchievementBadgeState {
  const AchievementBadgeState({
    required this.unlocks,
    required this.displayedBadgeIds,
  });

  final Map<String, AchievementBadgeUnlock> unlocks;
  final List<String> displayedBadgeIds;

  factory AchievementBadgeState.fromJson(Map<String, dynamic> json) {
    final rawUnlocks = json['unlocks'];
    final unlocks = <String, AchievementBadgeUnlock>{};
    if (rawUnlocks is List) {
      for (final value in rawUnlocks.whereType<Map>()) {
        final unlock = AchievementBadgeUnlock.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (unlock.id.isNotEmpty) unlocks[unlock.id] = unlock;
      }
    }

    return AchievementBadgeState(
      unlocks: unlocks,
      displayedBadgeIds: (json['displayedBadgeIds'] as List? ?? const [])
          .map((value) => value.toString())
          .where(unlocks.containsKey)
          .take(4)
          .toList(),
    );
  }
}
