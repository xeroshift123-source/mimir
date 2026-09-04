class SharedDeck {
  final String id;
  final String? authorUid;
  final String authorName;
  final String title;
  final String description;
  final String season;
  final String raidType;
  final String? bossName;
  final String? weaknessElement;
  final List<String> squadNames;
  final List<String> squadWeaknessElements;
  final List<String> squadDescriptions;

  /// Each squad contains 5 Nikke IDs.
  final List<List<String?>> squadsNikkeIds;
  int upvotes;
  int downvotes;
  final DateTime createdAt;

  SharedDeck({
    required this.id,
    this.authorUid,
    required this.authorName,
    required this.title,
    required this.description,
    required this.season,
    this.raidType = 'solo',
    this.bossName,
    this.weaknessElement,
    this.squadNames = const [],
    this.squadWeaknessElements = const [],
    this.squadDescriptions = const [],
    required this.squadsNikkeIds,
    required this.upvotes,
    required this.downvotes,
    required this.createdAt,
  });

  int get score => upvotes - downvotes;

  factory SharedDeck.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    DateTime? createdAt;
    if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    } else if (rawCreatedAt != null) {
      try {
        createdAt = (rawCreatedAt as dynamic).toDate() as DateTime;
      } catch (_) {}
    }
    return SharedDeck(
      id: json['id']?.toString() ?? '',
      authorUid: json['authorUid']?.toString(),
      authorName: json['authorName']?.toString() ?? '지휘관',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      season: json['season'] as String? ?? 'SEASON 37',
      raidType: json['raidType']?.toString() ?? 'solo',
      bossName: json['bossName']?.toString(),
      weaknessElement: json['weaknessElement']?.toString(),
      squadNames: (json['squadNames'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      squadWeaknessElements:
          (json['squadWeaknessElements'] as List? ?? const [])
              .map((value) => value.toString())
              .toList(),
      squadDescriptions: (json['squadDescriptions'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      squadsNikkeIds:
          (json['squadsNikkeIds'] as List? ?? const []).map((squad) {
        // Firestore does not support arrays nested directly inside arrays,
        // so current documents wrap each squad in a map. Keep accepting the
        // original nested-list shape for local mock/legacy data.
        final ids = squad is Map ? squad['nikkeIds'] : squad;
        return (ids as List? ?? const []).map((id) => id?.toString()).toList();
      }).toList(),
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (authorUid != null) 'authorUid': authorUid,
      'authorName': authorName,
      'title': title,
      'description': description,
      'season': season,
      'raidType': raidType,
      if (bossName != null) 'bossName': bossName,
      if (weaknessElement != null) 'weaknessElement': weaknessElement,
      'squadNames': squadNames,
      'squadWeaknessElements': squadWeaknessElements,
      'squadDescriptions': squadDescriptions,
      'squadsNikkeIds': squadsNikkeIds
          .map((squad) => <String, dynamic>{'nikkeIds': squad})
          .toList(),
      'upvotes': upvotes,
      'downvotes': downvotes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  SharedDeck copyWith({String? id, DateTime? createdAt}) {
    return SharedDeck(
      id: id ?? this.id,
      authorUid: authorUid,
      authorName: authorName,
      title: title,
      description: description,
      season: season,
      raidType: raidType,
      bossName: bossName,
      weaknessElement: weaknessElement,
      squadNames: squadNames,
      squadWeaknessElements: squadWeaknessElements,
      squadDescriptions: squadDescriptions,
      squadsNikkeIds: squadsNikkeIds,
      upvotes: upvotes,
      downvotes: downvotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
