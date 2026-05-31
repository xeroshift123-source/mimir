import 'dart:io';
import 'package:flutter/foundation.dart';
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
  // Only attempt file write in debug mode and if not web
  if (!kDebugMode || kIsWeb) return;

  try {
    // Attempt to locate mock_deck_repository.dart in the local file system.
    var file = File('lib/repository/mock_deck_repository.dart');
    if (!file.existsSync()) {
      file = File('C:\\MMR\\mimir\\lib\\repository\\mock_deck_repository.dart');
    }

    if (!file.existsSync()) {
      debugPrint("mock_deck_repository.dart not found in standard paths. Skipping file write.");
      return;
    }

    final content = file.readAsStringSync();
    final deckCode = generateDeckCode(deck);

    // We insert it inside `static final List<SharedDeck> _decks = [`
    const target = 'static final List<SharedDeck> _decks = [';
    final index = content.indexOf(target);
    if (index != -1) {
      final insertPos = index + target.length;
      final newContent = '${content.substring(0, insertPos)}\n$deckCode${content.substring(insertPos)}';
      file.writeAsStringSync(newContent);
      debugPrint("Successfully wrote shared deck directly to mock_deck_repository.dart!");
    } else {
      debugPrint("Failed to locate target array in mock_deck_repository.dart");
    }
  } catch (e) {
    debugPrint("Error writing deck to mock_deck_repository.dart: $e");
  }
}
