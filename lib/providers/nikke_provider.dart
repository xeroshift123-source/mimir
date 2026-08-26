import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:mimir/models/nikke.dart';

class NikkeProvider with ChangeNotifier {
  List<Nikke> _nikkeList = [];
  Map<String, Nikke> _nikkeById = const {};
  Map<int, Nikke> _nikkeByBlablaCode = const {};

  List<Nikke> get nikkeList => _nikkeList;
  Map<String, Nikke> get nikkeById => _nikkeById;
  Map<int, Nikke> get nikkeByBlablaCode => _nikkeByBlablaCode;

  /// 🔥 여기 loadNikkes()가 존재함
  Future<void> loadNikkes() async {
    try {
      // JSON 파일을 assets에서 불러옴
      final jsonStr = await rootBundle.loadString('assets/nikkes.json');
      final List<dynamic> raw = jsonDecode(jsonStr);

      // JSON → Nikke 객체로 변환
      _nikkeList = raw.map((e) => Nikke.fromJson(e)).toList();
      _buildIndexes();
      notifyListeners();
    } catch (e) {
      debugPrint("❗ Nikke 데이터 로딩 실패 : $e");
    }
  }

  void _buildIndexes() {
    _nikkeById =
        Map.unmodifiable({for (final nikke in _nikkeList) nikke.id: nikke});
    final byBlablaCode = <int, Nikke>{};
    for (final nikke in _nikkeList) {
      final code = nikke.blablaNameCode;
      if (code == null) continue;
      final existing = byBlablaCode[code];
      if (existing != null) {
        throw StateError(
          'Duplicate blablaNameCode $code: ${existing.id}, ${nikke.id}',
        );
      }
      byBlablaCode[code] = nikke;
    }
    _nikkeByBlablaCode = Map.unmodifiable(byBlablaCode);
  }
}
