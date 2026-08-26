import 'package:flutter/material.dart';

import '../models/nikke_statistics.dart';
import '../services/nikke_statistics_service.dart';

class NikkeStatisticsCard extends StatefulWidget {
  const NikkeStatisticsCard({
    super.key,
    required this.openId,
    required this.nameCode,
    required this.isDark,
  });

  final String openId;
  final int nameCode;
  final bool isDark;

  @override
  State<NikkeStatisticsCard> createState() => _NikkeStatisticsCardState();
}

class _NikkeStatisticsCardState extends State<NikkeStatisticsCard>
    with AutomaticKeepAliveClientMixin {
  final _service = NikkeStatisticsService();
  late Future<NikkeStatistics> _future;
  bool _isRefreshing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NikkeStatisticsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openId != widget.openId ||
        oldWidget.nameCode != widget.nameCode) {
      _load();
    }
  }

  void _load() {
    _future = _service.getStatistics(
      openId: widget.openId,
      nameCode: widget.nameCode,
    );
  }

  void _retry() => setState(_load);

  Future<void> _refreshAllStatistics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전체 통계를 갱신할까요?'),
        content: const Text('연동된 모든 계정의 최신 저장본으로 통계를 다시 집계합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('갱신'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRefreshing = true);
    try {
      await _service.refreshAllStatistics();
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전체 통계를 최신 데이터로 갱신했어요.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      final message = error.toString().replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final border = widget.isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final background = widget.isDark ? const Color(0xFF17181E) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: FutureBuilder<NikkeStatistics>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 96,
              child: Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            );
          }
          if (snapshot.hasError) {
            return _ErrorView(onRetry: _retry);
          }
          final statistics = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded,
                      color: Colors.orange.shade700, size: 21),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('유저 육성 통계',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  if (statistics.canRefreshStatistics) ...[
                    IconButton(
                      tooltip: '전체 통계 수동 갱신',
                      onPressed: _isRefreshing ? null : _refreshAllStatistics,
                      icon: _isRefreshing
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.orange,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded,
                              color: Colors.orange),
                    ),
                    const SizedBox(width: 2),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statistics.isSufficient
                          ? Colors.green.withOpacity(.12)
                          : Colors.orange.withOpacity(.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statistics.isSufficient
                          ? '표본 ${statistics.sampleCount}명'
                          : '참고용 ${statistics.sampleCount}명',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statistics.isSufficient
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${statistics.server} 서버 · 최근 ${statistics.freshnessDays}일 · 계정당 최신 저장본 1개',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
              if (statistics.generatedAt != null) ...[
                const SizedBox(height: 3),
                Text(
                  '통계 기준 ${_formatGeneratedAt(statistics.generatedAt!.toLocal())}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: widget.isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade500,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _SectionTitle(title: '오버로드 옵션 TOP 5', isDark: widget.isDark),
              const SizedBox(height: 8),
              if (statistics.overload.isEmpty)
                const _EmptyText('집계할 오버로드 옵션이 없습니다.')
              else
                ...statistics.overload.indexed.map(
                  (entry) => _OverloadRow(
                    rank: entry.$1 + 1,
                    statistic: entry.$2,
                    isDark: widget.isDark,
                  ),
                ),
              const SizedBox(height: 18),
              _SectionTitle(title: '스킬 프리셋 TOP 4', isDark: widget.isDark),
              const SizedBox(height: 10),
              if (statistics.skillPresets.isEmpty)
                const _EmptyText('집계할 스킬 정보가 없습니다.')
              else
                ...statistics.skillPresets.map(
                  (preset) => _SkillPresetBar(
                    statistic: preset,
                    isMine: preset.preset == statistics.mySkillPreset,
                    isDark: widget.isDark,
                  ),
                ),
              const SizedBox(height: 18),
              _SectionTitle(title: '장비 강화 프리셋 TOP 4', isDark: widget.isDark),
              const SizedBox(height: 3),
              Text(
                '머리 / 장갑 / 상의 / 다리 · 오버로드·T9 기업 장비 외 X',
                style: TextStyle(
                  fontSize: 10.5,
                  color: widget.isDark
                      ? Colors.grey.shade500
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 7),
              if (statistics.equipmentPresets.isEmpty)
                const _EmptyText('집계할 장비 강화 정보가 없습니다.')
              else
                ...statistics.equipmentPresets.map(
                  (preset) => _EquipmentPresetBar(
                    statistic: preset,
                    isMine: preset.preset == statistics.myEquipmentPreset,
                    isDark: widget.isDark,
                  ),
                ),
              if (!statistics.isSufficient) ...[
                const SizedBox(height: 10),
                Text(
                  '표본 ${statistics.minimumSample}명 미만의 통계는 참고용이며 수치가 크게 변할 수 있습니다.',
                  style:
                      TextStyle(fontSize: 10.5, color: Colors.orange.shade700),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _formatGeneratedAt(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}.${twoDigits(value.month)}.${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.isDark});
  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
        ),
      );
}

class _OverloadRow extends StatelessWidget {
  const _OverloadRow({
    required this.rank,
    required this.statistic,
    required this.isDark,
  });

  final int rank;
  final NikkeOverloadStatistic statistic;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mine = statistic.myTotalPercent;
    final topPercent = statistic.topPercent;
    final rankingScore =
        topPercent == null ? null : (100.0 - topPercent).clamp(0.0, 100.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                child: Text('$rank',
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statistic.name,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '채택 ${statistic.adoptionRate.toStringAsFixed(1)}% · 전체 평균 +${statistic.averageTotalPercent.toStringAsFixed(2)}% (${statistic.averageLineCount.toStringAsFixed(2)}줄)',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                mine == null ? '내 옵션 없음' : '+${mine.toStringAsFixed(2)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: mine == null
                      ? Colors.grey
                      : _rankingColor(rankingScore ?? 0),
                ),
              ),
            ],
          ),
          if (rankingScore != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: rankingScore / 100,
                        minHeight: 8,
                        color: _rankingColor(rankingScore),
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 62,
                    child: Text(
                      '상위 ${topPercent!.toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _rankingColor(rankingScore),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _rankingColor(double score) {
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

class _SkillPresetBar extends StatelessWidget {
  const _SkillPresetBar({
    required this.statistic,
    required this.isMine,
    required this.isDark,
  });
  final NikkeSkillPresetStatistic statistic;
  final bool isMine;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isMine ? Colors.orange.withOpacity(.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMine ? Colors.orange : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 68,
              child: Text(statistic.preset,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: (statistic.ratio / 100).clamp(0, 1),
                  minHeight: 8,
                  color: Colors.orange,
                  backgroundColor:
                      isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 45,
              child: Text('${statistic.ratio.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}

class _EquipmentPresetBar extends StatelessWidget {
  const _EquipmentPresetBar({
    required this.statistic,
    required this.isMine,
    required this.isDark,
  });

  final NikkeEquipmentPresetStatistic statistic;
  final bool isMine;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isMine ? Colors.orange.withOpacity(.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMine ? Colors.orange : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 82,
              child: Text(
                statistic.preset,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: (statistic.ratio / 100).clamp(0, 1),
                  minHeight: 8,
                  color: Colors.orange,
                  backgroundColor:
                      isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 45,
              child: Text(
                '${statistic.ratio.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 110,
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('육성 통계를 불러오지 못했습니다. 다시 시도'),
          ),
        ),
      );
}
