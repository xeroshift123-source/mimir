import 'package:flutter/material.dart';
import '../../models/nikke.dart';
import '../../models/enums.dart';

class NikkeCard extends StatelessWidget {
  final Nikke nikke;
  final VoidCallback? onTap;

  final bool isSelected;
  final bool isDimmed;

  /// 이 니케가 어느 스쿼드에 배치되어 있는지 (없으면 null)
  final int? assignedSquadIndex;

  /// assignedSquadIndex가 있을 때 중앙에 'Squad N' 오버레이를 보여줄지 여부
  /// - 왼쪽 목록: true (기본값)
  /// - 오른쪽 스쿼드 패널: false 로 넘김
  final bool showAssignedOverlay;

  final String? assignedSquadName;

  const NikkeCard({
    super.key,
    required this.nikke,
    this.onTap,
    this.isSelected = false,
    this.isDimmed = false,
    this.assignedSquadIndex,
    this.showAssignedOverlay = true, // 👈 기본값 true
    this.assignedSquadName,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAssigned = assignedSquadIndex != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // 카드 폭을 기준으로 스케일 계산
        final scale = (width / 150.0).clamp(0.55, 1.0);

        // 배지 크기 및 패딩 비율
        final elementSize = 22 * scale;
        final burstSize = 24 * scale;
        final badgePadding = 3 * scale;

        // 좌/우 상단 여백도 스케일링
        final badgeMargin = 6 * scale;

        return AspectRatio(
          aspectRatio: 0.75,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.all(2 * scale),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10 * scale),
                border: isSelected && !isAssigned
                    ? Border.all(
                        color: Colors.lightBlueAccent, width: 3 * scale)
                    : null,
              ),
              child: Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                elevation: isSelected ? 6 : 2,
                child: Stack(
                  children: [
                    // 1. 배경 이미지
                    Positioned.fill(child: _buildNikkeImage()),

                    // 2. 상단 그라디언트
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 40 * scale,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                      ),
                    ),

                    // 3. 이름 + 하단 그라디언트
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6 * scale,
                          vertical: 4 * scale,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                        child: Text(
                          nikke.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13 * scale,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // 4. 속성 배지 (좌상단)
                    Positioned(
                      left: badgeMargin,
                      top: badgeMargin,
                      child: _ElementBadge(
                        element: nikke.element,
                        size: elementSize,
                        padding: badgePadding,
                      ),
                    ),

                    // 5. 버스트 배지 (우상단)
                    Positioned(
                      right: badgeMargin,
                      top: badgeMargin,
                      child: _BurstBadge(
                        burst: nikke.burst,
                        size: burstSize,
                        padding: badgePadding,
                      ),
                    ),

                    // 6. Dim 처리
                    if (isDimmed && !isAssigned && !isSelected)
                      Positioned.fill(
                        child: Container(color: Colors.black.withOpacity(0.55)),
                      ),

                    // 7. 스쿼드 오버레이
                    if (isAssigned && showAssignedOverlay)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.7),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock,
                                    color: Colors.white, size: 22 * scale),
                                SizedBox(height: 4 * scale),
                                Text(
                                  assignedSquadName ??
                                      'Squad ${assignedSquadIndex! + 1}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14 * scale,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNikkeImage() {
    // 1) imageUrl 이 http/https 로 시작하면 → 원격 이미지
    if (nikke.imageUrl.startsWith('http')) {
      return Image.network(
        nikke.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Colors.black12,
          child: Center(child: Icon(Icons.image_not_supported)),
        ),
      );
    }

    // 2) 그 외 → Flutter asset 으로 간주
    return Image.asset(
      nikke.imageUrl, // 예: 'assets/nikke/elegg.webp'
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.image_not_supported)),
      ),
    );
  }
}

class _ElementBadge extends StatelessWidget {
  final ElementType element;
  final double size;
  final double padding;

  const _ElementBadge({
    required this.element,
    required this.size,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = switch (element) {
      ElementType.Fire => 'icon-elements-Fire.webp',
      ElementType.Wind => 'icon-elements-Wind.webp',
      ElementType.Iron => 'icon-elements-Iron.webp',
      ElementType.Electric => 'icon-elements-Electric.webp',
      ElementType.Water => 'icon-elements-Water.webp',
    };

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black54.withOpacity(0.6),
      ),
      child: Image.asset(
        'assets/icons/elements/$fileName',
        width: size,
        height: size,
      ),
    );
  }
}

class _BurstBadge extends StatelessWidget {
  final BurstType burst;
  final double size;
  final double padding;

  const _BurstBadge({
    required this.burst,
    required this.size,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final index = switch (burst) {
      BurstType.burst0 => 0,
      BurstType.burst1 => 1,
      BurstType.burst2 => 2,
      BurstType.burst3 => 3,
    };

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.black54.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Image.asset(
        'assets/icons/burst/icon-burst-$index.webp',
        width: size,
        height: size,
      ),
    );
  }
}
