import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/nikke_score_targets.dart';
import '../utils/ranking_color.dart';
import '../services/nikke_score_service.dart';
import '../services/nikke_statistics_service.dart';

class NikkeDamageCard extends StatefulWidget {
  const NikkeDamageCard(
      {super.key,
      required this.openId,
      required this.nameCode,
      required this.profileRevision,
      this.weakness,
      this.onStatisticsRefreshed,
      this.evaluate});
  final String openId;
  final int nameCode;
  final String profileRevision;
  final String? weakness;
  final VoidCallback? onStatisticsRefreshed;
  final Future<NikkeScoreResult> Function()? evaluate;
  @override
  State<NikkeDamageCard> createState() => _NikkeDamageCardState();
}

class _NikkeDamageCardState extends State<NikkeDamageCard> {
  NikkeScoreResult? _result;
  String? _error;
  bool _loading = false;
  bool _refreshing = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedResult());
  }

  @override
  void didUpdateWidget(covariant NikkeDamageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openId != widget.openId ||
        oldWidget.nameCode != widget.nameCode ||
        oldWidget.weakness != widget.weakness ||
        oldWidget.profileRevision != widget.profileRevision) {
      _request++;
      _result = null;
      _error = null;
      _loading = false;
      unawaited(_loadSavedResult());
    }
  }

  Future<void> _loadSavedResult() async {
    if (_loading) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await (widget.evaluate?.call() ??
          NikkeScoreService.loadStoredScores(openId: widget.openId).then(
              (scores) => scores.resultFor(widget.weakness == null
                  ? NikkeScoreService.profilesFor(widget.nameCode).first.key
                  : '${widget.nameCode}:${widget.weakness}')));
      if (!mounted || request != _request) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = error is NikkeScoreException
            ? error.message
            : '저장된 스코어를 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _refreshStatistics() async {
    setState(() => _refreshing = true);
    try {
      await NikkeStatisticsService().refreshAllStatistics();
      if (!mounted) return;
      widget.onStatisticsRefreshed?.call();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('표본 통계를 갱신했습니다.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? Colors.grey.shade400 : Colors.grey.shade600;
    final result = _result;
    final top = result?.topPercent;
    final profiles = NikkeScoreService.profilesFor(widget.nameCode);
    final profile = widget.weakness == null
        ? profiles.firstOrNull
        : nikkeScoreProfiles['${widget.nameCode}:${widget.weakness}'];
    final team = result != null && result.teamNames.isNotEmpty
        ? result.teamNames
        : profile?.teamNames ?? const <String>[];
    final rankColor = top == null ? Colors.grey : rankingColor(100 - top);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: dark ? const Color(0xFF17181E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: dark ? Colors.grey.shade800 : Colors.grey.shade300)),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.speed_rounded,
                  color: Colors.orange.shade700, size: 21),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      profiles.length > 1 && profile != null
                          ? '미미르 스코어 · ${profile.elementName}'
                          : '미미르 스코어',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold))),
              if (result != null)
                Text('표본 ${result.sampleCount}명',
                    style: TextStyle(fontSize: 11, color: muted)),
              if (result?.canRefreshStatistics == true)
                IconButton(
                  tooltip: '표본 통계 새로고침',
                  onPressed: _refreshing ? null : _refreshStatistics,
                  icon: _refreshing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                ),
              const SizedBox(width: 8),
              Tooltip(
                message: '대상은 내 육성 · 동료 4명은 고정 육성 · Lv.400 · 180초\n'
                    '코어 있음·없음 각각 180초 딜량을 50%씩 합산한 근사값\n'
                    '연구실은 사용자 기준으로 조합 전체에 적용\n'
                    '${team.join(' · ')}',
                waitDuration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.help_outline_rounded,
                    size: 20, color: muted, semanticLabel: '미미르 스코어 계산 조건'),
              ),
            ]),
            const SizedBox(height: 16),
            if (_loading) ...[
              const Center(
                  child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.orange))),
              const SizedBox(height: 8),
              const Center(
                  child:
                      Text('저장된 스코어 불러오는 중…', style: TextStyle(fontSize: 12))),
              const SizedBox(height: 16),
            ],
            if (result != null) ...[
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text('${NumberFormat('0.00').format(result.score)}점',
                        style: const TextStyle(
                            fontSize: 25, fontWeight: FontWeight.bold)),
                    Text(
                        top == null
                            ? '순위 집계 중'
                            : '상위 ${top.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: top == null ? muted : rankColor,
                            fontWeight: FontWeight.bold)),
                  ]),
              const SizedBox(height: 10),
              Semantics(
                  label: top == null
                      ? '순위 집계 중'
                      : '상위 ${top.toStringAsFixed(1)}퍼센트',
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value:
                              top == null ? 0 : (1 - top / 100).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: dark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          color: rankColor))),
              const SizedBox(height: 8),
              Text('전체 서버 · 최근 30일 · 계정당 최신 저장본 1개',
                  style: TextStyle(fontSize: 10.5, color: muted)),
              if (result.generatedAt != null)
                Text(
                    '통계 기준 ${DateFormat('yyyy.MM.dd HH:mm').format(result.generatedAt!.toLocal())}',
                    style: TextStyle(fontSize: 10.5, color: muted)),
              if (top == null)
                Text('같은 조건의 유효 표본 20명 이상부터 순위를 표시합니다.',
                    style: TextStyle(fontSize: 10.5, color: muted)),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12)),
              const SizedBox(height: 12),
              Text('프로필을 다시 동기화하면 자동으로 재측정합니다.',
                  style: TextStyle(fontSize: 11, color: muted)),
            ],
          ]),
    );
  }
}
