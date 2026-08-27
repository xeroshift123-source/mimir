import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/recap_card.dart';
import '../providers/nikke_provider.dart';
import '../services/database_service.dart';
import '../services/recap_service.dart';
import '../utils/image_export.dart';

class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});

  static const routeName = '/recap';

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  final DatabaseService _database = DatabaseService();
  final PageController _pageController = PageController();

  bool _started = false;
  bool _saving = false;
  int _currentIndex = 0;
  String? _error;
  List<RecapCardData>? _cards;
  List<GlobalKey> _captureKeys = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final openId =
        ModalRoute.of(context)?.settings.arguments?.toString().trim() ?? '';
    _load(openId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load(String openId) async {
    if (openId.isEmpty) {
      setState(() => _error = '연동 계정 정보를 찾을 수 없습니다.');
      return;
    }
    try {
      final profileFuture = _database.getCommanderProfile(openId);
      final provider = context.read<NikkeProvider>();
      if (provider.nikkeByBlablaCode.isEmpty) await provider.loadNikkes();
      final profile = await profileFuture;
      if (profile == null) throw StateError('프로필 정보가 없습니다.');
      if (kDebugMode &&
          profile['joinedAt'] == null &&
          profile['createdAt'] == null &&
          profile['created_at'] == null) {
        debugPrint(
          '[RECAP] 가입일 필드가 없습니다. 전체 새로고침으로 프로필을 다시 수집해 주세요.',
        );
      }
      final cards = RecapService.build(
        profile: profile,
        nikkesByCode: provider.nikkeByBlablaCode,
        accountSeed: openId,
      );
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _captureKeys = List.generate(cards.length, (_) => GlobalKey());
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '리캡을 만들지 못했습니다.\n최신 정보로 새로고침한 뒤 다시 시도해 주세요.');
      debugPrint('Recap load error: $error');
    }
  }

  Future<Uint8List?> _captureCurrentCard() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _captureKeys[_currentIndex]
        .currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: kIsWeb ? 2 : 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _saveCurrentCard() async {
    if (_saving || _cards == null) return;
    setState(() => _saving = true);
    try {
      final bytes = await _captureCurrentCard();
      if (bytes == null) throw StateError('카드 캡처에 실패했습니다.');
      final cardNumber =
          _cards![_currentIndex].order.toString().padLeft(2, '0');
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
      await exportPng(bytes, 'mimir_recap_${stamp}_$cardNumber.png');
      if (!mounted) return;
      const feedback = kIsWeb
          ? SnackBar(
              content: Text('리캡 카드를 다운로드했습니다.'),
              behavior: SnackBarBehavior.floating,
            )
          : SnackBar(
              content: Text('리캡 카드 공유 화면을 열었습니다.'),
              behavior: SnackBarBehavior.floating,
            );
      ScaffoldMessenger.of(context).showSnackBar(
        feedback,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 저장에 실패했습니다: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0C10),
        foregroundColor: Colors.white,
        title: const Text('COMMANDER RECAP',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        centerTitle: true,
        actions: [
          if (cards != null && cards.isNotEmpty)
            IconButton(
              tooltip: '현재 카드 저장',
              onPressed: _saving ? null : _saveCurrentCard,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _error != null
          ? _ErrorView(message: _error!)
          : cards == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.orange))
              : cards.isEmpty
                  ? const _ErrorView(message: '생성할 수 있는 리캡 카드가 없습니다.')
                  : SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: cards.length,
                              onPageChanged: (value) =>
                                  setState(() => _currentIndex = value),
                              itemBuilder: (context, index) => Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 10, 18, 14),
                                child: Center(
                                  child: AspectRatio(
                                    aspectRatio: 2 / 3,
                                    child: RepaintBoundary(
                                      key: _captureKeys[index],
                                      child: RecapCardView(
                                        card: cards[index],
                                        current: index + 1,
                                        total: cards.length,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _RecapNavigation(
                            current: _currentIndex,
                            total: cards.length,
                            saving: _saving,
                            onPrevious: _currentIndex == 0
                                ? null
                                : () => _pageController.previousPage(
                                      duration:
                                          const Duration(milliseconds: 280),
                                      curve: Curves.easeOutCubic,
                                    ),
                            onNext: _currentIndex == cards.length - 1
                                ? null
                                : () => _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 280),
                                      curve: Curves.easeOutCubic,
                                    ),
                            onSave: _saveCurrentCard,
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class RecapCardView extends StatelessWidget {
  const RecapCardView({
    super.key,
    required this.card,
    required this.current,
    required this.total,
  });

  final RecapCardData card;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final accent = card.accentColor ?? card.textColor.withOpacity(0.75);
    final canvas = ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: card.colors,
            stops: card.colors.length == 3 ? const [0, 0.52, 1] : null,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CardDecor(accent: accent),
            if (card.imageAsset != null)
              Positioned(
                right: -36,
                bottom: -8,
                width: 440,
                height: 810,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Color(0x66000000),
                      Colors.black,
                      Colors.black,
                    ],
                    stops: [0, 0.09, 0.24, 1],
                  ).createShader(bounds),
                  child: Image.asset(
                    card.imageAsset!,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    card.colors.first.withOpacity(0.96),
                    card.colors.first.withOpacity(0.72),
                    card.colors.first
                        .withOpacity(card.imageAsset == null ? 0.18 : 0.02),
                  ],
                  stops: const [0, 0.45, 0.78],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 52, 46, 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 36, height: 4, color: accent),
                      const SizedBox(width: 12),
                      Text(
                        card.eyebrow,
                        style: TextStyle(
                          color: accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 54),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 525),
                    child: Text(
                      card.title,
                      style: TextStyle(
                        color: card.textColor,
                        fontSize: card.order == 14 ? 58 : 42,
                        height: 1.22,
                        letterSpacing: -1.8,
                        fontWeight: FontWeight.w900,
                        shadows: card.textColor == Colors.white
                            ? const [
                                Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 3))
                              ]
                            : null,
                      ),
                    ),
                  ),
                  if (card.details.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: card.details
                            .map((detail) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: card.textColor.withOpacity(
                                        card.textColor == Colors.white
                                            ? 0.13
                                            : 0.08),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                        color: accent.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    detail,
                                    style: TextStyle(
                                      color: card.textColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Text('MIMIR',
                          style: TextStyle(
                              color: card.textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2)),
                      const Spacer(),
                      Text('$current / $total',
                          style: TextStyle(
                              color: card.textColor.withOpacity(0.82),
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 720,
        height: 1080,
        child: canvas,
      ),
    );
  }
}

class _CardDecor extends StatelessWidget {
  const _CardDecor({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
            right: -90,
            top: -70,
            child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: accent.withOpacity(0.18), width: 2)))),
        Positioned(
            right: -20,
            top: 5,
            child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: accent.withOpacity(0.16), width: 2)))),
        Positioned(
            left: 30,
            bottom: 90,
            child: Transform.rotate(
                angle: -0.12,
                child: Container(
                    width: 190, height: 5, color: accent.withOpacity(0.18)))),
      ],
    );
  }
}

class _RecapNavigation extends StatelessWidget {
  const _RecapNavigation({
    required this.current,
    required this.total,
    required this.saving,
    required this.onPrevious,
    required this.onNext,
    required this.onSave,
  });

  final int current;
  final int total;
  final bool saving;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded)),
          const SizedBox(width: 12),
          Flexible(
            child: Text('${current + 1} / $total',
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            icon: const Icon(Icons.download_rounded, size: 19),
            label: const Text('이 카드 저장',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
              onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5)),
      ),
    );
  }
}
