import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/nikke.dart';

class NikkeRepository {
  static Future<List<Nikke>> loadNikkes() async {
    final jsonStr = await rootBundle.loadString('assets/nikkes.json');
    final List data = json.decode(jsonStr);

    return data.map((item) => Nikke.fromJson(item)).toList();
  }
}
