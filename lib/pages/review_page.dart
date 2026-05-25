import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wrong_word.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage>
    with SingleTickerProviderStateMixin {
  List<WrongWord> _words = const [];
  int _index = 0;
  bool _revealed = false;
  bool _loading = true;
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut);
    _load();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  WrongWord? get _current =>
      _words.isEmpty ? null : _words[_index.clamp(0, _words.length - 1)];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('错词复习'),
        actions: [
          if (_words.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_index + 1} / ${_words.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? _buildEmpty()
              : _buildReview(context),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.celebration, size: 64, color: AppTheme.emerald),
          SizedBox(height: 16),
          Text('没有需要复习的错词！',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text('所有错词已掌握，继续保持！'),
        ],
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final word = _current!;
    final theme = Theme.of(context);

    return ResponsivePage(
      maxWidth: 600,
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _words.isEmpty ? 0 : (_index + 1) / _words.length,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 32),

          // Card
          AnimatedBuilder(
            animation: _flipAnim,
            builder: (context, _) {
              return GlassCard(
                padding: const EdgeInsets.all(32),
                onTap: _reveal,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text('错误拼写',
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Text(
                        word.wrongForm,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedCrossFade(
                        firstChild: OutlinedButton(
                          onPressed: _reveal,
                          child: const Text('点击显示正确答案'),
                        ),
                        secondChild: Column(
                          children: [
                            Text('正确形式',
                                style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            Text(
                              word.correctForm,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.emerald,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: AppTheme.borderMd,
                              ),
                              child: Text(word.sentenceText,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(height: 1.5)),
                            ),
                          ],
                        ),
                        crossFadeState: _revealed
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Action buttons
          if (_revealed)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _next(mastered: false),
                    icon: const Icon(Icons.refresh),
                    label: const Text('还不熟'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: AppTheme.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _next(mastered: true),
                    icon: const Icon(Icons.check),
                    label: const Text('已掌握'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: AppTheme.emerald,
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    _flipCtrl.forward();
  }

  Future<void> _next({required bool mastered}) async {
    final word = _current;
    if (word != null) {
      await context.read<AppState>().markWordMastered(word.id, mastered);
    }
    if (_index >= _words.length - 1) {
      // Done
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('复习完成'),
          content: const Text('本轮复习已完成，返回继续学习吧！'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } else {
      _flipCtrl.reset();
      setState(() {
        _index++;
        _revealed = false;
      });
    }
  }

  Future<void> _load() async {
    final words = await context
        .read<AppState>()
        .database
        .getWrongWords(mastered: false);
    if (!mounted) return;
    // Shuffle for spaced repetition effect
    final shuffled = List<WrongWord>.from(words)..shuffle();
    setState(() {
      _words = shuffled;
      _loading = false;
    });
  }
}
