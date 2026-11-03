import 'package:flutter/material.dart';

Color rankingColor(double score) {
  final normalized = score.clamp(0.0, 100.0);
  if (normalized <= 33.3) {
    return Color.lerp(
      Colors.red.shade500,
      Colors.amber.shade600,
      normalized / 33.3,
    )!;
  }
  if (normalized <= 66.6) {
    return Color.lerp(
      Colors.amber.shade600,
      Colors.green.shade500,
      (normalized - 33.3) / 33.3,
    )!;
  }
  return Color.lerp(
    Colors.green.shade500,
    Colors.blue.shade600,
    (normalized - 66.6) / 33.4,
  )!;
}
