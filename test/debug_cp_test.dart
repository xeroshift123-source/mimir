import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/utils/cp_calculator.dart';
import 'package:mimir/models/enums.dart';

void main() {
  testWidgets('debug CP', (WidgetTester tester) async {
    WidgetsFlutterBinding.ensureInitialized();
    await CpCalculator.init();

    final localNikke = Nikke(
      id: 'neon_vision_eye',
      name: '네온 : 비전아이',
      imageUrl: '',
      burst: BurstType.burst3,
      element: ElementType.Water,
      weaponType: WeaponType.MG,
      company: Company.Missilis,
      coolTime: 40,
      type: 'ATK',
      ability: [],
      squadNum: 0,
      rank: Rank.SSR,
    );

    final char = <String, dynamic>{
      'level': 464,
      'combat': 227969,
      'grade': 3,
      'core': 0,
      'bondLevel': 40,
      'commonConsoleLevel': 210,
      'classConsoleLevel': 121,
      'companyConsoleLevel': 109,
      'skills': {
        'skill1': 10,
        'skill2': 10,
        'burst': 10,
      },
      'harmonyCube': {
        'level': 15,
      },
      'favoriteItem': {
        'tid': 200000,
        'level': 15,
      },
      'equipment': [
        {'slot': 'head', 'tier': 10, 'level': 5, 'overloadOptions': []},
        {'slot': 'torso', 'tier': 10, 'level': 5, 'overloadOptions': []},
        {'slot': 'arm', 'tier': 10, 'level': 5, 'overloadOptions': []},
        {'slot': 'leg', 'tier': 10, 'level': 0, 'overloadOptions': []},
      ]
    };

    int currentLevel = char['level'] as int? ?? 1;
    final currentBase = CpCalculator.calculateTargetStats(char, localNikke, targetLevel: currentLevel);
    
    double currentBaseScore = (0.7 * currentBase['hp']!) + (19.35 * currentBase['atk']!) + (70.0 * currentBase['def']!);
    print('CurrentBaseScore: $currentBaseScore');

    final targetBase = CpCalculator.calculateTargetStats(char, localNikke, targetLevel: 40);
    double targetBaseScore = (0.7 * targetBase['hp']!) + (19.35 * targetBase['atk']!) + (70.0 * targetBase['def']!);
    print('TargetBaseScore: $targetBaseScore');

    double cp = CpCalculator.calculateCp(char, localNikke, targetLevel: 40);
    print('Result CP: $cp');
  });
}
