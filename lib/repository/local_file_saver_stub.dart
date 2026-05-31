import '../models/shared_deck.dart';

String generateDeckCode(SharedDeck deck) {
  final buffer = StringBuffer();
  buffer.writeln("    SharedDeck(");
  buffer.writeln("      id: \"${deck.id}\",");
  buffer.writeln("      authorName: \"${deck.authorName.replaceAll('"', '\\"')}\",");
  buffer.writeln("      title: \"${deck.title.replaceAll('"', '\\"')}\",");
  buffer.writeln("      description: \"${deck.description.replaceAll('"', '\\"').replaceAll('\n', '\\n')}\",");
  buffer.writeln("      upvotes: ${deck.upvotes},");
  buffer.writeln("      downvotes: ${deck.downvotes},");
  buffer.writeln("      createdAt: DateTime.parse(\"${deck.createdAt.toIso8601String()}\"),");
  buffer.writeln("      squadsNikkeIds: [");
  for (final squad in deck.squadsNikkeIds) {
    buffer.write("        [");
    buffer.write(squad.map((id) => id == null ? 'null' : "'$id'").join(', '));
    buffer.writeln("],");
  }
  buffer.writeln("      ],");
  buffer.writeln("    ),");
  return buffer.toString();
}

void saveDeckToLocalFile(SharedDeck deck) {
  // No-op on web / platforms without dart:io access
}
