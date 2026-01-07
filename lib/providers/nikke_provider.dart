import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:mimir/models/nikke.dart';

class NikkeProvider with ChangeNotifier {
  List<Nikke> _nikkeList = [];

  List<Nikke> get nikkeList => _nikkeList;

  /// 🔥 여기 loadNikkes()가 존재함
  Future<void> loadNikkes() async {
    try {
      // JSON 파일을 assets에서 불러옴
      final jsonStr = await rootBundle.loadString('assets/nikkes.json');
      final List<dynamic> raw = jsonDecode(jsonStr);

      // JSON → Nikke 객체로 변환
      _nikkeList = raw.map((e) => Nikke.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("❗ Nikke 데이터 로딩 실패 : $e");
    }
  }
}
