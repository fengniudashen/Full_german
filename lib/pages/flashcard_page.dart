import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wrong_word.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// Flashcard review page — spaced repetition style review of wrong words.
/// Part of Shang Wenjie method Step 2: "深度解析与独立抠语法".
class FlashcardPage extends StatefulWidget {
  const FlashcardPage({super.key});

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  List<WrongWord> _words = const [];
  int _currentIndex = 0;
  bool _showingAnswer = false;
  int _masteredInSession = 0;
  int _reviewedInSession = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut);
    _loadWords();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    final appState = context.read<AppState>();
    await appState.loadWrongWords(mastered: false);
    final words = List<WrongWord>.from(appState.wrongWords);
    // Shuffle for spaced repetition feel
    words.shuffle(Random());
    if (!mounted) return;
    setState(() {
      _words = words;
      _currentIndex = 0;
      _showingAnswer = false;
      _loading = false;
    });
  }

  void _flip() {
    if (_showingAnswer) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    setState(() => _showingAnswer = !_showingAnswer);
  }

  void _markMastered() {
    if (_words.isEmpty) return;
    final word = _words[_currentIndex];
    context.read<AppState>().markWordMastered(word.id, true);
    // Schedule next review with Ebbinghaus spacing
    context.read<AppState>().database.scheduleNextReview(
        word.id, word.reviewCount + 1);
    setState(() => _masteredInSession++);
    _next();
  }

  void _markNotMastered() {
    if (_words.isEmpty) return;
    final word = _words[_currentIndex];
    context.read<AppState>().markWordMastered(word.id, false);
    // Reset to short interval for not-mastered words
    context.read<AppState>().database.scheduleNextReview(word.id, 0);
    _next();
  }

  void _next() {
    setState(() {
      _reviewedInSession++;
      _showingAnswer = false;
    });
    _flipCtrl.reset();

    if (_currentIndex < _words.length - 1) {
      setState(() => _currentIndex++);
    } else {
      // End of deck
      setState(() => _currentIndex = _words.length); // past end
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('生词闪卡'),
        actions: [
          if (_words.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentIndex + 1} / ${_words.length}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? _buildEmpty(theme)
              : _currentIndex >= _words.length
                  ? _buildSummary(theme)
                  : _buildCard(theme),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.celebration,
              size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('没有待复习的生词！',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('所有生词已掌握，继续保持！',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events,
                size: 64, color: AppTheme.gold),
            const SizedBox(height: 16),
            Text('本轮复习完成！',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatChip(
                  icon: Icons.check_circle,
                  label: '已掌握',
                  value: '$_masteredInSession',
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 16),
                _StatChip(
                  icon: Icons.refresh,
                  label: '已复习',
                  value: '$_reviewedInSession',
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _masteredInSession = 0;
                  _reviewedInSession = 0;
                  _loading = true;
                });
                _loadWords();
              },
              icon: const Icon(Icons.replay),
              label: const Text('再来一轮'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme) {
    final word = _words[_currentIndex];
    final progress = (_currentIndex + 1) / _words.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          // Info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: AppTheme.borderSm,
            ),
            child: Row(
              children: [
                Icon(Icons.record_voice_over, size: 14,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text('尚雯婕法 · 第2步：深度解析',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    )),
                const Spacer(),
                Icon(Icons.folder_outlined, size: 14,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(word.projectName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),
          const Spacer(),

          // Flashcard
          GestureDetector(
            onTap: _flip,
            child: AnimatedBuilder(
              animation: _flipAnim,
              builder: (_, __) {
                final angle = _flipAnim.value * pi;
                final showFront = angle < pi / 2;

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  child: showFront
                      ? _buildFrontCard(word, theme)
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: _buildBackCard(word, theme),
                        ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          Text('点击卡片翻转',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),

          const Spacer(),

          // Action buttons
          if (_showingAnswer) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _markNotMastered,
                    icon: const Icon(Icons.close),
                    label: const Text('还没记住'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.wrongFg,
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _markMastered,
                    icon: const Icon(Icons.check),
                    label: const Text('已掌握！'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _flip,
              icon: const Icon(Icons.flip),
              label: const Text('翻转查看答案'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFrontCard(WrongWord word, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.wrongBgDark, AppTheme.wrongBgDark.withValues(alpha: 0.5)]
              : [AppTheme.wrongBg, AppTheme.wrongBg.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.wrongBorderDark : AppTheme.wrongBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppTheme.wrongFgDark : AppTheme.wrongFg)
                .withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('你写的是',
              style: theme.textTheme.labelLarge?.copyWith(
                color: isDark ? AppTheme.wrongFgDark : AppTheme.wrongFg,
              )),
          const SizedBox(height: 12),
          Text(
            word.wrongForm,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? AppTheme.wrongFgDark : AppTheme.wrongFg,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            word.sentenceText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(WrongWord word, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.correctBgDark, AppTheme.correctBgDark.withValues(alpha: 0.5)]
              : [AppTheme.correctBg, AppTheme.correctBg.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.correctBorderDark : AppTheme.correctBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppTheme.correctFgDark : AppTheme.correctFg)
                .withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('正确拼写',
              style: theme.textTheme.labelLarge?.copyWith(
                color: isDark ? AppTheme.correctFgDark : AppTheme.correctFg,
              )),
          const SizedBox(height: 12),
          Text(
            word.correctForm,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? AppTheme.correctFgDark : AppTheme.correctFg,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Show the difference
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              children: [
                TextSpan(
                  text: word.wrongForm,
                  style: TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: isDark ? AppTheme.wrongFgDark : AppTheme.wrongFg,
                  ),
                ),
                const TextSpan(text: '  →  '),
                TextSpan(
                  text: word.correctForm,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.correctFgDark : AppTheme.correctFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: color,
            )),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      ],
    );
  }
}
