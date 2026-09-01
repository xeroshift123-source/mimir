import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/models/achievement_badge.dart';
import 'package:mimir/widgets/achievement_badge_showcase.dart';

void main() {
  const unlockedBadge = AchievementBadgeDefinition(
    id: 'unlocked',
    name: '획득 뱃지',
    condition: '조건 달성',
    imagePath: 'assets/images/badge/CD.webp',
    comment: '테스트 코멘트',
  );
  const lockedBadge = AchievementBadgeDefinition(
    id: 'locked',
    name: '비밀 뱃지',
    condition: '숨겨진 조건',
    imagePath: 'assets/images/badge/700.png',
    comment: '숨겨진 코멘트',
  );

  testWidgets('전시 슬롯과 미획득 뱃지를 함께 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 620,
            child: AchievementBadgeShowcase(
              badges: const [unlockedBadge, lockedBadge],
              unlocks: {
                'unlocked': AchievementBadgeUnlock(
                  id: 'unlocked',
                  acquiredAt: DateTime(2026, 9, 1),
                ),
              },
              displayedBadgeIds: const ['unlocked'],
              expanded: true,
              loading: false,
              saving: false,
              hasChanges: false,
              previewLockedBadges: false,
              secondary: Colors.grey,
              onToggleExpanded: () {},
              onToggleBadge: (_) {},
              onSave: () {},
              onTogglePreview: () {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('전체 뱃지  1 / 2'), findsOneWidget);
    expect(find.text('획득 뱃지'), findsOneWidget);
    expect(find.text('???'), findsOneWidget);
    expect(find.text('비밀 뱃지'), findsNothing);
  });
}
