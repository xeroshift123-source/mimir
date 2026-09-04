import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mimir/models/shared_deck.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/services/shared_deck_service.dart';
import 'package:provider/provider.dart';

class DeckPublishScreen extends StatefulWidget {
  const DeckPublishScreen({
    super.key,
    required this.squadPreviews,
    required this.squadsNikkeIds,
    required this.squadNames,
    required this.squadWeaknessElements,
    required this.season,
    required this.raidType,
    this.bossName,
    this.weaknessElement,
    this.initialDeck,
  });

  final List<Widget> squadPreviews;
  final List<List<String?>> squadsNikkeIds;
  final List<String> squadNames;
  final List<String> squadWeaknessElements;
  final String season;
  final String raidType;
  final String? bossName;
  final String? weaknessElement;
  final SharedDeck? initialDeck;

  @override
  State<DeckPublishScreen> createState() => _DeckPublishScreenState();
}

class _DeckPublishScreenState extends State<DeckPublishScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final List<TextEditingController> _squadDescriptionControllers;
  final _service = SharedDeckService();
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _squadDescriptionControllers = List.generate(
      widget.squadsNikkeIds.length,
      (index) => TextEditingController(
        text: widget.initialDeck != null &&
                index < widget.initialDeck!.squadDescriptions.length
            ? widget.initialDeck!.squadDescriptions[index]
            : '',
      ),
    );
    _descriptionController.text = widget.initialDeck?.description ?? '';
    if (widget.initialDeck != null) {
      _titleController.text = widget.initialDeck!.title;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nickname = context.read<AuthProvider>().nickname ?? '지휘관';
      _titleController.text = '$nickname의 ${widget.season} 공략 덱';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final controller in _squadDescriptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _publish() async {
    if (_publishing) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('덱 제목을 입력해 주세요.');
      return;
    }
    if (widget.squadsNikkeIds.any(
      (squad) => squad.length != 5 || squad.any((nikkeId) => nikkeId == null),
    )) {
      _showMessage('모든 스쿼드에 니케 5명을 편성해 주세요.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (!auth.isLoggedIn || uid == null) {
      _showMessage('덱을 게시하려면 로그인이 필요합니다.');
      return;
    }

    setState(() => _publishing = true);
    try {
      final deck = SharedDeck(
        id: '',
        authorUid: uid,
        authorName: auth.nickname?.trim().isNotEmpty == true
            ? auth.nickname!.trim()
            : '지휘관',
        title: title,
        description: _descriptionController.text.trim(),
        season: widget.season,
        raidType: widget.raidType,
        bossName: widget.bossName,
        weaknessElement: widget.weaknessElement,
        squadNames: List<String>.from(widget.squadNames),
        squadWeaknessElements: List<String>.from(widget.squadWeaknessElements),
        squadDescriptions: _squadDescriptionControllers
            .map((controller) => controller.text.trim())
            .toList(),
        squadsNikkeIds: widget.squadsNikkeIds
            .map((squad) => List<String?>.from(squad))
            .toList(),
        upvotes: 0,
        downvotes: 0,
        createdAt: DateTime.now(),
      );
      final saved = widget.initialDeck == null
          ? await _service.createDeck(deck)
          : await _service.updateDeck(
              deck.copyWith(
                id: widget.initialDeck!.id,
                createdAt: widget.initialDeck!.createdAt,
              ),
            );
      if (!mounted) return;
      Navigator.pop(context, saved);
    } on FirebaseException catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint(
        'Shared deck publish failed: ${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      final message = switch (error.code) {
        'permission-denied' => '게시글 저장 권한이 거부됐습니다. 로그인 상태와 저장 데이터를 확인해 주세요.',
        'unauthenticated' => '로그인 인증이 만료됐습니다. 다시 로그인해 주세요.',
        'unavailable' => '서버에 연결할 수 없습니다. 네트워크를 확인해 주세요.',
        _ => '게시글을 등록하지 못했습니다. (${error.code})',
      };
      _showMessage(message);
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('Shared deck publish failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('게시글을 등록하지 못했습니다. ($error)');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fieldColor =
        isDark ? const Color(0xFF272727) : const Color(0xFFF5F5F7);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(
          widget.initialDeck == null ? '공유 덱 게시글 작성' : '공유 덱 게시글 수정',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _publishing ? null : _publish,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade800,
              ),
              icon: _publishing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_rounded),
              label: Text(
                _publishing
                    ? '저장 중'
                    : widget.initialDeck == null
                        ? '게시'
                        : '저장',
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              _EditorCard(
                color: surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetadataChip(label: widget.season),
                        _MetadataChip(
                          label:
                              widget.raidType == 'union' ? '유니온 레이드' : '솔로 레이드',
                        ),
                        if (widget.bossName?.isNotEmpty == true)
                          _MetadataChip(label: widget.bossName!),
                        if (widget.weaknessElement?.isNotEmpty == true)
                          _MetadataChip(
                            label: '${widget.weaknessElement} 약점',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _titleController,
                      fillColor: fieldColor,
                      label: '덱 제목',
                      hint: '게시글 제목을 입력해 주세요.',
                      maxLength: 80,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (var index = 0;
                  index < widget.squadPreviews.length;
                  index++) ...[
                _EditorCard(
                  color: surface,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 600,
                            child: widget.squadPreviews[index],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _squadDescriptionControllers[index],
                        fillColor: fieldColor,
                        label: '${index + 1}번 스쿼드 설명',
                        hint: '운용법, 버스트 순서, 대체 니케 등을 적어주세요.',
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 500,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _EditorCard(
                color: surface,
                child: _buildField(
                  controller: _descriptionController,
                  fillColor: fieldColor,
                  label: '전체 공략 설명',
                  hint: '덱 전체의 공략 포인트나 참고 사항을 적어주세요.',
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 1200,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _publishing ? null : _publish,
                  icon: _publishing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.publish_rounded),
                  label: Text(
                    _publishing
                        ? '저장 중...'
                        : widget.initialDeck == null
                            ? '공유 덱 게시하기'
                            : '게시글 수정 완료',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required Color fillColor,
    required String label,
    required String hint,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: fillColor,
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 1.7),
        ),
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Color color;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 1,
      borderRadius: BorderRadius.circular(14),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
