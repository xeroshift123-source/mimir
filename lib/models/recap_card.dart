import 'package:flutter/material.dart';

class RecapCardData {
  const RecapCardData({
    required this.order,
    required this.eyebrow,
    required this.title,
    required this.colors,
    required this.textColor,
    this.imageAsset,
    this.details = const [],
    this.accentColor,
  });

  final int order;
  final String eyebrow;
  final String title;
  final List<Color> colors;
  final Color textColor;
  final String? imageAsset;
  final List<String> details;
  final Color? accentColor;
}
