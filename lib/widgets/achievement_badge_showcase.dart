import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/achievement_badge.dart';

class PublicAchievementBadgeShowcase extends StatelessWidget {
  const PublicAchievementBadgeShowcase({
    super.key,
    required this.authorName,
    required this.badges,
    required this.unlocks,
    required this.displayedBadgeIds,
  });

  final String authorName;
  final List<AchievementBadgeDefinition> badges;
  final Map<String, AchievementBadgeUnlock> unlocks;
  final List<String> displayedBadgeIds;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final badge in badges) badge.id: badge};
    final visibleIds = displayedBadgeIds.where(byId.containsKey).toList();
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '전시 중인 프로필 뱃지',
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '닫기',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final badgeSize =
                    (constraints.maxWidth / 4 - 8).clamp(46.0, 72.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < 4; index++)
                      Expanded(
                        child: Column(
                          children: [
                            if (index < visibleIds.length)
                              _BadgeCircle(
                                badge: byId[visibleIds[index]]!,
                                unlock: unlocks[visibleIds[index]],
                                selected: true,
                                size: badgeSize,
                                onTap: null,
                              )
                            else
                              _PublicEmptyBadgeSlot(size: badgeSize),
                            const SizedBox(height: 7),
                            if (index < visibleIds.length)
                              Text(
                                byId[visibleIds[index]]!.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else
                              const SizedBox(height: 28),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicEmptyBadgeSlot extends StatelessWidget {
  const _PublicEmptyBadgeSlot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isDark
              ? const [Color(0xFF3B3D43), Color(0xFF25272C)]
              : const [Color(0xFFE4E6EA), Color(0xFFD3D6DC)],
        ),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

class AchievementBadgeShowcase extends StatelessWidget {
  const AchievementBadgeShowcase({
    super.key,
    required this.badges,
    required this.unlocks,
    required this.displayedBadgeIds,
    required this.expanded,
    required this.loading,
    required this.saving,
    required this.hasChanges,
    required this.previewLockedBadges,
    required this.secondary,
    required this.onToggleExpanded,
    required this.onToggleBadge,
    required this.onSave,
    required this.onTogglePreview,
    required this.onRetry,
    this.error,
  });

  final List<AchievementBadgeDefinition> badges;
  final Map<String, AchievementBadgeUnlock> unlocks;
  final List<String> displayedBadgeIds;
  final bool expanded;
  final bool loading;
  final bool saving;
  final bool hasChanges;
  final bool previewLockedBadges;
  final Color secondary;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onToggleBadge;
  final VoidCallback onSave;
  final VoidCallback onTogglePreview;
  final VoidCallback onRetry;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final badge in badges) badge.id: badge};

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.orange.withOpacity(0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 17, 12, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.orange,
                  size: 22,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '프로필 뱃지',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '획득한 뱃지를 최대 4개까지 전시할 수 있습니다.',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                if (kDebugMode)
                  IconButton(
                    onPressed: loading ? null : onTogglePreview,
                    tooltip:
                        previewLockedBadges ? '미획득 뱃지 미리보기 끄기' : '미획득 뱃지 미리보기',
                    color: previewLockedBadges ? Colors.orange : null,
                    icon: Icon(
                      previewLockedBadges
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                IconButton(
                  onPressed: loading ? null : onToggleExpanded,
                  tooltip: expanded ? '뱃지 목록 접기' : '전체 뱃지 보기',
                  icon: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.22)
                : const Color(0xFFFFFAF5),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: loading
                ? const SizedBox(
                    height: 72,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  )
                : error != null
                    ? SizedBox(
                        height: 72,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                error!,
                                style: TextStyle(color: secondary),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              for (var index = 0; index < 4; index++) ...[
                                Expanded(
                                  child: Center(
                                    child: index < displayedBadgeIds.length &&
                                            byId[displayedBadgeIds[index]] !=
                                                null
                                        ? _BadgeCircle(
                                            badge:
                                                byId[displayedBadgeIds[index]]!,
                                            unlock: unlocks[
                                                displayedBadgeIds[index]],
                                            selected: true,
                                            size: 68,
                                            onTap: saving
                                                ? null
                                                : () => onToggleBadge(
                                                    displayedBadgeIds[index]),
                                          )
                                        : const _EmptyBadgeSlot(size: 68),
                                  ),
                                ),
                                if (index != 3) const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 44,
                            child: FilledButton(
                              onPressed: hasChanges && !saving ? onSave : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Colors.orange.withOpacity(0.22),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: saving
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      hasChanges ? '뱃지 전시 저장' : '저장됨',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded && !loading && error == null
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.16),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '전체 뱃지  ${badges.where((badge) => unlocks.containsKey(badge.id)).length} / ${badges.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 15),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 390 ? 4 : 5;
                      const spacing = 12.0;
                      final itemWidth =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                              columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: 16,
                        children: [
                          for (final badge in badges)
                            SizedBox(
                              width: itemWidth,
                              child: Column(
                                children: [
                                  _BadgeCircle(
                                    badge: badge,
                                    unlock: unlocks[badge.id],
                                    selected:
                                        displayedBadgeIds.contains(badge.id),
                                    previewLocked: previewLockedBadges,
                                    size: itemWidth.clamp(54, 78),
                                    onTap:
                                        unlocks.containsKey(badge.id) && !saving
                                            ? () => onToggleBadge(badge.id)
                                            : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    unlocks.containsKey(badge.id) ||
                                            previewLockedBadges
                                        ? badge.name
                                        : '???',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: unlocks.containsKey(badge.id)
                                          ? null
                                          : secondary.withOpacity(0.58),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCircle extends StatelessWidget {
  const _BadgeCircle({
    required this.badge,
    required this.unlock,
    required this.selected,
    this.previewLocked = false,
    required this.size,
    required this.onTap,
  });

  final AchievementBadgeDefinition badge;
  final AchievementBadgeUnlock? unlock;
  final bool selected;
  final bool previewLocked;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = unlock != null;
    final InlineSpan tooltip = unlocked
        ? TextSpan(
            children: [
              TextSpan(
                text: badge.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              TextSpan(
                text: '\n${badge.condition}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.8,
                ),
              ),
              const TextSpan(
                text: '\n────────────────\n',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 10,
                  height: 1,
                ),
              ),
              const TextSpan(
                text: '획득 날짜  ',
                style: TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: DateFormat(
                  'yyyy.MM.dd',
                ).format(unlock!.acquiredAt.toLocal()),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: '\n${badge.comment}',
                style: const TextStyle(
                  color: Color(0xFFBBBBBB),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  height: 1.8,
                ),
              ),
            ],
          )
        : previewLocked
            ? TextSpan(
                children: [
                  TextSpan(
                    text: badge.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: '\n${badge.condition}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.8,
                    ),
                  ),
                  const TextSpan(
                    text: '\n미획득 · 개발 미리보기',
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.8,
                    ),
                  ),
                ],
              )
            : const TextSpan(
                text: '???',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              );

    Widget image = Image.asset(
      badge.imagePath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: 256,
      cacheHeight: 256,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade800,
        alignment: Alignment.center,
        child: Icon(
          unlocked ? Icons.workspace_premium_rounded : Icons.question_mark,
          color: Colors.white54,
          size: size * 0.38,
        ),
      ),
    );
    if (badge.imageScale != 1) {
      final overflow = size * (badge.imageScale - 1) / 2;
      image = Transform.translate(
        offset: Offset(
          -badge.focusX * overflow,
          -badge.focusY * overflow,
        ),
        child: Transform.scale(
          scale: badge.imageScale,
          child: image,
        ),
      );
    }
    if (badge.imageBackgroundColor != null) {
      image = ColoredBox(
        color: Color(badge.imageBackgroundColor!),
        child: image,
      );
    }
    if (!unlocked && !previewLocked) {
      image = const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.2, -0.25),
            radius: 0.9,
            colors: [Color(0xFF77787C), Color(0xFF34353A)],
          ),
        ),
      );
    }

    return Tooltip(
      richMessage: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      showDuration: const Duration(seconds: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF262626), Color(0xFF1E1E1E)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF666666), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x52000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: MouseRegion(
        cursor:
            onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            padding: EdgeInsets.all(selected ? 3 : 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? Colors.orange : Colors.transparent,
              border: Border.all(
                color: unlocked
                    ? Colors.orange.withOpacity(selected ? 1 : 0.62)
                    : Colors.black.withOpacity(0.28),
                width: selected ? 2.4 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: unlocked
                      ? Colors.orange.withOpacity(selected ? 0.24 : 0.1)
                      : Colors.black.withOpacity(0.2),
                  blurRadius: selected ? 12 : 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: RepaintBoundary(child: image),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBadgeSlot extends StatelessWidget {
  const _EmptyBadgeSlot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface.withOpacity(0.4),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.32),
          width: 1.2,
        ),
      ),
      child: Icon(
        Icons.add_rounded,
        color: Theme.of(context).disabledColor.withOpacity(0.45),
        size: 22,
      ),
    );
  }
}
