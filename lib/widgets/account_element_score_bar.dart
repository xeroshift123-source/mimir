import 'package:flutter/material.dart';
import '../services/nikke_score_service.dart';
import '../utils/ranking_color.dart';

class AccountElementScoreBar extends StatelessWidget {
  const AccountElementScoreBar({
    super.key,
    required this.statistic,
    required this.isDark,
  });

  final ElementScoreStatistic statistic;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final topPercent = statistic.topPercent;
    final score = statistic.score;
    final average = statistic.average;
    String formatValue(double? value) => value == null
        ? '\uac31\uc2e0 \ub300\uae30'
        : '${value.toStringAsFixed(2)}\uc810';
    final rankingScore =
        topPercent == null ? 0.0 : (100.0 - topPercent).clamp(0.0, 100.0);
    final rankColor =
        topPercent == null ? Colors.grey : rankingColor(rankingScore);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(.04) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/icons/elements/icon-elements-${statistic.key}.webp',
                width: 18,
                height: 18,
                errorBuilder: (_, __, ___) => const SizedBox.square(
                  dimension: 18,
                  child:
                      Icon(Icons.bolt_rounded, size: 16, color: Colors.orange),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  statistic.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatValue(score),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: rankColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: rankingScore / 100,
              minHeight: 6,
              color: rankColor,
              backgroundColor:
                  isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '평균 ${formatValue(average)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
              ),
              Text(
                topPercent == null
                    ? '비교 불가'
                    : '상위 ${topPercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: topPercent == null ? Colors.grey : rankColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text('표본 ${statistic.sampleCount}명',
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }
}
