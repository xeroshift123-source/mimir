import 'dart:io';
import 'dart:convert';

void main() async {
  final dir = Directory('assets/nikke');
  final files = dir.listSync();

  List<Map<String, dynamic>> result = [];

  for (var f in files) {
    if (f.path.endsWith('.png') ||
        f.path.endsWith('.jpg') ||
        f.path.endsWith('.webp')) {
      final filename = f.uri.pathSegments.last;
      final id = filename.split('.').first;

      result.add({
        "id": id,
        "name": id, // 나중에 수동 수정 or 테이블로 병합 예정
        "imageUrl": "assets/nikke/$filename",
        "burst": "1",
        "element": "Fire",
        "weaponType": "MG",
        "company": "Elysion",
        "ability": [],
        "coolTime": 0,
        "squadNum": 0,
      });
    }
  }

  final output = File('assets/nikkes.json');
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));

  print("✔ nikkes.json 생성 완료 (${result.length} entries)");
}
