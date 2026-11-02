import 'dart:async';
import 'dart:convert';
// Isolated by the conditional import in nikke_score_service.dart.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<double> calculateNikkeScore(String specJson) async {
  final url = Uri.parse(html.document.baseUri!)
      .resolve('score/rapi-score-worker.js')
      .toString();
  final worker = html.Worker(url);
  final result = Completer<double>();
  final messages = worker.onMessage.listen((event) {
    try {
      final data = jsonDecode(event.data as String) as Map<String, dynamic>;
      final score = data['score'];
      if (score is! num || !score.isFinite || score < 0) {
        throw StateError('score_unavailable');
      }
      if (!result.isCompleted) result.complete(score.toDouble());
    } catch (error, stack) {
      if (!result.isCompleted) result.completeError(error, stack);
    }
  });
  final errors = worker.onError.listen((event) {
    if (!result.isCompleted) {
      result.completeError(StateError('score_worker_failed'));
    }
  });
  try {
    worker.postMessage(specJson);
    return await result.future.timeout(const Duration(minutes: 3));
  } finally {
    await messages.cancel();
    await errors.cancel();
    worker.terminate();
  }
}
