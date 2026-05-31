class SharedDeck {
  final String id;
  final String authorName;
  final String title;
  final String description;
  
  /// 5 squads, each contains 5 Nikke IDs (e.g. [[id1, id2...], [id6, id7...], ...])
  final List<List<String?>> squadsNikkeIds;
  int upvotes;
  int downvotes;
  final DateTime createdAt;

  SharedDeck({
    required this.id,
    required this.authorName,
    required this.title,
    required this.description,
    required this.squadsNikkeIds,
    required this.upvotes,
    required this.downvotes,
    required this.createdAt,
  });

  int get score => upvotes - downvotes;

  factory SharedDeck.fromJson(Map<String, dynamic> json) {
    return SharedDeck(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      squadsNikkeIds: (json['squadsNikkeIds'] as List)
          .map((squad) => (squad as List).map((id) => id as String?).toList())
          .toList(),
      upvotes: json['upvotes'] as int,
      downvotes: json['downvotes'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorName': authorName,
      'title': title,
      'description': description,
      'squadsNikkeIds': squadsNikkeIds,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
