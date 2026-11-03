import 'package:flutter/material.dart';
import '../services/nikke_score_service.dart';

class LicenseScore {
  const LicenseScore(this.elementName, this.score);
  final String elementName;
  final double score;
}

List<LicenseScore> savedLicenseScores(StoredNikkeScores saved, int nameCode) {
  final scores = <LicenseScore>[];
  for (final profile in NikkeScoreService.profilesFor(nameCode)) {
    try {
      scores.add(LicenseScore(
          profile.elementName, saved.resultFor(profile.key).score));
    } on NikkeScoreException {
      // Missing or failed scores are omitted from the exported license.
    } on FormatException {
      // Invalid stored values must not be displayed as a score.
    }
  }
  return scores;
}

class LicenseScoreSummary extends StatelessWidget {
  const LicenseScoreSummary(
      {super.key,
      required this.scores,
      required this.textColor,
      required this.scoreColor});
  final List<LicenseScore> scores;
  final Color textColor, scoreColor;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('미미르 스코어',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 3),
        Wrap(spacing: 12, runSpacing: 3, children: [
          for (final score in scores)
            Text('${score.elementName} ${score.score.toStringAsFixed(2)}점',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: scoreColor)),
        ]),
      ]),
    );
  }
}
